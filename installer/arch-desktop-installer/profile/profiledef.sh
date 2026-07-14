#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="n0ko-arch"
iso_label="N0KO_ARCH_202607"
iso_publisher="n0ko <https://github.com/Nokodoko>"
iso_application="n0ko Arch Linux AMD/ROCm Desktop Installer"
iso_version="2026.07"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/root/n0ko-install/install.sh"]="0:0:755"
  ["/root/n0ko-install/00-partition.sh"]="0:0:755"
  ["/root/n0ko-install/01-pacstrap.sh"]="0:0:755"
  ["/root/n0ko-install/02-chroot-config.sh"]="0:0:755"
  ["/root/n0ko-install/03-userland.sh"]="0:0:755"
)
