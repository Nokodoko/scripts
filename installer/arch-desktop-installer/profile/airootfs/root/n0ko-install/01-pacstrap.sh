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

# ── Base packages always included ─────────────────────────────────────────────
BASE_PKGS=(
    base
    base-devel
    linux
    linux-headers
    linux-firmware
    amd-ucode
)

# ── Merge (base + curated, deduped) ──────────────────────────────────────────
ALL_PKGS=()
declare -A seen
for pkg in "${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}"; do
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
