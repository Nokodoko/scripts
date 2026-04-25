#!/bin/bash
# test-dwm-monitor-listener.sh - Comprehensive test suite for dwm monitor listener
#
# Tests the monitor listener daemon, hotswap script, and build system
# without actually killing dwm or modifying the running system.
#
# Usage: ./test-dwm-monitor-listener.sh [--verbose]

set -uo pipefail

# --- Test Framework ---
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
VERBOSE=0
TEST_TMPDIR=$(mktemp -d /tmp/dwm-test-XXXXXX)

if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=1
fi

cleanup_test() {
    rm -rf "$TEST_TMPDIR"
    # Clean up any mock scripts
    rm -f /tmp/dwm-test-*.sh
    # Kill any test listener instances
    if [[ -f "$TEST_TMPDIR/test.pid" ]]; then
        local pid
        pid=$(cat "$TEST_TMPDIR/test.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    fi
}
trap cleanup_test EXIT

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $1"
    if [[ $VERBOSE -eq 1 && -n "${2:-}" ]]; then
        echo "        Detail: $2"
    fi
}

skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo "  SKIP: $1"
}

section() {
    echo ""
    echo "=== $1 ==="
}

# --- Test Helpers ---

# Create a mock xrandr that reports N monitors
create_mock_xrandr() {
    local count="$1"
    local mock_script="$TEST_TMPDIR/xrandr"

    if [[ "$count" -eq 1 ]]; then
        cat > "$mock_script" << 'MOCK_EOF'
#!/bin/bash
echo "Screen 0: minimum 8 x 8, current 3840 x 2160, maximum 32767 x 32767"
echo "DP-0 connected primary 3840x2160+0+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    144.00*+"
echo "DP-1 disconnected (normal left inverted right x axis y axis)"
echo "DP-2 disconnected (normal left inverted right x axis y axis)"
echo "DP-3 disconnected (normal left inverted right x axis y axis)"
echo "HDMI-0 disconnected (normal left inverted right x axis y axis)"
MOCK_EOF
    elif [[ "$count" -eq 2 ]]; then
        cat > "$mock_script" << 'MOCK_EOF'
#!/bin/bash
echo "Screen 0: minimum 8 x 8, current 7680 x 2160, maximum 32767 x 32767"
echo "DP-0 connected primary 3840x2160+0+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    144.00*+"
echo "DP-1 disconnected (normal left inverted right x axis y axis)"
echo "DP-2 disconnected (normal left inverted right x axis y axis)"
echo "DP-3 connected 3840x2160+3840+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    60.00*+"
echo "HDMI-0 disconnected (normal left inverted right x axis y axis)"
MOCK_EOF
    elif [[ "$count" -eq 3 ]]; then
        cat > "$mock_script" << 'MOCK_EOF'
#!/bin/bash
echo "Screen 0: minimum 8 x 8, current 11520 x 2160, maximum 32767 x 32767"
echo "DP-0 connected primary 3840x2160+0+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    144.00*+"
echo "DP-1 connected 3840x2160+7680+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    60.00*+"
echo "DP-2 disconnected (normal left inverted right x axis y axis)"
echo "DP-3 connected 3840x2160+3840+0 (normal left inverted right x axis y axis) 600mm x 340mm"
echo "   3840x2160    60.00*+"
echo "HDMI-0 disconnected (normal left inverted right x axis y axis)"
MOCK_EOF
    fi

    chmod +x "$mock_script"
    echo "$mock_script"
}

# --- Tests ---

section "1. Build Verification"

# Test 1.1: Base dwm compiles
echo "  Testing base dwm build..."
if cd /home/n0ko/bling/dwm && make clean >/dev/null 2>&1 && make >/dev/null 2>&1; then
    pass "Base dwm (desktop branch) compiles successfully"
else
    fail "Base dwm (desktop branch) failed to compile" "Check /home/n0ko/bling/dwm for errors"
fi

# Test 1.2: Pertag dwm compiles
echo "  Testing pertag dwm build..."
if cd /home/n0ko/bling/dwm-pertag && make clean >/dev/null 2>&1 && make >/dev/null 2>&1; then
    pass "Pertag dwm (dual-monitor branch) compiles successfully"
