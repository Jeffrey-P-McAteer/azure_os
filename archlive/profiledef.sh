#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="azure-os-baseline"
iso_label="ARCH_$(date +%Y%m)"
iso_publisher="Jeffrey McAteer <jeffrey.p.mcateer@gmail.com>"
iso_application="Azure OS"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
bootmodes=('uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"

