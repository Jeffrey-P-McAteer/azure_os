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
  '/j/.gitconfig'

  # Low-level graphics
  '/j/.Xresources'
  '/j/.Xresources.d/colors'
  '/j/.Xresources.d/fonts'
  '/j/.Xresources.d/rxvt-unicode'

  # Higher level graphics
  '/j/.config/i3/config'
  '/j/.i3status.conf'
  '/j/.config/dunst'
  '/j/.config/mpv/mpv.conf'
  '/j/.config/nitrogen/'
  '/j/.config/sublime-text-3/'
  '/j/.config/yay/config.json'
  '/j/.fonts/'
  '/j/.config/user-dirs.dirs'

  '/j/.profile'
  '/j/.zprofile'
  '/j/.zshrc'
  '/j/.oh-my-zsh/'
  
  '/j/.icons/default/index.theme'
  '/j/.config/gtk-3.0'
  '/j/.config/gtk-2.0'

  '/j/.config/rclone'

  '/j/.streamlinkrc'

  # Documents
  '/j/docs/pw'

  '/j/photos'

  # Keep my secrets
  '/j/ident/'

  # MY applications (reasonably sized I assure... nobody)
  # '/j/bins/azure-os/'
  # '/j/bins/azure-angel-backup'
  # '/j/bins/music-fetch.py'
  # '/j/bins/import-wp.sh'
  # '/j/bins/eventmgr.py'
  # '/j/bins/srvmgr.py'
  # '/j/bins/backlight-up'
  # '/j/bins/backlight-down'
  # '/j/bins/volume-up'
  # '/j/bins/volume-down'
  # '/j/bins/d'
  '/j/bins/'
  
  # enhancements to existing programs
  # '/j/bins/rmpv'
  # '/j/bins/mpvep'
  # '/j/bins/gdbbin'
  # '/j/bins/pause-procs'

  '/j/bin/'

  # Applications + stupidly large things
  '/j/.mozilla/'
  
  # Personal OS stuff
  '/etc/systemd/system/eventmgr.service'
  '/etc/systemd/system/srvmgr.service'
  '/etc/systemd/system/portfwd.service'

  '/etc/systemd/nspawn/steamcontainer.nspawn'
  '/etc/systemd/system/systemd-nspawn@.service.d/override.conf'

  '/etc/X11/xorg.conf.d/70-synaptics.conf'

  '/etc/modules-load.d/intel-gvt-g.conf'

  # OS stuff
  '/etc/radicale/'
  '/var/lib/radicale'

  '/etc/sudoers.d/jeffrey'
  '/etc/udev/rules.d/99-thunderbolt-auto-auth.rules' # ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
  
)

sudo tar -czvf archlive/airootfs/tools/jconfigs.tar.gz \
  --exclude=target --exclude=build --exclude=mkarchiso --exclude=work --exclude=out --exclude=jconfigs.tar.gz \
  "${jconfigs[@]}"

# Drop in a default network DHCP handler for ethernet conns
mkdir -p archlive/airootfs/etc/systemd/network/
cat >archlive/airootfs/etc/systemd/network/20-default.network <<EOF
[Match]
Name=*

[Network]
DHCP=ipv4
UseDNS=yes
DNS=1.1.1.1

EOF
mkdir -p archlive/airootfs/etc/systemd/system/multi-user.target.wants/

ln -nsf /usr/lib/systemd/system/systemd-networkd.service archlive/airootfs/etc/systemd/system/multi-user.target.wants/
ln -nsf /usr/lib/systemd/system/systemd-resolved.service archlive/airootfs/etc/systemd/system/multi-user.target.wants/



# Now build the iso

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
#AZURE_OS_HDA="/j/downloads/azure_os_hda.img"
AZURE_OS_HDA="/dev/sda"
if ! [ -e "$AZURE_OS_HDA" ] ; then
  sudo qemu-img create "$AZURE_OS_HDA" 24G
  sudo chown jeffrey "$AZURE_OS_HDA"
fi

# Need `yay -S edk2-ovmf` for /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
if ! [ -e "$OVMF_CODE" ] ; then
  echo "Please install 'edk2-ovmf' so the file $OVMF_CODE is available."
fi

cat <<EOF

====================== BOOTING ======================

EOF

qemu-system-x86_64 \
  -bios "$OVMF_CODE" \
  -enable-kvm -cpu host -boot d \
  -cdrom "$ISO_IMG" \
  -nographic -serial mon:stdio \
  -m 3048 -net user -net nic \
  -drive format=raw,file="$AZURE_OS_HDA"

cat <<EOF
To run a test VM:

qemu-system-x86_64 -bios "$OVMF_CODE" -enable-kvm -cpu host -m 3048 -net user -net nic -drive format=raw,file="$AZURE_OS_HDA"

EOF