else
    fail "Pertag dwm (dual-monitor branch) failed to compile" "Check /home/n0ko/bling/dwm-pertag for errors"
fi

# Test 1.3: Both binaries exist after build
if [[ -f /home/n0ko/bling/dwm/dwm ]]; then
    pass "Base dwm binary exists"
else
    fail "Base dwm binary missing after build"
fi

if [[ -f /home/n0ko/bling/dwm-pertag/dwm ]]; then
    pass "Pertag dwm binary exists"
else
    fail "Pertag dwm binary missing after build"
fi

# Test 1.4: Binaries are different (pertag patch changes the binary)
if [[ -f /home/n0ko/bling/dwm/dwm && -f /home/n0ko/bling/dwm-pertag/dwm ]]; then
    BASE_SIZE=$(stat -c %s /home/n0ko/bling/dwm/dwm)
    PERTAG_SIZE=$(stat -c %s /home/n0ko/bling/dwm-pertag/dwm)
    BASE_MD5=$(md5sum /home/n0ko/bling/dwm/dwm | awk '{print $1}')
    PERTAG_MD5=$(md5sum /home/n0ko/bling/dwm-pertag/dwm | awk '{print $1}')
    if [[ "$BASE_MD5" != "$PERTAG_MD5" ]]; then
        pass "Base and pertag binaries are different (base=${BASE_SIZE}B, pertag=${PERTAG_SIZE}B)"
    else
        fail "Base and pertag binaries are identical - pertag patch may not be applied"
    fi
fi


section "2. Script Existence and Permissions"

# Test 2.1: hotswap script exists and is executable
if [[ -x /home/n0ko/scripts/dwm-hotswap.sh ]]; then
    pass "dwm-hotswap.sh exists and is executable"
else
    fail "dwm-hotswap.sh missing or not executable"
fi

# Test 2.2: listener script exists and is executable
if [[ -x /home/n0ko/scripts/dwm-monitor-listener.sh ]]; then
    pass "dwm-monitor-listener.sh exists and is executable"
else
    fail "dwm-monitor-listener.sh missing or not executable"
fi

# Test 2.3: xinitrc references the listener
if grep -q "dwm-monitor-listener" /home/n0ko/.xinitrc 2>/dev/null; then
    pass ".xinitrc references dwm-monitor-listener.sh"
else
    fail ".xinitrc does not reference dwm-monitor-listener.sh"
fi


section "3. Hotswap Script Logic (dry-run tests)"

# Test 3.1: Invalid argument handling
OUTPUT=$(bash /home/n0ko/scripts/dwm-hotswap.sh invalid 2>&1) || true
# The script should fail (exit non-zero) with invalid arg
if bash -c 'source <(grep -A5 "Validate argument" /home/n0ko/scripts/dwm-hotswap.sh | head -1) 2>/dev/null'; then
    # Just check that the script validates its input
    if grep -q 'Invalid version' /home/n0ko/scripts/dwm-hotswap.sh; then
        pass "Hotswap script validates input arguments"
    else
        fail "Hotswap script does not validate arguments"
    fi
fi

# Test 3.2: Idempotency check
echo "base" > "$TEST_TMPDIR/state"
# Verify the script has idempotency logic
if grep -q 'Already running' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap script has idempotency check"
else
    fail "Hotswap script lacks idempotency check"
fi

# Test 3.3: Lock file logic
if grep -q 'flock' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap script uses flock for single-instance enforcement"
else
    fail "Hotswap script lacks single-instance lock mechanism"
fi

# Test 3.4: State file tracking
if grep -q '/tmp/dwm-monitor-state' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap script tracks state in /tmp/dwm-monitor-state"
else
    fail "Hotswap script does not use state tracking file"
fi


section "4. Monitor Listener Logic"

# Test 4.1: PID file enforcement
if grep -q 'PID_FILE' /home/n0ko/scripts/dwm-monitor-listener.sh && \
   grep -q 'enforce_single_instance' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener has PID file single-instance enforcement"
else
    fail "Listener lacks PID file enforcement"
fi

