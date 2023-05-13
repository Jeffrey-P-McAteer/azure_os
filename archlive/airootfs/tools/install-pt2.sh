#!/bin/bash

# Part 2 of the install:
# this file is copied to /mnt/tools/
# and executed inside the newly installed system
# using arch-chroot

set -e

# Setup time + locale
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG="en_US.UTF-8"' > /etc/locale.conf

# Cannot run in chroot; TODO install-pt3.sh?
timedatectl set-ntp true || true

echo 'azure-angel' > /etc/hostname
# hostname 'azure-angel'

# Just in case pacstrap didn't already do this
mkinitcpio -P

# Bootloader
bootctl --esp-path=/boot/ install

# Package + signing stuff
mkdir -p /etc/pacman.d/gnupg
echo 'keyserver hkp://pool.key-servers.net' >> /etc/pacman.d/gnupg/gpg.conf
mkdir -p /root/.gnupg/
echo 'keyserver hkp://pool.key-servers.net' >> /root/.gnupg/gpg.conf

cat <<EOF > /etc/pacman.d/mirrorlist
# USA
Server = http://mirrors.acm.wpi.edu/archlinux/\$repo/os/\$arch

## Worldwide
Server = http://mirrors.evowise.com/archlinux/\$repo/os/\$arch
Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch

EOF


read -p 'Update pacman keys? ' yn
if grep -qi y <<<"$yn" ; then
  pacman --noconfirm -Syy || true
  pacman --noconfirm -Sy archlinux-keyring || true
  yes | pacman-key --init || true
  yes | pacman-key --populate archlinux || true
  yes | pacman-key --refresh-keys || true
fi


# Enable some systemd tasks
ln -nsf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/
ln -nsf /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/

# We do the symlinking before moving into the new OS
# if [ -e /etc/resolv.conf ] ; then
#   rm /etc/resolv.conf
# fi
# ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

pacman -S --noconfirm systemd-resolvconf # replaces /usr/bin/resolvconf with systemd so it can manage 3rdparty requests
if ! grep 127 /etc/resolv.conf ; then
  cat <<EOF >>/etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad

EOF
fi

# Create jeffrey user
useradd \
  --home /j/ \
  --shell /bin/zsh \
  --groups wheel,lp \
  -m jeffrey

echo "Type new password for user 'jeffrey':"
passwd jeffrey

# cat <<EOJC > /etc/sudoers.d/jeffrey
# jeffrey ALL=(ALL) ALL
# Defaults:jeffrey timestamp_timeout=900
# Defaults:jeffrey !tty_tickets

# jeffrey ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/bin/cpupower, /usr/bin/rtcwake

# EOJC
# This is now copied in the tarball as /etc/sudoers.d/jeffrey


# Grant root rights to ALL (this is removed at the end)
echo 'root ALL = (ALL) NOPASSWD: ALL' > /etc/sudoers.d/installstuff


# Add autologin for jeffrey user
mkdir -p '/etc/systemd/system/getty@tty1.service.d'
cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin jeffrey --noclear %I \$TERM

EOF


# Install deps to makepkg
pacman -S --noconfirm base-devel

# use jeffrey user to install yay

(
  cd /opt
  git clone https://aur.archlinux.org/yay-git.git
  chown -R jeffrey:jeffrey yay-git
  cd /opt/yay-git
  sudo -u jeffrey makepkg -si
)


# use yay to install neat sw

echo 'WARNING: lots of apps going in'
sleep 0.5

