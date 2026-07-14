# Build Instructions

## Prerequisites

```bash
sudo pacman -S archiso
```

## Create working directories

```bash
sudo mkdir -p /tmp/archiso-work /tmp/archiso-out
```

## Build the ISO

```bash
sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out /home/n0ko/arch-desktop-installer/profile/
```

The ISO will appear at:

```
/tmp/archiso-out/n0ko-arch-2026.07-x86_64.iso
```

(Exact filename includes the version date from profiledef.sh.)

## Clean up working directory between rebuilds

```bash
sudo rm -rf /tmp/archiso-work && sudo mkdir -p /tmp/archiso-work
```

## Write ISO to USB

```bash
sudo dd if=/tmp/archiso-out/n0ko-arch-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with your USB device. Use `lsblk` to identify it.
