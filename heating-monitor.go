// heating-monitor — continuously decides whether the heat pump or oil furnace
// is cheaper to run right now, and sends a dunst notification when the
// recommendation flips.
//
// Environment variables (all optional with defaults):
//
//	EIA_API_KEY          — EIA v2 API key for live oil price
//	OIL_PRICE_OVERRIDE   — fallback oil price in $/gal (e.g. "3.50")
//	ELEC_RATE            — electricity rate in $/kWh (default 0.30)
//	CHECK_INTERVAL_MINS  — polling interval in minutes (default 15)
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// ── constants ────────────────────────────────────────────────────────────────

const (
	furnaceEff    = 0.85    // AFUE efficiency of the oil furnace
	btuPerGalOil  = 138500. // BTU per gallon of No.2 heating oil
	btuPerKWh     = 3412.   // BTU per kWh
	defaultElec   = 0.30    // $/kWh
	defaultMins   = 15      // polling interval
	httpTimeout   = 15 * time.Second
	stateFilename = "state.json"
	logFilename   = "heating-monitor.log"
	dataDir       = ".local/share/heating-monitor"
)

// COP anchor points for piecewise-linear interpolation (tempF → COP).
type copAnchor struct {
	tempF float64
	cop   float64
}

var copTable = []copAnchor{
	{-10, 1.00},
	{0, 1.35},
	{21, 1.85},
	{35, 2.75},
	{50, 3.75},
}

// ── domain types ─────────────────────────────────────────────────────────────

// Recommendation is the heating source decision.
type Recommendation string

const (
	RecHeatPump Recommendation = "heat_pump"
	RecFurnace  Recommendation = "furnace"
)

// State persisted between runs.
type State struct {
	LastRecommendation Recommendation `json:"last_recommendation"`
	UpdatedAt          time.Time      `json:"updated_at"`
}

// Config holds runtime configuration resolved from env.
type Config struct {
	EIAKey       string
	OilOverride  string // raw string; empty means not set
	ElecRate     float64
	IntervalMins int
	StateFile    string
	LogFile      string
}

// CycleResult carries all computed values for one monitoring cycle.
type CycleResult struct {
	TempF          float64
	OilPricePerGal float64
	CurrentCOP     float64
	BreakEvenCOP   float64
	Winner         Recommendation
}

// ── wttr.in response shapes ──────────────────────────────────────────────────

type wttrResponse struct {
	CurrentCondition []struct {
		TempF string `json:"temp_F"`
	} `json:"current_condition"`
}

// ── EIA API v2 response shapes ───────────────────────────────────────────────

// eiaDataPoint uses json.Number so value can be either a JSON number or a
// quoted string — EIA occasionally returns both forms.
type eiaDataPoint struct {
	Period string      `json:"period"`
	Value  json.Number `json:"value"`
}

type eiaResponse struct {
	Response struct {
		Data []eiaDataPoint `json:"data"`
	} `json:"response"`
}

// ── HTTP helpers ─────────────────────────────────────────────────────────────

func newHTTPClient() *http.Client {
	return &http.Client{Timeout: httpTimeout}
}

func fetchTempF(ctx context.Context, client *http.Client) (float64, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://wttr.in/Boston,MA?format=j1", nil)
	if err != nil {
		return 0, fmt.Errorf("fetchTempF: build request: %w", err)
	}
	req.Header.Set("User-Agent", "heating-monitor/1.0")

	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("fetchTempF: http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("fetchTempF: unexpected status %d", resp.StatusCode)
	}

	var w wttrResponse
	if err := json.NewDecoder(resp.Body).Decode(&w); err != nil {
		return 0, fmt.Errorf("fetchTempF: decode: %w", err)
	}
	if len(w.CurrentCondition) == 0 {
		return 0, errors.New("fetchTempF: empty current_condition array")
	}
	f, err := strconv.ParseFloat(strings.TrimSpace(w.CurrentCondition[0].TempF), 64)
	if err != nil {
		return 0, fmt.Errorf("fetchTempF: parse temp_F %q: %w",
			w.CurrentCondition[0].TempF, err)
	}
	return f, nil
}