jeff_packages=(
  # Kernel stuff
  linux-headers # for DKMS drivers

  ## terminals
  zsh oh-my-zsh-git

  ## cli utilities
  tree
  helix
  youtube-dl exiftool jq socat xdg-user-dirs unzip
  python python-pip
  htop
  tungsten

  ## X11 DE
  xorg xorg-server xorg-startx-systemd xorg-xrandr mesa
  i3 lxappearance arc-gtk-theme arc-icon-theme breeze-hacked-cursor-theme
  ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git
  noto-fonts noto-fonts-cjk terminus-font-otb
  adobe-source-han-sans-cn-fonts adobe-source-han-sans-tw-fonts adobe-source-han-serif-cn-fonts adobe-source-han-serif-tw-fonts
  opendesktop-fonts
  adobe-source-han-sans-jp-fonts adobe-source-han-serif-jp-fonts

  ## Wayland DE
  sway

  ## Audio tools
  pipewire pipewire-audio pipewire-alsa pipewire-pulse
  wireplumber

  ## GUI software dev tools
  sublime-text-3
  alacritty

  ## GUI normal tools
  mpv
  feh # TODO find wayland equivelant
  firefox
  libreoffice
  #chromium
  blender
  gimp
  xcftools
  inkscape

  ## Extra sw dev tools
  mold-git
  gdb
  vmtouch

  ## Background servers to support other devices
  radicale
  
  ## Extra hardware utilities (smartcard stuff)
  ccid opensc pcsc-tools

  ## File / protocol supports
  libimobiledevice ifuse libheif

  ## Common project dependencies
  archiso

  ## Unsorted


  acpilight
  xprintidle
  fwupd
  # weston
  # mingw-w64-gcc arm-none-eabi-gcc
  
  lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups dunst
  inotify-tools
  # Spellcheckers
  hunspell-en_US mythes-en hyphen-en hyphen libmythes
  aspell aspell-en
  # Multilang
  fcitx fcitx-configtool fcitx-libpinyin fcitx-kkc
  dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics xf86-input-joystick wpa_supplicant
  mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl curl wget streamlink
  remmina  libvncserver
  qemu libguestfs edk2-ovmf virt-viewer unclutter xautolock rsync rclone
  strace nmap intel-ucode tunsafe net-tools
  # alsa-utils pulseaudio pulseaudio-alsa
  #jdk-openjdk jd-gui-bin gradle pavucontrol pa-applet-git python python-pip xpra discount evolution
  lftp netkit-telnet-ssl cpupower samba
  # gmni-git ledger
  # gnuplot
  # HW info dumpers
  lshw
  # USB-C graphics dock stuff
  vulkan-intel xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati bolt
  vulkan-radeon mesa-vdpau
  iw texlive-most meson ninja valgrind
  intel-undervolt fping usbutils opencl-headers
  displaylink xf86-video-fbdev
  libva-mesa-driver
  opencl-amd vulkan-amdgpu-pro vulkan-tools
  ddcutil
  # Movies
  # totem grilo-plugins dleyna-server
  # math tools
  # octave
  # Phone stuff
  bluez bluez-utils pulseaudio-bluetooth
  libnl owlink-git
  # DVD authoring libs
  cdrtools libburn brasero devede
  # Print utils
  system-config-printer
  # GPU nonsense
  cuda md2pdf
  # Engineering; Wolfram Alpha cli client
  intel-undervolt
  intel-media-driver intel-compute-runtime level-zero-loader
  i915-firmware
  # Awesome environment mgr
  # guix-installer # guix
)

for i in "${!jeff_packages[@]}"; do
  echo "Installing ${jeff_packages[$i]} ($i of ${#jeff_packages[@]})"
  sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    "${jeff_packages[$i]}" || true
done


systemctl enable cups.socket || true


cat <<EOF >/etc/opensc.conf
app default {
  # debug = 3;
  # debug_file = opensc-debug.txt;
  framework pkcs15 {
    # use_file_caching = true;
  }
}
enable_pinpad = false

EOF

systemctl enable pcscd.socket

#cat <<EOF >>/etc/pulse/default.pa
#load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
#
#EOF

cat <<EOF >/etc/systemd/logind.conf
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See logind.conf(5) for details.

[Login]
#NAutoVTs=6
#ReserveVT=6
#KillUserProcesses=no
#KillOnlyUsers=
#KillExcludeUsers=root
#InhibitDelayMaxSec=5
#HandlePowerKey=poweroff
#HandleSuspendKey=suspend
#HandleHibernateKey=hibernate
#HandleLidSwitch=suspend
#HandleLidSwitchExternalPower=suspend
#HandleLidSwitchDocked=ignore
#PowerKeyIgnoreInhibited=no
#SuspendKeyIgnoreInhibited=no
#HibernateKeyIgnoreInhibited=no
#LidSwitchIgnoreInhibited=yes
#HoldoffTimeoutSec=30s
#IdleAction=ignore
#IdleActionSec=30min
#RuntimeDirectorySize=10%
#RuntimeDirectoryInodes=400k
#RemoveIPC=yes
#InhibitorsMax=8192
#SessionsMax=8192

HandleLidSwitch=ignore

EOF


jeff_pip_packages=(
  clikan
  htmlmin
  # TODO figure out what below supported
  #pyftpdlib
  #jetforce
  #flameprof
)

for i in "${!jeff_pip_packages[@]}"; do
  echo "Installing ${jeff_pip_packages[$i]} ($i of ${#jeff_pip_packages[@]})"
  sudo -u jeffrey python -m pip install --user \
    "${jeff_pip_packages[$i]}" || true
done


systemctl enable radicale
systemctl enable iwd
systemctl enable jabberd

systemctl enable intel-undervolt


# Add linux-ck boot entry
ROOT_PARTUUID=$(blkid | grep -i 'AzureOS-Root' | sed 's/.*PARTUUID="//g' | sed 's/".*//g' | tr -d '\n')
echo "ROOT_PARTUUID=$ROOT_PARTUUID"

