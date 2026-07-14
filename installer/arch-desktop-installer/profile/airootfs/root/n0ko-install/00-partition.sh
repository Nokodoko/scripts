#!/bin/bash
set -euo pipefail

# ── 00-partition.sh ───────────────────────────────────────────────────────────
# SAFETY-CRITICAL: partitions and formats TARGET_DISK.
# Called by install.sh with TARGET_DISK set in environment,
# or pass disk name as $1 (without /dev/).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/n0ko-partition-$(date +%Y%m%d-%H%M%S).log}"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── Resolve target disk ───────────────────────────────────────────────────────
TARGET_DISK="${1:-${TARGET_DISK:-}}"
[[ -n "${TARGET_DISK}" ]] || die "TARGET_DISK not set. Pass as \$1 or export before sourcing."
[[ -b "/dev/${TARGET_DISK}" ]] || die "/dev/${TARGET_DISK} is not a block device."

log "Target disk: /dev/${TARGET_DISK}"

# ── Detect live boot device (do NOT touch it) ─────────────────────────────────
log "Detecting live boot device..."
LIVE_BOOT_DEV=""

# Try to find the backing block device of the archiso mountpoint
LIVE_SOURCE="$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null || true)"
if [[ -n "${LIVE_SOURCE}" ]]; then
    # Strip partition number suffix to get the base device name (e.g. sdb1 -> sdb, nvme0n1p1 -> nvme0n1)
    LIVE_BOOT_DEV="$(lsblk -no pkname "${LIVE_SOURCE}" 2>/dev/null | head -1 || true)"
    log "Live ISO source: ${LIVE_SOURCE} → base device: ${LIVE_BOOT_DEV:-unknown}"
fi

# Fallback: scan for ISO9660 / vfat on removable devices
if [[ -z "${LIVE_BOOT_DEV}" ]]; then
    log "findmnt method failed; scanning for removable media..."
    for dev in /sys/block/*/removable; do
        [[ -f "${dev}" ]] || continue
        if [[ "$(cat "${dev}")" == "1" ]]; then
            candidate="$(basename "$(dirname "${dev}")")"
            log "  Removable candidate: ${candidate}"
            LIVE_BOOT_DEV="${candidate}"
            break
        fi
    done
fi

log "Live boot device resolved to: '${LIVE_BOOT_DEV:-<could not determine>}'"

# ── Safety checks ─────────────────────────────────────────────────────────────
if [[ -n "${LIVE_BOOT_DEV}" && "${TARGET_DISK}" == "${LIVE_BOOT_DEV}" ]]; then
    die "TARGET_DISK (${TARGET_DISK}) matches the live boot device (${LIVE_BOOT_DEV}). Refusing to proceed."
fi

# Check for mounted partitions on the target
MOUNTED=$(lsblk -no MOUNTPOINTS "/dev/${TARGET_DISK}" 2>/dev/null | grep -v '^$' || true)
if [[ -n "${MOUNTED}" ]]; then
    die "Target disk /dev/${TARGET_DISK} has mounted partitions:\n${MOUNTED}\nUnmount them first."
fi

# ── Show disk info ────────────────────────────────────────────────────────────
log "Target disk details:"
lsblk -o NAME,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS "/dev/${TARGET_DISK}" | tee -a "${LOG_FILE}"

echo ""
echo "All non-live block devices for reference:"
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,FSTYPE,MOUNTPOINTS | grep -v "^${LIVE_BOOT_DEV:-NOLIVEDEV}" | tee -a "${LOG_FILE}"
echo ""

# ── Final typed confirmation ──────────────────────────────────────────────────
echo "WARNING: ALL DATA ON /dev/${TARGET_DISK} WILL BE PERMANENTLY DESTROYED."
read -rp "Type YES (exactly) to proceed with partitioning: " PART_CONFIRM
[[ "${PART_CONFIRM}" == "YES" ]] || die "Partitioning aborted by operator."

# ── Wipe ─────────────────────────────────────────────────────────────────────
log "Wiping /dev/${TARGET_DISK}..."
wipefs -a "/dev/${TARGET_DISK}"
sgdisk --zap-all "/dev/${TARGET_DISK}"
log "Wipe complete."

# ── Create GPT partitions ─────────────────────────────────────────────────────
log "Creating GPT partition table on /dev/${TARGET_DISK}..."

sgdisk \
    --new=1:0:+512M   --typecode=1:EF00 --change-name=1:"EFI" \
    --new=2:0:+20G    --typecode=2:8200 --change-name=2:"swap" \
    --new=3:0:+100G   --typecode=3:8300 --change-name=3:"root" \
    --new=4:0:0       --typecode=4:8300 --change-name=4:"home" \
    "/dev/${TARGET_DISK}"

# Inform kernel of new partition table
partprobe "/dev/${TARGET_DISK}"
sleep 1

log "Partition table written."

# ── Determine partition suffix ────────────────────────────────────────────────
# NVMe uses p1/p2/p3/p4; SATA/USB uses 1/2/3/4
if [[ "${TARGET_DISK}" == nvme* || "${TARGET_DISK}" == mmcblk* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

P1="/dev/${TARGET_DISK}${PART_SUFFIX}1"
P2="/dev/${TARGET_DISK}${PART_SUFFIX}2"
P3="/dev/${TARGET_DISK}${PART_SUFFIX}3"
P4="/dev/${TARGET_DISK}${PART_SUFFIX}4"

# Wait for partition nodes
for part in "${P1}" "${P2}" "${P3}" "${P4}"; do
    local_timeout=10
    while [[ ! -b "${part}" && ${local_timeout} -gt 0 ]]; do
        sleep 1
        (( local_timeout-- ))
    done
    [[ -b "${part}" ]] || die "Partition node ${part} did not appear after 10 seconds."
done

# ── Format partitions ─────────────────────────────────────────────────────────
log "Formatting ${P1} as EFI (vfat)..."
mkfs.vfat -F32 -n EFI "${P1}"

log "Formatting ${P2} as swap..."
mkswap -L swap "${P2}"
swapon "${P2}"

log "Formatting ${P3} as ext4 (root)..."
mkfs.ext4 -L root "${P3}"

log "Formatting ${P4} as ext4 (home)..."
mkfs.ext4 -L home "${P4}"

# ── Mount ─────────────────────────────────────────────────────────────────────
log "Mounting filesystems..."
mount "${P3}" /mnt
mkdir -p /mnt/boot /mnt/home
mount "${P1}" /mnt/boot
mount "${P4}" /mnt/home

log "Mount complete."

# ── Verify ───────────────────────────────────────────────────────────────────
log "Final disk state:"
lsblk "/dev/${TARGET_DISK}" | tee -a "${LOG_FILE}"

log "00-partition.sh finished successfully."