func fetchOilPriceEIA(ctx context.Context, client *http.Client, apiKey string) (float64, error) {
	url := fmt.Sprintf(
		"https://api.eia.gov/v2/petroleum/pri/wfr/data/"+
			"?frequency=weekly&data[0]=value"+
			"&facets[duoarea][]=SMA&facets[product][]=EPD2F"+
			"&sort[0][column]=period&sort[0][direction]=desc"+
			"&offset=0&length=1&api_key=%s",
		apiKey,
	)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, fmt.Errorf("fetchOilPriceEIA: build request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("fetchOilPriceEIA: http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return 0, fmt.Errorf("fetchOilPriceEIA: status %d: %s", resp.StatusCode, body)
	}

	var e eiaResponse
	if err := json.NewDecoder(resp.Body).Decode(&e); err != nil {
		return 0, fmt.Errorf("fetchOilPriceEIA: decode: %w", err)
	}
	if len(e.Response.Data) == 0 {
		return 0, errors.New("fetchOilPriceEIA: no data points returned")
	}
	val, err := e.Response.Data[0].Value.Float64()
	if err != nil {
		return 0, fmt.Errorf("fetchOilPriceEIA: parse value %q: %w",
			e.Response.Data[0].Value.String(), err)
	}
	return val, nil
}

// ── physics ───────────────────────────────────────────────────────────────────

// interpolateCOP returns the heat pump COP for a given outdoor temperature in °F
// using piecewise-linear interpolation with clamping at the anchor extremes.
func interpolateCOP(tempF float64) float64 {
	// Clamp below lowest anchor.
	if tempF <= copTable[0].tempF {
		return copTable[0].cop
	}
	// Clamp above highest anchor.
	if tempF >= copTable[len(copTable)-1].tempF {
		return copTable[len(copTable)-1].cop
	}
	// Find the segment.
	for i := 1; i < len(copTable); i++ {
		lo := copTable[i-1]
		hi := copTable[i]
		if tempF <= hi.tempF {
			t := (tempF - lo.tempF) / (hi.tempF - lo.tempF)
			return lo.cop + t*(hi.cop-lo.cop)
		}
	}
	// Unreachable but keeps the compiler happy.
	return copTable[len(copTable)-1].cop
}

// breakEvenCOP returns the COP at which heat pump and furnace costs are equal.
func breakEvenCOP(elecRate, oilPricePerGal float64) float64 {
	return (elecRate / oilPricePerGal) * (furnaceEff * btuPerGalOil / btuPerKWh)
}

// decide returns the cheaper heating source.
func decide(currentCOP, beCOP float64) Recommendation {
	if currentCOP > beCOP {
		return RecHeatPump
	}
	return RecFurnace
}

// ── state persistence ─────────────────────────────────────────────────────────

func loadState(path string) (State, error) {
	f, err := os.Open(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return State{}, nil // first run
		}
		return State{}, fmt.Errorf("loadState: %w", err)
	}
	defer f.Close()

	var s State
	if err := json.NewDecoder(f).Decode(&s); err != nil {
		return State{}, fmt.Errorf("loadState: decode: %w", err)
	}
	return s, nil
}

func saveState(path string, s State) error {
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("saveState: create tmp: %w", err)
	}
	if err := json.NewEncoder(f).Encode(s); err != nil {
		f.Close()
		return fmt.Errorf("saveState: encode: %w", err)
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("saveState: close: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		return fmt.Errorf("saveState: rename: %w", err)
	}
	return nil
}

// ── notifications ─────────────────────────────────────────────────────────────

