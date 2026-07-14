#!/bin/bash
set -euo pipefail

# ── 02-chroot-config.sh ───────────────────────────────────────────────────────
# Runs INSIDE arch-chroot /mnt.
# Usage: 02-chroot-config.sh <hostname> <username>

LOG_FILE="${LOG_FILE:-/tmp/n0ko-chroot-$(date +%Y%m%d-%H%M%S).log}"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── Args ─────────────────────────────────────────────────────────────────────
NEW_HOSTNAME="${1:-}"
NEW_USER="${2:-}"
[[ -n "${NEW_HOSTNAME}" ]] || die "Usage: $0 <hostname> <username>"
[[ -n "${NEW_USER}" ]]     || die "Usage: $0 <hostname> <username>"

log "Starting chroot configuration for hostname='${NEW_HOSTNAME}' user='${NEW_USER}'"

# ── Timezone ──────────────────────────────────────────────────────────────────
log "Setting timezone to America/New_York..."
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
log "Timezone set."

# ── Locale ───────────────────────────────────────────────────────────────────
log "Configuring locale..."
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
log "Locale configured."

# ── Vconsole ─────────────────────────────────────────────────────────────────
log "Setting keymap..."
echo "KEYMAP=us" > /etc/vconsole.conf

# ── Hostname ─────────────────────────────────────────────────────────────────
log "Setting hostname to '${NEW_HOSTNAME}'..."
echo "${NEW_HOSTNAME}" > /etc/hostname

cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${NEW_HOSTNAME}.localdomain ${NEW_HOSTNAME}
EOF
log "Hostname and /etc/hosts configured."

# ── Create user ───────────────────────────────────────────────────────────────
log "Creating user '${NEW_USER}'..."
if id "${NEW_USER}" &>/dev/null; then
    log "User '${NEW_USER}' already exists; skipping creation."
else
    useradd -m -G wheel,audio,video,storage,optical,network,docker "${NEW_USER}"
    log "User '${NEW_USER}' created with groups: wheel,audio,video,storage,optical,network,docker"
fi

# ── Sudo ─────────────────────────────────────────────────────────────────────
log "Configuring sudo for wheel group..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ── Passwords ─────────────────────────────────────────────────────────────────
# Set NON-INTERACTIVELY by install.sh (Phase 2b) via chpasswd + verified with
# `passwd -S`. Interactive passwd here proved skippable (cai, 2026-07-13).

# ── mkinitcpio ───────────────────────────────────────────────────────────────
# Use lewis's HOOKS but strip the Cirrus/CS35L41 laptop audio MODULES
# (snd_hda_scodec_cs35l41_i2c snd_hda_scodec_cs35l41 snd_soc_cs35l41_lib cs_dsp snd_soc_cs_amp_lib)
log "Configuring mkinitcpio..."
cat > /etc/mkinitcpio.conf.d/n0ko.conf <<EOF
# n0ko AMD desktop mkinitcpio overrides
# MODULES: empty — no laptop audio codec modules needed
MODULES=()
# HOOKS: from lewis, standard systemd-boot path
HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)
EOF
log "mkinitcpio config written to /etc/mkinitcpio.conf.d/n0ko.conf"
mkinitcpio -P
log "mkinitcpio complete."

# ── systemd-boot ─────────────────────────────────────────────────────────────
log "Installing systemd-boot..."
bootctl install
log "systemd-boot installed."

# ── Bootloader config ─────────────────────────────────────────────────────────
log "Writing bootloader configuration..."
mkdir -p /boot/loader/entries

cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode auto
editor no
EOF

# Detect root partition UUID by label
ROOT_UUID="$(blkid -s UUID -o value /dev/disk/by-label/root 2>/dev/null || true)"
[[ -n "${ROOT_UUID}" ]] || {
    log "WARNING: Could not resolve UUID for /dev/disk/by-label/root. Falling back to blkid on /mnt..."
    ROOT_UUID="$(findmnt -n -o UUID /)" || true
}
[[ -n "${ROOT_UUID}" ]] || die "Could not determine root partition UUID."
log "Root UUID: ${ROOT_UUID}"

# Pick whichever microcode image pacstrap installed (intel-ucode or amd-ucode)
UCODE_LINE=""
[[ -f /boot/amd-ucode.img ]]   && UCODE_LINE="initrd  /amd-ucode.img"
[[ -f /boot/intel-ucode.img ]] && UCODE_LINE="initrd  /intel-ucode.img"
log "Microcode initrd: ${UCODE_LINE:-(none found)}"

# NVIDIA proprietary driver needs KMS enabled for a clean console/X handoff
# no `quiet`: n0ko wants the kernel message scroll visible during boot
KERNEL_OPTS="root=UUID=${ROOT_UUID} rw"
if pacman -Qq nvidia &>/dev/null; then
    KERNEL_OPTS+=" nvidia_drm.modeset=1"
    log "NVIDIA driver installed — appending nvidia_drm.modeset=1"
fi

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux (n0ko)
linux   /vmlinuz-linux
${UCODE_LINE}
initrd  /initramfs-linux.img
options ${KERNEL_OPTS}
EOF

log "Bootloader entries written."

# ── Enable system services ────────────────────────────────────────────────────
log "Enabling system services..."

SERVICES=(
    iwd
    dhcpcd
    systemd-resolved
    systemd-networkd
    sshd
    cronie
    bluetooth
    iptables
    # wg-resume: laptop-only (USB dock resume); omitted on desktop
)

for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null; then
        systemctl enable "${svc}.service"
        log "  Enabled: ${svc}"
    else
        log "  SKIP (not installed): ${svc}"
    fi
done

# Docker — enable if present
if systemctl list-unit-files docker.service &>/dev/null; then
    systemctl enable docker.service
    log "  Enabled: docker"
fi

# ollama — enable if present
if systemctl list-unit-files ollama.service &>/dev/null; then
    systemctl enable ollama.service
    log "  Enabled: ollama"
fi

# postgresql — enable if present
if systemctl list-unit-files postgresql.service &>/dev/null; then
    systemctl enable postgresql.service
    log "  Enabled: postgresql"
fi

# ── TODO: GPU/ROCm services ───────────────────────────────────────────────────
# The following services are user-space and should be enabled post-boot as the
# primary user via 'systemctl --user enable <service>':
#   pipewire.service pipewire-pulse.service wireplumber.service
#   ollama.service (if running as user)
# ROCm itself requires no additional services — it is a runtime library set.
log "NOTE: ROCm/HIP are runtime libraries — no daemon services to enable."
log "NOTE: PipeWire/WirePlumber should be enabled as --user services post-boot."

# ── systemd-resolved stub DNS ────────────────────────────────────────────────
log "Configuring systemd-resolved stub resolver..."
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
log "resolv.conf symlinked to systemd-resolved stub."

log "02-chroot-config.sh finished successfully."