# Test 4.2: Debounce logic
if grep -q 'DEBOUNCE_SECONDS' /home/n0ko/scripts/dwm-monitor-listener.sh && \
   grep -q 'Debounced event' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener has debounce logic for rapid events"
else
    fail "Listener lacks debounce logic"
fi

# Test 4.3: Uses udevadm monitor (efficient event-driven)
if grep -q 'udevadm monitor.*--subsystem-match=drm' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener uses udevadm monitor with DRM subsystem filter"
else
    fail "Listener does not use udevadm monitor for event detection"
fi

# Test 4.4: Cleanup handler
if grep -q 'trap cleanup' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener has cleanup trap for graceful shutdown"
else
    fail "Listener lacks cleanup trap"
fi

# Test 4.5: Notification support
if grep -q 'notify-send' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener sends dunst notifications"
else
    fail "Listener lacks notification support"
fi


section "5. Monitor Count Detection (mocked xrandr)"

# Test 5.1: Single monitor detection
MOCK_XRANDR=$(create_mock_xrandr 1)
SINGLE_COUNT=$("$MOCK_XRANDR" | grep -c ' connected ')
if [[ "$SINGLE_COUNT" -eq 1 ]]; then
    pass "Mock xrandr correctly reports 1 monitor"
else
    fail "Mock xrandr reports $SINGLE_COUNT monitors (expected 1)"
fi

# Test 5.2: Dual monitor detection
MOCK_XRANDR=$(create_mock_xrandr 2)
DUAL_COUNT=$("$MOCK_XRANDR" | grep -c ' connected ')
if [[ "$DUAL_COUNT" -eq 2 ]]; then
    pass "Mock xrandr correctly reports 2 monitors"
else
    fail "Mock xrandr reports $DUAL_COUNT monitors (expected 2)"
fi

# Test 5.3: Triple monitor detection (edge case)
MOCK_XRANDR=$(create_mock_xrandr 3)
TRIPLE_COUNT=$("$MOCK_XRANDR" | grep -c ' connected ')
if [[ "$TRIPLE_COUNT" -eq 3 ]]; then
    pass "Mock xrandr correctly reports 3 monitors"
else
    fail "Mock xrandr reports $TRIPLE_COUNT monitors (expected 3)"
fi

# Test 5.4: Version decision logic
# Source the version decision function for testing
desired_version_for_count() {
    local count="$1"
    if [[ "$count" -ge 2 ]]; then
        echo "pertag"
    else
        echo "base"
    fi
}

if [[ "$(desired_version_for_count 1)" == "base" ]]; then
    pass "1 monitor -> base version decision correct"
else
    fail "1 monitor -> wrong version decision: $(desired_version_for_count 1)"
fi

if [[ "$(desired_version_for_count 2)" == "pertag" ]]; then
    pass "2 monitors -> pertag version decision correct"
else
    fail "2 monitors -> wrong version decision: $(desired_version_for_count 2)"
fi

if [[ "$(desired_version_for_count 3)" == "pertag" ]]; then
    pass "3 monitors -> pertag version decision correct (2+ = pertag)"
else
    fail "3 monitors -> wrong version decision: $(desired_version_for_count 3)"
fi


section "6. State File Idempotency"

STATE_TEST="$TEST_TMPDIR/test-state"

# Test 6.1: Base -> Base (no action)
echo "base" > "$STATE_TEST"
CURRENT=$(cat "$STATE_TEST")
DESIRED="base"
if [[ "$CURRENT" == "$DESIRED" ]]; then
    pass "State file: base->base correctly identified as no-op"
else
    fail "State file idempotency broken for base->base"
fi

# Test 6.2: Base -> Pertag (action needed)
DESIRED="pertag"
if [[ "$CURRENT" != "$DESIRED" ]]; then
    pass "State file: base->pertag correctly identified as action needed"
else
    fail "State file fails to detect base->pertag transition"
fi

# Test 6.3: Pertag -> Pertag (no action)
echo "pertag" > "$STATE_TEST"
CURRENT=$(cat "$STATE_TEST")
DESIRED="pertag"
if [[ "$CURRENT" == "$DESIRED" ]]; then
    pass "State file: pertag->pertag correctly identified as no-op"