func sendNotification(rec Recommendation, r CycleResult) {
	var title string
	switch rec {
	case RecFurnace:
		title = "\U0001f525 Switch to Furnace"
	case RecHeatPump:
		title = "\U0001f321️ Switch to Heat Pump"
	}
	body := fmt.Sprintf(
		"Oil: $%.2f/gal  |  COP: %.2f  |  Break-even COP: %.2f  |  Temp: %.2f°F",
		r.OilPricePerGal, r.CurrentCOP, r.BreakEvenCOP, r.TempF,
	)
	cmd := exec.Command("notify-send", "-u", "normal", title, body)
	if err := cmd.Run(); err != nil {
		// notify-send not found or failed — log and continue.
		log.Printf("WARNING: notify-send failed (is it installed?): %v", err)
	}
}

// ── config ────────────────────────────────────────────────────────────────────

func loadConfig() (Config, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return Config{}, fmt.Errorf("loadConfig: UserHomeDir: %w", err)
	}
	dir := filepath.Join(home, dataDir)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return Config{}, fmt.Errorf("loadConfig: mkdir %s: %w", dir, err)
	}

	elecRate := defaultElec
	if v := os.Getenv("ELEC_RATE"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil && f > 0 {
			elecRate = f
		} else {
			log.Printf("WARNING: invalid ELEC_RATE=%q, using %.2f", v, defaultElec)
		}
	}

	intervalMins := defaultMins
	if v := os.Getenv("CHECK_INTERVAL_MINS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			intervalMins = n
		} else {
			log.Printf("WARNING: invalid CHECK_INTERVAL_MINS=%q, using %d", v, defaultMins)
		}
	}

	return Config{
		EIAKey:       os.Getenv("EIA_API_KEY"),
		OilOverride:  os.Getenv("OIL_PRICE_OVERRIDE"),
		ElecRate:     elecRate,
		IntervalMins: intervalMins,
		StateFile:    filepath.Join(dir, stateFilename),
		LogFile:      filepath.Join(dir, logFilename),
	}, nil
}

// ── cycle ─────────────────────────────────────────────────────────────────────

// runCycle performs one full check and returns the result, or an error if data
// could not be fetched. It does NOT mutate state or send notifications.
func runCycle(ctx context.Context, client *http.Client, cfg Config) (CycleResult, error) {
	// 1. Fetch temperature.
	tempF, err := fetchTempF(ctx, client)
	if err != nil {
		return CycleResult{}, fmt.Errorf("runCycle: temp: %w", err)
	}

	// 2. Resolve oil price.
	var oilPrice float64
	if cfg.EIAKey != "" {
		oilPrice, err = fetchOilPriceEIA(ctx, client, cfg.EIAKey)
		if err != nil {
			log.Printf("WARNING: EIA fetch failed (%v); trying OIL_PRICE_OVERRIDE", err)
		}
	}
	if oilPrice == 0 {
		if cfg.OilOverride != "" {
			oilPrice, err = strconv.ParseFloat(strings.TrimSpace(cfg.OilOverride), 64)
			if err != nil || oilPrice <= 0 {
				return CycleResult{}, fmt.Errorf("runCycle: invalid OIL_PRICE_OVERRIDE=%q", cfg.OilOverride)
			}
		} else {
			return CycleResult{}, errors.New("runCycle: no oil price available (set EIA_API_KEY or OIL_PRICE_OVERRIDE)")
		}
	}

	// 3–5. Compute COPs and decide.
	cop := interpolateCOP(tempF)
	beCOP := breakEvenCOP(cfg.ElecRate, oilPrice)
	winner := decide(cop, beCOP)

	return CycleResult{
		TempF:          tempF,
		OilPricePerGal: oilPrice,
		CurrentCOP:     cop,
		BreakEvenCOP:   beCOP,
		Winner:         winner,
	}, nil
}

// ── logging ───────────────────────────────────────────────────────────────────

func openLogWriter(path string) (*os.File, error) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, fmt.Errorf("openLogWriter: %w", err)
	}
	return f, nil
}

