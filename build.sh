#!/bin/bash

set -e

# Conditional run, uses a directory to check if a step has occurred. If so, step is skipped.
crun() {
  if ! [ -e '.crun' ] ; then
    mkdir '.crun'
  fi
  RAN_FILE=".crun/${1}"
  if ! [ -e "$RAN_FILE" ] ; then
    ${1} && touch "$RAN_FILE"
  fi
}

# Installs dependencies for the host building the OS
install_deps() {
  sudo pacman -S \
    archiso
}

crun install_deps

# archlive is checked in to source control, so this only runs if you've thrown it out.
if ! [ -e archlive ] ; then
  cp -r /usr/share/archiso/configs/baseline archlive
else
  # Do fast rsync to update files; every now & then maybe we should purge everything that
  # isn't archlive/airootfs/tools?
  sudo find archlive -type f -not -path 'archlive/airootfs/tools*' -print -delete

  rsync -r /usr/share/archiso/configs/baseline/ archlive

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
  '/j/.config/i3/'
  '/j/.config/i3/config'
  '/j/.i3status.conf'
  '/j/.config/sway/'
  '/j/.config/sway/config'
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
  '/j/.zlogin'
  '/j/.oh-my-zsh/'

  '/j/.config/alacritty/'
  '/j/.config/alacritty/alacritty.yml'
  
  '/j/.icons/default/index.theme'
  '/j/.config/gtk-3.0'
  '/j/.config/gtk-2.0'

  '/j/.config/rclone'

  '/j/.streamlinkrc'

  # Documents
  '/j/docs/'
  '/j/docs/pw'

  '/j/lists/'

  # Task management data
  '/j/.clikan.yaml'
  '/j/.clikan.dat'


  #'/j/photos'
  #'/j/infra'
  #'/j/music'

  # Keep my secrets
  '/j/ident/'
  '/j/.gnupg/' # gpg --list-secret-keys --keyid-format LONG

  # MY applications (reasonably sized I assure... nobody)
  '/j/bins/'

  '/j/bin/'

  # Applications + stupidly large things
  '/j/.mozilla/'
  '/j/.config/mimeapps.list'
  
  # Personal OS stuff
  '/etc/systemd/system.conf'
  '/etc/systemd/system/eventmgr.service'
  '/etc/systemd/system/srvmgr.service'
  '/etc/systemd/system/portfwd.service'
  '/etc/systemd/network/' # copies ALL my network files

  #'/etc/systemd/nspawn/steamcontainer.nspawn'
  '/etc/systemd/system/systemd-nspawn@.service.d/override.conf'

  '/etc/X11/xorg.conf.d/70-synaptics.conf'

  '/etc/modules-load.d/intel-gvt-g.conf'

  # Not sure what adds the thinkpad_acpi module but it didn't have to be installed
  '/etc/modprobe.d/thinkpad_acpi.conf'
  '/etc/modprobe.d/nobeep.conf'

  '/etc/intel-undervolt.conf'
  '/etc/fwupd/daemon.conf'

  '/etc/makepkg.conf'

  # OS stuff
  '/etc/radicale/'
  '/etc/ssl/radicale.key.pem'
  '/etc/ssl/radicale.cert.pem'
  '/var/lib/radicale'

  '/etc/X11/xorg.conf.d/51-joystick.conf'

  '/etc/sudoers.d/jeffrey'
  '/etc/udev/rules.d/99-thunderbolt-auto-auth.rules'
  '/etc/udev/rules.d/00-usb-permissions.rules'
  
)


sudo du -sh \
  --exclude=target --exclude=build --exclude=mkarchiso --exclude=work --exclude=out --exclude=Index --exclude=Cache --exclude=jconfigs.tar.gz \
  "${jconfigs[@]}"

echo 'Beginning archive...'
sleep 1

sudo tar -czvf archlive/airootfs/tools/jconfigs.tar.gz \
  --exclude=target --exclude=build --exclude=mkarchiso --exclude=work --exclude=out --exclude=Index --exclude=Cache --exclude=jconfigs.tar.gz \
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

# Enable important services
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
  -nographic -serial mon:stdio \
  -m 3048 -net user -net nic \
  -drive format=raw,file="$AZURE_OS_HDA"

cat <<EOF
To run a test VM:

qemu-system-x86_64 -bios "$OVMF_CODE" -enable-kvm -cpu host -m 3048 -net user -net nic -drive format=raw,file="$AZURE_OS_HDA"

EOF