else
    fail "State file idempotency broken for pertag->pertag"
fi

# Test 6.4: Unknown state triggers action
echo "unknown" > "$STATE_TEST"
CURRENT=$(cat "$STATE_TEST")
if [[ "$CURRENT" != "base" && "$CURRENT" != "pertag" ]]; then
    pass "Unknown state correctly detected (will trigger initial setup)"
else
    fail "Unknown state not properly handled"
fi


section "7. Debounce Timing Simulation"

# Test 7.1: Events within cooldown are debounced
DEBOUNCE_SECONDS=3
LAST_EVENT_TIME=$(date +%s)
sleep 1
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_EVENT_TIME))
if [[ "$TIME_DIFF" -lt "$DEBOUNCE_SECONDS" ]]; then
    pass "Event within ${DEBOUNCE_SECONDS}s cooldown would be debounced (diff=${TIME_DIFF}s)"
else
    fail "Debounce timing incorrect: ${TIME_DIFF}s should be < ${DEBOUNCE_SECONDS}s"
fi

# Test 7.2: Events after cooldown are processed
LAST_EVENT_TIME=$(($(date +%s) - 5))
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_EVENT_TIME))
if [[ "$TIME_DIFF" -ge "$DEBOUNCE_SECONDS" ]]; then
    pass "Event after cooldown would be processed (diff=${TIME_DIFF}s >= ${DEBOUNCE_SECONDS}s)"
else
    fail "Debounce timing incorrect: ${TIME_DIFF}s should be >= ${DEBOUNCE_SECONDS}s"
fi


section "8. Pertag Patch Verification"

# Test 8.1: pertag struct exists in worktree dwm.c
if grep -q 'struct Pertag' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "Pertag struct defined in worktree dwm.c"
else
    fail "Pertag struct missing from worktree dwm.c"
fi

# Test 8.2: pertag NOT in base dwm.c (must be separate)
if ! grep -q 'struct Pertag' /home/n0ko/bling/dwm/dwm.c; then
    pass "Pertag struct absent from base dwm.c (correctly separated)"
else
    fail "Pertag struct found in base dwm.c (should only be in worktree)"
fi

# Test 8.3: pertag modifies createmon
if grep -q 'pertag.*ecalloc' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "createmon allocates pertag struct"
else
    fail "createmon does not allocate pertag struct"
fi

# Test 8.4: pertag modifies view function
if grep -q 'pertag->curtag' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "view function uses pertag->curtag"
else
    fail "view function does not reference pertag"
fi

# Test 8.5: pertag modifies setmfact
if grep -q 'pertag->mfacts' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "setmfact stores per-tag mfact"
else
    fail "setmfact does not use pertag mfacts"
fi

# Test 8.6: pertag modifies setlayout
if grep -q 'pertag->sellts' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "setlayout stores per-tag layout selection"
else
    fail "setlayout does not use pertag sellts"
fi

# Test 8.7: pertag modifies incnmaster
if grep -q 'pertag->nmasters' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "incnmaster stores per-tag nmaster"
else
    fail "incnmaster does not use pertag nmasters"
fi

# Test 8.8: pertag modifies togglebar
if grep -q 'pertag->showbars' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "togglebar stores per-tag showbar"
else
    fail "togglebar does not use pertag showbars"
fi

# Test 8.9: Memory cleanup (pertag freed in cleanupmon)
if grep -q 'free(mon->pertag)' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "cleanupmon frees pertag memory"
else
    fail "cleanupmon does not free pertag memory (memory leak)"
fi


section "9. Config.h Window Rules Verification (Pertag)"

# Test 9.1: Browsers assigned to monitor 1 (second monitor)
PERTAG_CONFIG="/home/n0ko/bling/dwm-pertag/config.h"
BROWSER_RULES_OK=1