// logCycle writes one structured line per cycle.
func logCycle(logger *log.Logger, r CycleResult, switched bool) {
	switchedStr := "no"
	if switched {
		switchedStr = "YES"
	}
	logger.Printf(
		"tempF=%.1f oilPrice=%.2f currentCOP=%.3f breakEvenCOP=%.3f winner=%s switched=%s",
		r.TempF, r.OilPricePerGal, r.CurrentCOP, r.BreakEvenCOP, r.Winner, switchedStr,
	)
}

// ── main loop ─────────────────────────────────────────────────────────────────

func run() error {
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("run: %w", err)
	}

	// Set up logger writing to both stdout and the log file.
	logFile, err := openLogWriter(cfg.LogFile)
	if err != nil {
		return fmt.Errorf("run: open log: %w", err)
	}
	defer logFile.Close()

	multiWriter := io.MultiWriter(os.Stdout, logFile)
	logger := log.New(multiWriter, "", log.LstdFlags)

	logger.Printf("heating-monitor starting: interval=%dm elecRate=%.2f logFile=%s",
		cfg.IntervalMins, cfg.ElecRate, cfg.LogFile)

	// Load persisted state.
	state, err := loadState(cfg.StateFile)
	if err != nil {
		logger.Printf("WARNING: could not load state (%v); starting fresh", err)
	}

	// Context for graceful shutdown.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigs
		logger.Printf("shutdown signal received")
		cancel()
	}()

	client := newHTTPClient()
	interval := time.Duration(cfg.IntervalMins) * time.Minute
	first := true

	for {
		// Run one cycle with a per-request timeout.
		cycleCtx, cycleCancel := context.WithTimeout(ctx, httpTimeout*2)
		result, err := runCycle(cycleCtx, client, cfg)
		cycleCancel()

		if err != nil {
			if errors.Is(err, context.Canceled) {
				logger.Printf("context cancelled; exiting")
				return nil
			}
			logger.Printf("ERROR: cycle failed: %v; will retry in %v", err, interval)
		} else {
			switched := state.LastRecommendation != "" && state.LastRecommendation != result.Winner

			// On first cycle, always print status regardless of change.
			if first {
				logger.Printf(
					"STATUS: tempF=%.1f oilPrice=%.2f/gal currentCOP=%.3f breakEvenCOP=%.3f winner=%s",
					result.TempF, result.OilPricePerGal,
					result.CurrentCOP, result.BreakEvenCOP, result.Winner,
				)
				first = false
			}

			logCycle(logger, result, switched)

			if switched || state.LastRecommendation == "" {
				if switched {
					sendNotification(result.Winner, result)
				}
				state = State{
					LastRecommendation: result.Winner,
					UpdatedAt:          time.Now().UTC(),
				}
				if err := saveState(cfg.StateFile, state); err != nil {
					logger.Printf("WARNING: saveState: %v", err)
				}
			}
		}

		// Sleep until next cycle, or bail on cancellation.
		select {
		case <-ctx.Done():
			logger.Printf("context done; exiting cleanly")
			return nil
		case <-time.After(interval):
			// continue
		}
	}
}

func main() {
	if err := run(); err != nil {
		log.Fatalf("heating-monitor: %v", err)
	}
}

// ── sanity: verify interpolateCOP covers the full table range ─────────────────
// (compile-time insurance; remove if binary size matters)
var _ = func() bool {
	// clamp low
	if interpolateCOP(-20) != 1.0 {
		panic("COP clamp low broken")
	}
	// clamp high
	if interpolateCOP(60) != 3.75 {
		panic("COP clamp high broken")
	}
	// mid-point between 0→21: t=0.5 → cop = 1.35 + 0.5*(1.85-1.35) = 1.60
	got := interpolateCOP(10.5)
	if math.Abs(got-1.60) > 0.01 {
		panic(fmt.Sprintf("COP interpolation wrong: got %f, want 1.60", got))
	}
	return true
}()
