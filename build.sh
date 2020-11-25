#!/bin/bash

set -e

crun() {
  if ! [ -e '.crun' ] ; then
    mkdir '.crun'
  fi
  RAN_FILE=".crun/${1}"
  if ! [ -e "$RAN_FILE" ] ; then
    ${1} && touch "$RAN_FILE"
  fi
}

install_deps() {
  sudo pacman -S \
    archiso
}

crun install_deps

# archlive is checked in to source control, so this only runs if you've thrown it out.
if ! [ -e archlive ] ; then
  cp -r /usr/share/archiso/configs/baseline archlive
fi

# Copy personal config files from my system into the install system

jconfigs=(
  # CLI and infrastructure stuff
  '/j/.ssh/config'

  # Low-level graphics
  '/j/.Xresources'
  '/j/.Xresources.d/colors'
  '/j/.Xresources.d/fonts'
  '/j/.Xresources.d/rxvt-unicode'

  # Higher level graphics
  '/j/.config/i3/config'
  '/j/.i3status.conf'

  # Applications + stupidly large things
  #'/j/.mozilla/'
)

tar -czvf archlive/airootfs/tools/jconfigs.tar.gz "${jconfigs[@]}"

cd archlive

sudo mkarchiso \
  -A 'AzureOS' \
  -L 'AzureOS' \
  -P 'jeffrey mcateer <jeffrey.p.mcateer@gmail.com>' \
  -C pacman.conf \
  -p yay \
  -v $(pwd)

ISO_IMG=$(find $(pwd) -name '*.iso' 2>/dev/null | head -n 1 | tr -d '\n')
echo "DONE! Built $ISO_IMG"
echo "To clean, run:  sudo rm -rf archlive/out archlive/work"

echo "Booting in qemu..."

#AZURE_OS_HDA="/mnt/wdb/azure_os_hda.img"
AZURE_OS_HDA="/j/downloads/azure_os_hda.img"
if ! [ -e "$AZURE_OS_HDA" ] ; then
  sudo qemu-img create "$AZURE_OS_HDA" 24G
  sudo chown jeffrey "$AZURE_OS_HDA"
fi

# Need `yay -S edk2-ovmf` for /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
if ! [ -e "$OVMF_CODE" ] ; then
  echo "Please install 'edk2-ovmf' so the file $OVMF_CODE is available."
fi

qemu-system-x86_64 \
  -bios "$OVMF_CODE" \
  -boot d \
  -cdrom "$ISO_IMG" \
  -m 2048 \
  -drive format=raw,file="$AZURE_OS_HDA"