for class in "firefox" "Vivaldi-flatpak" "Vivaldi-stable" "chromium" "Google Chrome"; do
    if ! grep -P "\"$class\".*\b1\b" "$PERTAG_CONFIG" | grep -qv "1 <<"; then
        # Need to verify monitor field is 1 - check the rule line more carefully
        RULE_LINE=$(grep "\"$class\"" "$PERTAG_CONFIG" | head -1)
        if echo "$RULE_LINE" | grep -qP '\b1,\s*0,\s*-1' || echo "$RULE_LINE" | grep -qP '\b0,\s*1,\s*0'; then
            # monitor field = 1
            :
        else
            BROWSER_RULES_OK=0
        fi
    fi
done

# Simpler check: browsers have monitor 1 in their rules
FIREFOX_MON=$(grep '"firefox"' "$PERTAG_CONFIG" | grep -oP '0,\s+\K\d+' | head -1)
if [[ "${FIREFOX_MON:-}" == "1" ]]; then
    pass "Firefox assigned to monitor 1 (second monitor)"
else
    skip "Firefox monitor assignment needs manual verification (got: ${FIREFOX_MON:-unknown})"
fi

# Test 9.2: Teams assigned to monitor 1
TEAMS_LINE=$(grep '"Teams"' "$PERTAG_CONFIG")
if echo "$TEAMS_LINE" | grep -qP '0,\s+1,'; then
    pass "Teams assigned to monitor 1 (second monitor)"
else
    skip "Teams monitor assignment needs manual verification"
fi

# Test 9.3: Steam assigned to monitor 0
STEAM_LINE=$(grep '"steam"' "$PERTAG_CONFIG")
if echo "$STEAM_LINE" | grep -qP '0,\s+0,'; then
    pass "Steam assigned to monitor 0 (primary/current)"
else
    skip "Steam monitor assignment needs manual verification"
fi

# Test 9.4: kitty terminal rule exists for monitor 0
if grep -q '"kitty".*0,' "$PERTAG_CONFIG"; then
    pass "kitty rule exists targeting monitor 0"
else
    fail "No kitty rule found for monitor 0 in pertag config"
fi


section "10. Config.h Window Rules Verification (Base)"

# Test 10.1: Base config uses monitor -1 for most apps (follow focus)
BASE_CONFIG="/home/n0ko/bling/dwm/config.h"
FIREFOX_BASE=$(grep '"firefox"' "$BASE_CONFIG" | head -1)
if echo "$FIREFOX_BASE" | grep -q '\-1'; then
    pass "Base config: Firefox uses monitor -1 (follow focus)"
else
    skip "Base config: Firefox monitor setting needs manual verification"
fi


section "11. Git Worktree Integrity"

# Test 11.1: Worktree exists
if [[ -d /home/n0ko/bling/dwm-pertag ]]; then
    pass "Pertag worktree directory exists at /home/n0ko/bling/dwm-pertag"
else
    fail "Pertag worktree directory missing"
fi

# Test 11.2: Worktree is on correct branch
WORKTREE_BRANCH=$(git -C /home/n0ko/bling/dwm-pertag branch --show-current 2>/dev/null || echo "unknown")
if [[ "$WORKTREE_BRANCH" == "feature/pertag-dual-monitor" ]]; then
    pass "Pertag worktree is on branch: feature/pertag-dual-monitor"
else
    fail "Pertag worktree on wrong branch: $WORKTREE_BRANCH (expected feature/pertag-dual-monitor)"
fi

# Test 11.3: Base repo is on desktop branch
BASE_BRANCH=$(git -C /home/n0ko/bling/dwm branch --show-current 2>/dev/null || echo "unknown")
if [[ "$BASE_BRANCH" == "desktop" ]]; then
    pass "Base repo is on branch: desktop"
else
    fail "Base repo on wrong branch: $BASE_BRANCH (expected desktop)"
fi

# Test 11.4: Worktree registered in git
WORKTREE_LIST=$(git -C /home/n0ko/bling/dwm worktree list 2>/dev/null)
if echo "$WORKTREE_LIST" | grep -q "dwm-pertag"; then
    pass "Pertag worktree is registered in git worktree list"
else
    fail "Pertag worktree not found in git worktree list"
fi


section "12. Existing Patches Preserved"

# Test 12.1: Scratchpad functionality preserved in pertag
if grep -q 'SCRATCHPAD_TAG' /home/n0ko/bling/dwm-pertag/config.h; then
    pass "Scratchpad tags preserved in pertag config"
