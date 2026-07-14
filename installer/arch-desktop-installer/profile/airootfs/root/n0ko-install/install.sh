#!/bin/bash
set -euo pipefail

# ── n0ko-arch desktop installer orchestrator ──────────────────────────────────
# Runs from the live ISO as root. Sources sub-scripts in order.
# Usage: /root/n0ko-install/install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/n0ko-install-$(date +%Y%m%d-%H%M%S).log"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── UEFI check ────────────────────────────────────────────────────────────────
log "Checking for UEFI firmware..."
[[ -d /sys/firmware/efi ]] || die "/sys/firmware/efi not found. This installer requires UEFI boot. Aborting."
log "UEFI confirmed."

# ── NTP ───────────────────────────────────────────────────────────────────────
log "Enabling NTP..."
timedatectl set-ntp true
log "NTP enabled."

# ── Prompt for required inputs ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  n0ko-arch AMD/ROCm Desktop Installer"
echo "═══════════════════════════════════════════════════════════"
echo ""
log "Listing available block devices:"
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,MOUNTPOINTS
echo ""

read -rp "TARGET_DISK (e.g. nvme0n1 or sda, without /dev/): " TARGET_DISK
[[ -n "${TARGET_DISK}" ]] || die "TARGET_DISK cannot be empty."
[[ -b "/dev/${TARGET_DISK}" ]] || die "/dev/${TARGET_DISK} is not a block device."

read -rp "HOSTNAME for the new system: " NEW_HOSTNAME
[[ -n "${NEW_HOSTNAME}" ]] || die "HOSTNAME cannot be empty."

read -rp "USERNAME for the primary user account: " NEW_USER
[[ -n "${NEW_USER}" ]] || die "USERNAME cannot be empty."

# ── Passwords (collected UP FRONT; applied + verified after chroot phase) ─────
# Interactive passwd inside the chroot script proved unreliable (cai install
# 2026-07-13 finished with root locked + user passwordless). Collect here.
prompt_password() {
    local label="$1" pw1 pw2
    while :; do
        read -rsp "Password for ${label}: " pw1; echo >&2
        read -rsp "Confirm password for ${label}: " pw2; echo >&2
        [[ -n "${pw1}" ]] || { echo "Empty password not allowed." >&2; continue; }
        [[ "${pw1}" == "${pw2}" ]] || { echo "Mismatch, try again." >&2; continue; }
        printf '%s' "${pw1}"
        return 0
    done
}
ROOT_PW="$(prompt_password root)"
USER_PW="$(prompt_password "${NEW_USER}")"

# ── Confirmation ──────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  INSTALLATION SUMMARY"
echo "  Target disk : /dev/${TARGET_DISK}"
echo "  Hostname    : ${NEW_HOSTNAME}"
echo "  Username    : ${NEW_USER}"
echo ""
echo "  Partition layout:"
echo "    /dev/${TARGET_DISK}p1  512 MiB  EFI (vfat)"
echo "    /dev/${TARGET_DISK}p2   20 GiB  swap"
echo "    /dev/${TARGET_DISK}p3  100 GiB  root ext4"
echo "    /dev/${TARGET_DISK}p4 <rest>    home ext4"
echo ""
echo "  ALL DATA ON /dev/${TARGET_DISK} WILL BE DESTROYED."
echo "═══════════════════════════════════════════════════════════"
echo ""
read -rp "Type YES (exactly) to proceed: " CONFIRM
[[ "${CONFIRM}" == "YES" ]] || die "Confirmation not received. Aborting."

# ── Export variables for sub-scripts ─────────────────────────────────────────
export TARGET_DISK NEW_HOSTNAME NEW_USER SCRIPT_DIR LOG_FILE

# ── Phase 0: Partition & format ───────────────────────────────────────────────
log "=== PHASE 0: Partitioning /dev/${TARGET_DISK} ==="
bash "${SCRIPT_DIR}/00-partition.sh"
log "=== PHASE 0 complete ==="

# ── Phase 1: Pacstrap ─────────────────────────────────────────────────────────
log "=== PHASE 1: Pacstrap ==="
bash "${SCRIPT_DIR}/01-pacstrap.sh"
log "=== PHASE 1 complete ==="

# ── Phase 2: Chroot configuration ────────────────────────────────────────────
log "=== PHASE 2: Chroot config ==="
arch-chroot /mnt bash /root/n0ko-install/02-chroot-config.sh "${NEW_HOSTNAME}" "${NEW_USER}"
log "=== PHASE 2 complete ==="

# ── Phase 2b: Apply + VERIFY passwords (non-interactive, cannot be skipped) ───
log "=== PHASE 2b: Setting passwords ==="
printf 'root:%s\n' "${ROOT_PW}"          | arch-chroot /mnt chpasswd
printf '%s:%s\n' "${NEW_USER}" "${USER_PW}" | arch-chroot /mnt chpasswd
unset ROOT_PW USER_PW
# verify: `passwd -S` must report P (usable password) for both accounts
for acct in root "${NEW_USER}"; do
    state="$(arch-chroot /mnt passwd -S "${acct}" 2>/dev/null | awk '{print $2}')"
    [[ "${state}" == "P" ]] || die "Password for '${acct}' NOT set (state=${state:-unknown}). DO NOT REBOOT — run: arch-chroot /mnt passwd ${acct}"
    log "Password verified for ${acct} (state=P)"
done
log "=== PHASE 2b complete ==="

# ── Phase 3: Post-boot userland instructions ──────────────────────────────────
log "=== PHASE 3: Post-boot instructions ==="
bash "${SCRIPT_DIR}/03-userland.sh" --print-instructions
log "=== PHASE 3 complete ==="

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
log "Installation complete. Full log: ${LOG_FILE}"
log "Next steps:"
log "  1. umount -R /mnt"
log "  2. reboot (remove ISO media)"
log "  3. Log in as ${NEW_USER}"
log "  4. Run: /root/n0ko-install/03-userland.sh"
echo ""
