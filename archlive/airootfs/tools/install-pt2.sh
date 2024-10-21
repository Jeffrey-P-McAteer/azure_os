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
if ! [ -e /etc/pacman.d/gnupg/gpg.conf ] || ! grep -q "hkp://keyserver.ubuntu.com" </etc/pacman.d/gnupg/gpg.conf ; then
  echo 'keyserver hkp://keyserver.ubuntu.com' >> /etc/pacman.d/gnupg/gpg.conf
fi
mkdir -p /root/.gnupg/
if ! [ -e /root/.gnupg/gpg.conf ] || ! grep -q "hkp://keyserver.ubuntu.com" </root/.gnupg/gpg.conf ; then
  echo 'keyserver hkp://keyserver.ubuntu.com' >> /root/.gnupg/gpg.conf
fi

cat <<EOF > /etc/pacman.d/mirrorlist
##
## Arch Linux repository mirrorlist
## Filtered by mirror score from mirror status page
## Generated on 2023-05-26
##

## United States
Server = https://mirror.wdc1.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://mirrors.rit.edu/archlinux/\$repo/os/\$arch
Server = https://codingflyboy.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://wcbmedia.io:8000/\$repo/os/\$arch
Server = http://mirrors.advancedhosters.com/archlinux/\$repo/os/\$arch
Server = https://coresite.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.clarkson.edu/archlinux/\$repo/os/\$arch
Server = http://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = https://mirror.theash.xyz/arch/\$repo/os/\$arch
Server = http://mirrors.mit.edu/archlinux/\$repo/os/\$arch
Server = http://ftp.osuosl.org/pub/archlinux/\$repo/os/\$arch
Server = https://opencolo.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://nnenix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.rit.edu/archlinux/\$repo/os/\$arch
Server = http://mnvoip.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = http://coresite.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://archive-us-nj.gaab-networks.de/arch/\$repo/os/\$arch
Server = https://mirror.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.arizona.edu/archlinux/\$repo/os/\$arch
Server = http://volico.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://opencolo.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.mia11.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = https://archive-us-ny.gaab-networks.de/arch/\$repo/os/\$arch
Server = http://mirror.sfo12.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://repo.ialab.dsu.edu/archlinux/\$repo/os/\$arch
Server = http://mirrors.cat.pdx.edu/archlinux/\$repo/os/\$arch
Server = http://uvermont.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror2.sandyriver.net/pub/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = http://mirrors.acm.wpi.edu/archlinux/\$repo/os/\$arch
Server = http://mirrors.vectair.net/archlinux/\$repo/os/\$arch
Server = https://mirror.sfo12.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://plug-mirror.rcac.purdue.edu/archlinux/\$repo/os/\$arch
Server = https://archive-us-nj.gaab-networks.de/arch/\$repo/os/\$arch
Server = https://mirrors.vectair.net/archlinux/\$repo/os/\$arch
Server = https://mirror.phx1.us.spryservers.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.lug.mtu.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.pit.teraswitch.com/archlinux/\$repo/os/\$arch
Server = https://iad.mirrors.misaka.one/archlinux/\$repo/os/\$arch
Server = http://mirror.cs.vt.edu/pub/ArchLinux/\$repo/os/\$arch
Server = https://mirror.arizona.edu/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.ivo.st/\$repo/os/\$arch
Server = https://mirrors.radwebhosting.com/archlinux/\$repo/os/\$arch
Server = https://zxcvfdsa.com/arch/\$repo/os/\$arch
Server = https://archive-us-lv.gaab-networks.de/arch/\$repo/os/\$arch
Server = https://mirror.adectra.com/archlinux/\$repo/os/\$arch
Server = http://irltoolkit.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://southfront.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.stephanie.is/archlinux/\$repo/os/\$arch
Server = https://ohioix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://uvermont.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirrors.rutgers.edu/archlinux/\$repo/os/\$arch
Server = https://nocix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.metrocast.net/archlinux/\$repo/os/\$arch
Server = https://mirror.dal10.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://mirror.umd.edu/archlinux/\$repo/os/\$arch
Server = http://distro.ibiblio.org/archlinux/\$repo/os/\$arch
Server = https://mnvoip.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.wdc1.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://mirror.clarkson.edu/archlinux/\$repo/os/\$arch
Server = https://iad.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirror.cs.pitt.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.umd.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.phx1.us.spryservers.net/archlinux/\$repo/os/\$arch
Server = https://mirror.mia11.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = https://nnenix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://irltoolkit.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.ette.biz/archlinux/\$repo/os/\$arch
Server = https://volico.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch
Server = http://arch.mirror.constant.com/\$repo/os/\$arch
Server = http://iad.mirrors.misaka.one/archlinux/\$repo/os/\$arch
Server = http://mirror.dal10.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://ziply.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.siena.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirror.hackingand.coffee/arch/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirror.hackingand.coffee/arch/\$repo/os/\$arch
Server = http://arlm.tyzoid.com/\$repo/os/\$arch
Server = https://ord.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirror.fcix.net/archlinux/\$repo/os/\$arch
Server = http://southfront.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.math.princeton.edu/pub/archlinux/\$repo/os/\$arch
Server = http://mirror.stephanie.is/archlinux/\$repo/os/\$arch
Server = https://mirrors.bloomu.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.fossable.org/archlinux/\$repo/os/\$arch
Server = https://arlm.tyzoid.com/\$repo/os/\$arch
Server = http://mirror.pit.teraswitch.com/archlinux/\$repo/os/\$arch
Server = http://mirror.adectra.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.xmission.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.radwebhosting.com/archlinux/\$repo/os/\$arch
Server = https://mirrors.xtom.com/archlinux/\$repo/os/\$arch
Server = https://ziply.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://forksystems.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirror.vtti.vt.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.gigenet.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = http://archmirror1.octyl.net/\$repo/os/\$arch
Server = https://mirror.tmmworkshop.com/archlinux/\$repo/os/\$arch
Server = https://dfw.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://codingflyboy.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://archive-us-lv.gaab-networks.de/arch/\$repo/os/\$arch
Server = https://plug-mirror.rcac.purdue.edu/archlinux/\$repo/os/\$arch
Server = https://repo.ialab.dsu.edu/archlinux/\$repo/os/\$arch
Server = http://mirrors.lug.mtu.edu/archlinux/\$repo/os/\$arch
Server = http://ohioix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://mirrors.bloomu.edu/archlinux/\$repo/os/\$arch
Server = http://nocix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = http://archive-us-ny.gaab-networks.de/arch/\$repo/os/\$arch
Server = http://iad.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://ridgewireless.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://archmirror1.octyl.net/\$repo/os/\$arch
Server = http://www.gtlib.gatech.edu/pub/archlinux/\$repo/os/\$arch
Server = http://mirrors.xtom.com/archlinux/\$repo/os/\$arch
Server = http://repo.miserver.it.umich.edu/archlinux/\$repo/os/\$arch
Server = http://ord.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://dfw.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://ridgewireless.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://america.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://ftp.osuosl.org/pub/archlinux/\$repo/os/\$arch
Server = http://mirror.ette.biz/archlinux/\$repo/os/\$arch
Server = http://forksystems.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://m.lqy.me/arch/\$repo/os/\$arch

