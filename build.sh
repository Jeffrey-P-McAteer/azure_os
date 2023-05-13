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
  cp -r /usr/share/archiso/configs/releng ./archlive
else
  # Do fast rsync to update files; every now & then maybe we should purge everything that
  # isn't archlive/airootfs/tools?
  if ! [ -z "$CLEAR_ARCHLIVE" ] ; then
    echo "Clearing arch live files..."
    sleep 1

    sudo find ./archlive -type f -not -path './archlive/airootfs/tools*' -print -delete

    rsync --verbose -r --links \
      /usr/share/archiso/configs/releng/ \
      ./archlive/
  fi
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

PACKAGE_JCONFIGS=true
if [ -e archlive/airootfs/tools/jconfigs.tar.gz ] ; then
  JCONFIGS_AGE_S=$(($(date +'%s') - $(stat -c '%Y' archlive/airootfs/tools/jconfigs.tar.gz)))
  if [ "$JCONFIGS_AGE_S" -lt '900' ] ; then
    echo "archlive/airootfs/tools/jconfigs.tar.gz is $JCONFIGS_AGE_S seconds old, not re-building!"
    sleep 1
    PACKAGE_JCONFIGS=false
  fi
fi

if "$PACKAGE_JCONFIGS" ; then
  sudo du -sh \
    --exclude=target --exclude=build --exclude=mkarchiso --exclude=work --exclude=out --exclude=Index --exclude=Cache --exclude=jconfigs.tar.gz \
    "${jconfigs[@]}"

  echo 'Beginning archive...'
  sleep 1

  sudo tar -czvf archlive/airootfs/tools/jconfigs.tar.gz \
    --exclude=target --exclude=build --exclude=mkarchiso --exclude=work --exclude=out --exclude=Index --exclude=Cache --exclude=jconfigs.tar.gz \
    "${jconfigs[@]}"
fi

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



# Now build the iso

cd archlive

# sudo mkarchiso \
#   -A 'AzureOS' \
#   -L 'AzureOS' \
#   -P 'jeffrey mcateer <jeffrey.p.mcateer@gmail.com>' \
#   -C pacman.conf \
#   -p yay \
#   -v $(pwd)

sudo pacman-db-upgrade $(pwd)/work/x86_64/airootfs/var/lib/pacman || true

# Ensure getty is enabled (may fail if /work/ does not exist, but good example for later)
systemctl --root=$(pwd)/work/x86_64/airootfs/ enable getty@ || true


sudo mkarchiso \
  -A 'AzureOS' \
  -L 'AzureOS' \
  -P 'jeffrey mcateer <jeffrey.p.mcateer@gmail.com>' \
  -C pacman.conf \
  -p linux \
  -v $(pwd)


ISO_IMG=$(find $(pwd) -name '*.iso' 2>/dev/null | head -n 1 | tr -d '\n')
echo "DONE! Built $ISO_IMG"

cd ..

if ! [ -e test.sh ] ; then
  cd ..
fi

./test.sh

