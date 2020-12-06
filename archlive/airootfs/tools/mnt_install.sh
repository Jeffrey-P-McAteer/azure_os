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

timedatectl set-ntp true

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


pacman --noconfirm -Syy || true
pacman --noconfirm -Sy archlinux-keyring || true
yes | pacman-key --init || true
yes | pacman-key --populate archlinux || true
yes | pacman-key --refresh-keys || true


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

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    sublime-text-3 oh-my-zsh-git tree archiso

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    xorg xorg-server xorg-startx-systemd xorg-xrandr mesa acpilight

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    i3 lxappearance arc-gtk-theme arc-icon-theme breeze-hacked-cursor-theme

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    mingw-w64-gcc

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    rxvt-unicode ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git noto-fonts terminus-font-otb

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups dunst

systemctl enable cups.socket || true


sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics wpa_supplicant

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl curl wget streamlink

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    radicale qemu libguestfs edk2-ovmf virt-viewer unclutter xautolock rsync rclone

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    firefox libreoffice chromium blender gimp xcftools inkscape

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    strace nmap intel-ucode tunsafe net-tools alsa-utils pulseaudio pulseaudio-alsa

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    jdk-openjdk jd-gui-bin gradle pavucontrol pa-applet-git python python-pip xpra discount evolution

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    lftp netkit-telnet-ssl cpupower gdb htop

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    youtube-dl exiftool jq socat whois xdg-user-dirs unzip || true

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    gmni-git aspell aspell-en || true

# USB-C graphics dock stuff
sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati bolt || true

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    iw || true






# Work stuff
sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    ccid opensc pcsc-tools



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

cat <<EOF >>/etc/pulse/default.pa
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

EOF

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


sudo -u jeffrey python3 -m pip install --user pyftpdlib
python3 -m pip install --user pyftpdlib

sudo -u jeffrey python3 -m pip install --user jetforce
python3 -m pip install --user jetforce

# More python libs for other projects
#sudo -u jeffrey python3 -m pip install --user tensorflow
sudo -u jeffrey python3 -m pip install --user flameprof

# For blog build.py
sudo -u jeffrey python3 -m pip install --user htmlmin

systemctl enable radicale
systemctl enable iwd


echo 'WARNING: installing linux-ck'

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    linux-headers || true # we use these for DKMS modules, so....


sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    linux-ck linux-ck-headers || true # Don't fail on this if we don't get it


# Add linux-ck boot entry
ROOT_PARTUUID=$(blkid | grep -i 'AzureOS-Root' | sed 's/.*PARTUUID="//g' | sed 's/".*//g' | tr -d '\n')
echo "ROOT_PARTUUID=$ROOT_PARTUUID"
cat <<EOF >/boot/loader/entries/azureosck.conf
title Azure OS CK
linux /vmlinuz-linux-ck
initrd /intel-ucode.img
initrd /initramfs-linux-ck.img
options root=PARTUUID=$ROOT_PARTUUID rootfstype=btrfs add_efi_memmap mitigations=off loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off tsx=on tsx_async_abort=off intel_pstate=passive pti=off

EOF

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
default azureosck.conf
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

  '/j/www' # public data served over ftp, http, https, friggin' telnet, and a samba server. This is what srvmgr.py performs.

  '/j/.ssh/controls' # used for ssh sockets in master-slave mode
)
for jd in "${jdirs[@]}" ; do
  echo "Creating directory $jd"
  mkdir -p "$jd"
done

jfiles=(
  '/j/tasks.toml' # [[task]].name="do thing X"/.period="24h" ; polled by /j/bins/eventmgr.py every 60s -> 300s? keep it opinionated.

)
for jf in "${jfiles[@]}" ; do
  echo "Touching file $jf"
  touch "$jf"
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