EOF

# yn=''
# read -t 45 -p 'Update pacman keys? ' yn
# if grep -qi y <<<"$yn" ; then
#   pacman --noconfirm -Syy || true
#   pacman --noconfirm -Sy archlinux-keyring || true
#   yes | pacman-key --init || true
#   yes | pacman-key --populate archlinux || true
#   yes | pacman-key --refresh-keys || true
# fi


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
  -m jeffrey || true

echo "Type new password for user 'jeffrey':"
passwd jeffrey || true

if ! [ -e /etc/sudoers.d/jeffrey ] ; then
  cat <<EOJC > /etc/sudoers.d/jeffrey
jeffrey ALL=(ALL) ALL
Defaults:jeffrey timestamp_timeout=9000
Defaults:jeffrey !tty_tickets

jeffrey ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/bin/cpupower, /usr/bin/rtcwake
EOJC

fi

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
pacman -S --noconfirm base-devel git

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
sleep 1.5

jeff_packages=(
  # Kernel stuff
  linux-headers # for DKMS drivers
  intel-ucode
  intel-undervolt
  i915-firmware
  util-linux

  ## terminals
  zsh oh-my-zsh-git

  ## cli utilities
  tree
  helix
  youtube-dl exiftool jq socat xdg-user-dirs unzip
  python python-pip
  htop
  tungsten
  powerline powerline-fonts
  powerline-console-fonts
  curl wget
  lshw
  net-tools
  nmap
  cpupower
  imagemagick

  ## X11 DE
  xorg xorg-server xorg-startx-systemd xorg-xrandr mesa mesa-utils
  i3 lxappearance arc-gtk-theme arc-icon-theme breeze-hacked-cursor-theme
  ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git
  noto-fonts noto-fonts-cjk terminus-font-otb
  adobe-source-han-sans-cn-fonts adobe-source-han-sans-tw-fonts adobe-source-han-serif-cn-fonts adobe-source-han-serif-tw-fonts
  opendesktop-fonts
  adobe-source-han-sans-jp-fonts adobe-source-han-serif-jp-fonts

  ## Wayland DE
  sway swaybg swayidle swaylock waybar rofi
  ddcutil
  slurp grim slop
  adwaita-dark
  wl-clipboard
  swww
  wl-mirror

  # Work Utils
  libcacard

  ## Audio tools
  pipewire pipewire-audio pipewire-alsa pipewire-pulse
  wireplumber
  helvum
  bluez bluez-utils

  ## AV tools
  shotcut

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
  cups system-config-printer
  transmission-cli transmission-gtk
  wf-recorder

  ## Extra sw dev tools
  mold-git
  gdb
  vmtouch

  # Language support
  dotnet-sdk

  ## Math/Physics/Science tools
  plots

  ## Background servers to support other devices
  radicale
  tailscale
  cifs-utils

  ## Extra hardware utilities (smartcard stuff)
  ccid opensc pcsc-tools

  ## File / protocol supports
  libimobiledevice ifuse libplist libusbmuxd libheif
  curlftpfs
  udisks2 

  ## Common project dependencies
  archiso

  # GPU nonsense
  bolt
  vulkan-intel xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati
  vulkan-radeon mesa mesa-vdpau
  displaylink xf86-video-fbdev
  libva-mesa-driver
  opencl-amd vulkan-amdgpu-pro vulkan-tools
  nvidia cuda
  intel-media-driver intel-compute-runtime level-zero-loader

  ## Unsorted
  qemu libguestfs edk2-ovmf virt-viewer
  qemu-ui-gtk qemu-audio-pa
  qemu-system-aarch64 qemu-user-static qemu-user-static-binfmt

  rsync
  freerdp freerdp2
  smartmontools inotify-tools
  fwupd
  dunst
  iw
  wireless_tools


  # Super unsorted

  #acpilight
  #xprintidle
  # weston
  # mingw-w64-gcc arm-none-eabi-gcc

  #lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups dunst
  # Spellcheckers
  #hunspell-en_US mythes-en hyphen-en hyphen libmythes
  #aspell aspell-en
  # Multilang
  # fcitx fcitx-configtool fcitx-libpinyin fcitx-kkc
  # dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics xf86-input-joystick wpa_supplicant
  #mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl curl wget streamlink
  #remmina  libvncserver
  #qemu libguestfs edk2-ovmf virt-viewer unclutter xautolock rsync rclone
  #strace nmap intel-ucode tunsafe net-tools
  # alsa-utils pulseaudio pulseaudio-alsa
  #jdk-openjdk jd-gui-bin gradle pavucontrol pa-applet-git python python-pip xpra discount evolution
  #lftp netkit-telnet-ssl cpupower samba
  # gmni-git ledger
  # gnuplot
  # HW info dumpers
  #lshw
  # USB-C graphics dock stuff
  # vulkan-intel xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati bolt
  # vulkan-radeon mesa-vdpau
  #iw texlive-most meson ninja valgrind
  #intel-undervolt fping usbutils opencl-headers
  #displaylink xf86-video-fbdev
  # Movies
  # totem grilo-plugins dleyna-server
  # math tools
  # octave
  # Phone stuff
  #bluez bluez-utils pulseaudio-bluetooth
  #libnl owlink-git
  # DVD authoring libs
  #cdrtools libburn brasero devede
  # Print utils
  #system-config-printer
  # GPU nonsense
  #cuda md2pdf
  # Engineering; Wolfram Alpha cli client
  #intel-undervolt
)

