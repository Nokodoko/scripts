#!/bin/bash
set -euo pipefail

# ── 01-pacstrap.sh ────────────────────────────────────────────────────────────
# Installs base system + curated package list to /mnt via pacstrap,
# generates fstab, and copies the n0ko-install directory into the new root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/n0ko-pacstrap-$(date +%Y%m%d-%H%M%S).log}"
PKG_LIST="${SCRIPT_DIR}/pkgs-native.curated.txt"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────
[[ -d /mnt ]] || die "/mnt does not exist — run 00-partition.sh first."
mountpoint -q /mnt || die "/mnt is not mounted — run 00-partition.sh first."
mountpoint -q /mnt/boot || die "/mnt/boot is not mounted — run 00-partition.sh first."
[[ -f "${PKG_LIST}" ]] || die "Package list not found: ${PKG_LIST}"

# ── Read curated package list ─────────────────────────────────────────────────
log "Reading package list from: ${PKG_LIST}"
mapfile -t EXTRA_PKGS < <(grep -v '^[[:space:]]*$' "${PKG_LIST}" | grep -v '^#')
log "Loaded ${#EXTRA_PKGS[@]} packages from curated list."

# ── Hardware detection: CPU microcode + GPU drivers ──────────────────────────
CPU_VENDOR="$(grep -m1 '^vendor_id' /proc/cpuinfo | awk '{print $3}')"
case "${CPU_VENDOR}" in
    GenuineIntel) UCODE_PKG="intel-ucode" ;;
    AuthenticAMD) UCODE_PKG="amd-ucode" ;;
    *)            log "WARNING: unknown CPU vendor '${CPU_VENDOR}' — defaulting to amd-ucode"
                  UCODE_PKG="amd-ucode" ;;
esac
log "CPU: ${CPU_VENDOR} -> ${UCODE_PKG}"

GPU_INFO="$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)"
log "GPU(s) detected:"
log "${GPU_INFO:-  (none)}"

AMD_GPU_PKGS=(vulkan-radeon rocm-hip-sdk hip-runtime-amd rocm-opencl-runtime libva-mesa-driver)
NVIDIA_GPU_PKGS=(nvidia nvidia-utils nvidia-settings opencl-nvidia)
INTEL_GPU_PKGS=(vulkan-intel intel-media-driver)

GPU_PKGS=()
if grep -qi 'nvidia' <<<"${GPU_INFO}"; then
    GPU_PKGS+=("${NVIDIA_GPU_PKGS[@]}")
    log "NVIDIA GPU -> ${NVIDIA_GPU_PKGS[*]}"
fi
if grep -qiE 'amd|ati|radeon' <<<"${GPU_INFO}"; then
    GPU_PKGS+=("${AMD_GPU_PKGS[@]}")
    log "AMD GPU -> ${AMD_GPU_PKGS[*]}"
fi
if grep -qi 'intel' <<<"${GPU_INFO}"; then
    GPU_PKGS+=("${INTEL_GPU_PKGS[@]}")
    log "Intel GPU -> ${INTEL_GPU_PKGS[*]}"
fi
if [[ ${#GPU_PKGS[@]} -eq 0 ]]; then
    log "WARNING: no GPU vendor matched — installing mesa only"
    GPU_PKGS=(mesa)
fi

# Strip hardware-specific packages from the curated list; detection re-adds the
# correct set for THIS machine (curated list was snapshotted from an AMD host).
HW_SPECIFIC_RE='^(amd-ucode|intel-ucode|vulkan-radeon|rocm-.*|hip-.*|opencl-nvidia|nvidia.*|vulkan-intel|intel-media-driver|xf86-video-.*)$'
FILTERED_PKGS=()
for pkg in "${EXTRA_PKGS[@]}"; do
    [[ "$pkg" =~ ${HW_SPECIFIC_RE} ]] || FILTERED_PKGS+=("$pkg")
done
log "Curated list: ${#EXTRA_PKGS[@]} pkgs, ${#FILTERED_PKGS[@]} after hw-specific strip."
EXTRA_PKGS=("${FILTERED_PKGS[@]}")

# ── Base packages always included ─────────────────────────────────────────────
BASE_PKGS=(
    base
    base-devel
    linux
    linux-headers
    linux-firmware
    "${UCODE_PKG}"
)

# ── Merge (base + hw-detected + curated, deduped) ─────────────────────────────
ALL_PKGS=()
declare -A seen
for pkg in "${BASE_PKGS[@]}" "${GPU_PKGS[@]}" "${EXTRA_PKGS[@]}"; do
    if [[ -z "${seen[$pkg]+x}" ]]; then
        seen["$pkg"]=1
        ALL_PKGS+=("$pkg")
    fi
done

log "Total packages to install: ${#ALL_PKGS[@]}"

# ── Pacstrap ─────────────────────────────────────────────────────────────────
log "Running pacstrap... (this may take a while)"
pacstrap -K /mnt "${ALL_PKGS[@]}" 2>&1 | tee -a "${LOG_FILE}"
log "Pacstrap complete."

# ── Generate fstab ────────────────────────────────────────────────────────────
log "Generating /mnt/etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
log "fstab written:"
cat /mnt/etc/fstab | tee -a "${LOG_FILE}"

# ── Copy installer into new root ──────────────────────────────────────────────
log "Copying n0ko-install into /mnt/root/n0ko-install..."
mkdir -p /mnt/root/n0ko-install
cp -r "${SCRIPT_DIR}/." /mnt/root/n0ko-install/
chmod 755 /mnt/root/n0ko-install/*.sh
log "Installer scripts copied."

log "01-pacstrap.sh finished successfully."
