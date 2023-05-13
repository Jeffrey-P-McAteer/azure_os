#!/bin/bash


ISO_IMG=$(find $(pwd) -name '*.iso' 2>/dev/null | head -n 1 | tr -d '\n')
echo "DONE! Built $ISO_IMG"

echo "To clean, run:  sudo rm -rf archlive/out archlive/work"
echo "To release keyboard press ctrl+alt+g "

echo "Booting in qemu..."

#AZURE_OS_HDA="/mnt/wdb/azure_os_hda.img"
#AZURE_OS_HDA="/j/downloads/azure_os_hda.img"
# # AZURE_OS_HDA="/dev/sda"

AZURE_OS_HDA="/mnt/scratch/azure_os_hda.img"

if grep -q '/dev/' <<<"$AZURE_OS_HDA" ; then
  cat <<EOF
WARNING: AZURE_OS_HDA=$AZURE_OS_HDA, which looks like a physical disk!
Ok to overwrite it?
EOF
  read yn
  if ! grep -qi 'y' in <<<"$yn" ; then
    echo "Exiting..."
    exit 1
  fi
fi

if ! [ -e "$AZURE_OS_HDA" ] ; then
  sudo qemu-img create "$AZURE_OS_HDA" 24G
  sudo chown jeffrey "$AZURE_OS_HDA"
fi


# Need `yay -S edk2-ovmf` for /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
if ! [ -e "$OVMF_CODE" ] ; then
  echo "Please install 'edk2-ovmf' so the file $OVMF_CODE is available."
  exit 1
fi

cat <<EOF

====================== BOOTING ======================

EOF

qemu-system-x86_64 \
  -bios "$OVMF_CODE" \
  -enable-kvm -cpu host -boot d \
  -cdrom "$ISO_IMG" \
  -m 4096 -net user -net nic \
  -drive format=raw,file="$AZURE_OS_HDA" || true

cat <<EOF
To run a test VM:

qemu-system-x86_64 -bios "$OVMF_CODE" -enable-kvm -cpu host -m 4096 -net user -net nic -drive format=raw,file="$AZURE_OS_HDA"

EOF


