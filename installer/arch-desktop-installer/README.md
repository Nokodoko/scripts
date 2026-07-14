# n0ko-arch AMD/ROCm Desktop Installer

Custom Arch Linux archiso profile targeting a new AMD/ROCm desktop host
at parity with the lewis installation.

---

## How to Build the ISO

See [BUILD.md](BUILD.md) for full instructions. Quick version:

```bash
sudo mkdir -p /tmp/archiso-work /tmp/archiso-out
sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out /home/n0ko/arch-desktop-installer/profile/
```

---

## How to Boot and Run the Installer

1. Write the ISO to a USB drive.
2. Boot the target machine from USB (UEFI mode required).
3. At the live shell, the MOTD will greet you. Run:

```bash
/root/n0ko-install/install.sh
```

The script will:
- Verify UEFI firmware
- Enable NTP
- Prompt for target disk, hostname, and username
- Print a summary and require you to type `YES` to proceed
- Partition, format, pacstrap, and chroot-configure the new system

---

## Partition Layout

| Partition | Size     | Type          | Label | Mount   |
|-----------|----------|---------------|-------|---------|
| p1        | 512 MiB  | EFI (EF00)    | EFI   | /boot   |
| p2        | 20 GiB   | swap (8200)   | swap  | [swap]  |
| p3        | 100 GiB  | Linux (8300)  | root  | /       |
| p4        | remainder | Linux (8300) | home  | /home   |

All on a single NVMe (or SATA) disk, GPT, ext4 for root and home.

**Note:** The lewis fstab also mounts btrfs subvolumes for
`/mnt/ollama-models`, `/var/lib/containers`, `/mnt/datasets`,
`/mnt/seclab`, and `/var/lib/databases` from a second drive.
These are NOT created by this installer — add them to `/etc/fstab`
manually after attaching the data drive.

---

## Post-Install Steps

After the installer completes and you reboot:

1. Log in as your new user.
2. Copy the installer to your home directory:

```bash
sudo cp -r /root/n0ko-install ~/n0ko-install
sudo chown -R $USER:$USER ~/n0ko-install
```

3. Run the userland script (as your normal user, NOT root):

```bash
bash ~/n0ko-install/03-userland.sh
```

This will:
- Bootstrap `yay` (AUR helper)
- Install all AUR packages from `pkgs-aur.curated.txt`
- Clone all git repos from `git_repo_list` into `~/repos/`
- Enable PipeWire user services

---

## Files Reference

```
arch-desktop-installer/
├── BUILD.md                          # Build command and instructions
├── README.md                         # This file
└── profile/
    ├── profiledef.sh                 # ISO metadata (name, label, modes)
    ├── packages.x86_64               # Live ISO packages (releng + git)
    ├── pacman.conf                   # pacman config (multilib enabled)
    └── airootfs/
        ├── etc/
        │   └── motd                  # Live ISO welcome message
        └── root/
            └── n0ko-install/
                ├── install.sh        # Main orchestrator
                ├── 00-partition.sh   # Partition + format (safety-critical)
                ├── 01-pacstrap.sh    # pacstrap + fstab + copy scripts
                ├── 02-chroot-config.sh  # chroot: locale, users, boot, services
                ├── 03-userland.sh    # Post-boot: yay, AUR, git repos
                ├── pkgs-native.curated.txt  # Curated native package list
                ├── pkgs-aur.curated.txt     # Curated AUR package list
                ├── exclusions.txt    # Packages dropped and why
                └── git_repo_list    # Nokodoko repos to clone
```

---

## Key Decisions / Review Points

- **Swap size** is fixed at 20 GiB. Adjust in `00-partition.sh` if the
  desktop has more RAM and needs a larger swap for hibernation.
- **Root partition** is fixed at 100 GiB. Adjust if `/var/lib/...` mounts
  are not on a separate data drive.
- **AUR packages** include `yay` itself — this is intentional so
  `03-userland.sh`'s bootstrap can skip if yay is already present.
- **ollama + ollama-rocm** are in the native list; point `/mnt/ollama-models`
  at the data drive btrfs subvolume post-install.
- **smu-guard** was dropped (laptop AMD power limit guard, not needed on desktop).
- **asusctl/asusd** dropped (ASUS laptop daemon).
- **intel-ucode** is absent from pkgs-native.txt; `amd-ucode` is used instead
  and is already in the releng packages.x86_64 list.
