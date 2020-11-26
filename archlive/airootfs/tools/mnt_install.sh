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

echo 'azure-angel' > /etc/hostname
# hostname 'azure-angel'

# Just in case pacstrap didn't already do this
mkinitcpio -P

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


pacman -Syy || true
pacman -Sy archlinux-keyring || true
pacman-key --init || true
pacman-key --populate archlinux || true
pacman-key --refresh-keys || true


# Enable some systemd tasks
ln -nsf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/
ln -nsf /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/

# We do the symlinking before moving into the new OS
# if [ -e /etc/resolv.conf ] ; then
#   rm /etc/resolv.conf
# fi
# ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

pacman -S systemd-resolvconf # replaces /usr/bin/resolvconf with systemd so it can manage 3rdparty requests
if ! grep 127 /etc/resolv.conf ; then
  cat <<EOF >>/etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad

EOF
fi

# Create jeffrey user
useradd \
  --home /j/ \
  --groups wheel,lp \
  -m jeffrey

echo "Type new password for user 'jeffrey':"
passwd jeffrey

# Ensure wheel group has sudo rights
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheelsetup


# Add autologin for jeffrey user
mkdir -p '/etc/systemd/system/getty@tty1.service.d'
cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin jeffrey --noclear %I \$TERM

EOF


# Install deps to makepkg
pacman -S base-devel

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

sudo -u jeffrey yay -S sublime-text-3 oh-my-zsh-git tree 

sudo -u jeffrey yay -S xorg xorg-server xorg-startx-systemd xorg-xrandr mesa
sudo -u jeffrey yay -S i3

# sudo -u jeffrey yay -S mingw-w64-gcc-base mingw-w64-gcc

sudo -u jeffrey yay -S urxvt ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git

sudo -u jeffrey yay -S breeze-hacked-cursor-theme-git lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups

# sudo -u jeffrey yay -S dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics

# sudo -u jeffrey yay -S mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl

# sudo -u jeffrey yay -S radicale

# sudo -u jeffrey yay -S libreoffice chromium

# sudo -u jeffrey yay -S strace

# sudo -u jeffrey yay -S jdk-openjdk jd-gui-bin pavucontrol python python-pip xpra discount evolution

echo 'WARNING: installing linux-ck'

sudo -u jeffrey yay -S intel-ucode linux-ck || true # Don't fail on this if we don't get it


# Sync changes
sync