cat <<EOF >/boot/loader/entries/azureos.conf
title Azure OS
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$ROOT_PARTUUID rootfstype=btrfs add_efi_memmap mitigations=off loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off tsx=on tsx_async_abort=off intel_pstate=passive pti=off

EOF

cat <<EOF >/boot/loader/loader.conf
#console-mode keep
console-mode max
timeout 2
default azureos.conf
EOF

# install rust in jeff's account
sudo -u jeffrey sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Config stuff
sudo -u jeffrey git config --global core.preloadIndex true

# Add jeff to useful groups
added_groups=(
  video
  audio
  disk
  avahi
  cups
  power
  radicale
  xpra
  uucp
  optical
  lp
  input
  # Copy-pasted in from prior install, TODO sort/organize
  root bin daemon sys tty mem ftp mail log smmsp proc http games lock uuidd dbus network floppy scanner power polkitd rtkit usbmux nvidia-persistenced wireshark transmission rabbitmq cups seat adbusers i2c qemu libvirt-qemu systemd-oom sgx brltty jabber tss gnupg-pkcs11-scd-proxy gnupg-pkcs11 dhcpcd libvirt _telnetd xpra radicale brlapi colord avahi git systemd-coredump systemd-timesync systemd-resolve systemd-network systemd-journal-remote rfkill systemd-journal users video uucp storage render optical lp kvm input disk audio utmp kmem wheel adm jeffrey dialout plugdev nobody
)
for g in "${added_groups[@]}" ; do
  echo "Adding jeffrey to $g"
  usermod -a -G $g jeffrey || true
done

####
##
## The below files OUGHT to be added to azure_os/build.sh in jconfigs.
## They are hardcoded here because they do not exist on the source OS
## but they are planned in the next OS.
## 
## TODO start versioning my personal OS?
##
####

# Default wifi network
cat <<EOF >/etc/systemd/network/24-default-wifi.network
[Match]
Name=wl*
# SSID=AP Name 5ghz
# BSSID=aa:bb:cc:dd:ee:ff

[Network]
#DHCP=true
DHCP=ipv4

EOF
# Default ethernet
cat <<EOF >/etc/systemd/network/24-default-ethernet.network
[Match]
Name=en*

[Network]
#DHCP=true
DHCP=ipv4

EOF

# .xinitrc for i3wm
sudo -u jeffrey sh -c "cat - > /j/.xinitrc" <<EOF

# i3 is responsible for all x11 app startups (/j/.config/i3/config),
# do not start x11 apps here besides i3.

# SO SAYETH THE PRIMARY USER OF THIS OS

xrdb ~/.Xresources

exec i3

EOF


# This is the authoritative list of directories I use to organize $HOME
jdirs=(
  '/j/bin'        # symlinks to bins/<project>/<build directory>/<actual binary>
  '/j/bins'       # directories of source/config/build tools which produce my bins
  '/j/downloads'  # fuck capital letters, I don't love my shift key that much.
  '/j/ident'      # was /j/i/, contains secrets and identities
  '/j/lists'      # holds anime.csv and music.csv, any other lists I keep track of (books.csv?) Most of these .csv files will have comments using '#' chars.
  '/j/music'      # contains music which is managed by /j/bins/music_fetch.py which reads /j/lists/music.csv
  '/j/photos'     # contains:
      # bb/<blackberry camera files, synced on USB conn>
      # hourly/<timestamped pics of webcam every hour, post-processed into other projects>
      # wallpaper/<category>; the only files we have will be in wallpaper/originals, categories contain symlinks
  '/j/proj' # projects
  '/j/docs' # documents
  '/j/infra'
  '/j/art'
  '/j/edu'

  '/j/www' # public data served over ftp, http, https, friggin' telnet, and a samba server. This is what srvmgr.py performs.

  '/j/.ssh/controls' # used for ssh sockets in master-slave mode
)
for jd in "${jdirs[@]}" ; do
  echo "Creating directory $jd"
  mkdir -p "$jd"
done


####
##
## END the hardcoded files section, we extract everything else below + exit.
##
####

# Extract old files, overwriting any which exist.
# These have passed the quality requirement 100%.
tar -C / -zxvf /tools/jconfigs.tar.gz

# Make sure jeff can access his own stuff
chown -R jeffrey:jeffrey /j/

# Enable some services we copied in
systemctl enable eventmgr
systemctl enable srvmgr

# Remove rights we granted root earlier; yeah it's stupid but we're being civilized here.
rm /etc/sudoers.d/installstuff || true

# Sync changes
sync

cat <<EOF

DONE!

$0 has finished setting up Jeff's system packages and personal configs.
Exit the chroot environment with 'exit' then shutdown and reboot
into the new OS!

EOF