for i in "${!jeff_packages[@]}"; do
  echo "Installing ${jeff_packages[$i]} ($i of ${#jeff_packages[@]})"
  sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    "${jeff_packages[$i]}" || true
done


systemctl enable cups.socket || true
# Must happen as jeffrey user!
sudo -u jeffrey systemctl --user enable wireplumber || true

systemctl enable tailscaled.service || true

systemctl enable bluetooth || true


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

systemctl enable pcscd.socket || true


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


systemctl enable radicale || true
systemctl enable iwd || true
systemctl enable intel-undervolt || true


# Add linux-ck boot entry
ROOT_PARTUUID=$(blkid | grep -i 'AzureOS-Root' | sed 's/.*PARTUUID="//g' | sed 's/".*//g' | tr -d '\n')
echo "ROOT_PARTUUID=$ROOT_PARTUUID"

cat <<EOF >/boot/loader/entries/azureos.conf
title Azure OS
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$ROOT_PARTUUID rootfstype=btrfs add_efi_memmap mitigations=off pti=off intel_pstate=passive

EOF

cat <<EOF >/boot/loader/loader.conf
#console-mode keep
console-mode max
timeout 2
default azureos.conf
EOF

# install rust in jeff's account
sudo -u jeffrey sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" || true

# Install zig
yay -S zig

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
systemctl enable eventmgr || true

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