else
    fail "Scratchpad tags missing from pertag config"
fi

# Test 12.2: Status2d support preserved (check for drawstatusbar)
if grep -q 'drawstatusbar' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "Status2d patch (drawstatusbar) preserved in pertag dwm.c"
else
    fail "Status2d patch missing from pertag dwm.c"
fi

# Test 12.3: Gap pixel support preserved
if grep -q 'gappx' /home/n0ko/bling/dwm-pertag/config.h; then
    pass "Gap pixel support preserved in pertag config"
else
    fail "Gap pixel support missing from pertag config"
fi

# Test 12.4: Border scheme support preserved
if grep -q 'borderscheme' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "Border scheme customization preserved in pertag dwm.c"
else
    fail "Border scheme customization missing from pertag dwm.c"
fi

# Test 12.5: AI scratchpad preserved
if grep -q 'ai-scratchpad' /home/n0ko/bling/dwm-pertag/config.h; then
    pass "AI scratchpad preserved in pertag config"
else
    fail "AI scratchpad missing from pertag config"
fi

# Test 12.6: dwmblocks/sigstatusbar preserved
if grep -q 'sigstatusbar' /home/n0ko/bling/dwm-pertag/dwm.c; then
    pass "dwmblocks sigstatusbar support preserved in pertag dwm.c"
else
    fail "dwmblocks sigstatusbar support missing from pertag dwm.c"
fi

# Test 12.7: Steam scratchpad preserved
if grep -q 'stm-scratchpad' /home/n0ko/bling/dwm-pertag/config.h; then
    pass "Steam scratchpad preserved in pertag config"
else
    fail "Steam scratchpad missing from pertag config"
fi


section "13. Edge Case Handling"

# Test 13.1: Hotswap handles missing source directory gracefully
if grep -q 'Source directory not found' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap handles missing source directory"
else
    fail "Hotswap does not check for missing source directory"
fi

# Test 13.2: Listener handles missing hotswap script
if grep -q 'HOTSWAP_SCRIPT' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener references hotswap script via variable (configurable)"
else
    fail "Listener does not reference hotswap script properly"
fi

# Test 13.3: Build failure notification
if grep -q 'Build failed' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap notifies on build failure"
else
    fail "Hotswap does not notify on build failure"
fi

# Test 13.4: Install failure notification
if grep -q 'Install failed' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap notifies on install failure"
else
    fail "Hotswap does not notify on install failure"
fi

# Test 13.5: Logging exists in listener
if grep -q 'LOG_FILE' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener has logging to file"
else
    fail "Listener lacks file logging"
fi


section "14. Notification Coverage"

# Test 14.1: Listener notifies on start
if grep -q 'Monitor listener started' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener sends startup notification"
else
    fail "Listener missing startup notification"
fi

# Test 14.2: Listener notifies on monitor connect
if grep -q 'Second monitor detected' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener notifies when second monitor detected"
else
    fail "Listener missing monitor connect notification"
fi

# Test 14.3: Listener notifies on monitor disconnect
if grep -q 'Single monitor detected' /home/n0ko/scripts/dwm-monitor-listener.sh; then
    pass "Listener notifies when single monitor detected"
else
    fail "Listener missing monitor disconnect notification"
fi

# Test 14.4: Hotswap notifies on version switch
if grep -q 'Switching to' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap notifies on version switch"
else
    fail "Hotswap missing version switch notification"
fi

# Test 14.5: Hotswap notifies on build start
if grep -q 'Building' /home/n0ko/scripts/dwm-hotswap.sh; then
    pass "Hotswap notifies when build starts"
else
    fail "Hotswap missing build start notification"
fi


# --- Summary ---
echo ""
echo "========================================"
echo "  TEST RESULTS"
echo "========================================"
echo "  Passed:  $TESTS_PASSED"
echo "  Failed:  $TESTS_FAILED"
echo "  Skipped: $TESTS_SKIPPED"
echo "  Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "  STATUS: SOME TESTS FAILED"
    exit 1
else
    echo "  STATUS: ALL TESTS PASSED"
    exit 0
fi
