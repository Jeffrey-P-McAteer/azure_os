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
hostname 'azure-angel'

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

pacman-key --init
pacman-key --populate archlinux
pacman-key --refresh-keys

pacman -Syy

# Create jeffrey user
useradd \
  --home /j/ \
  --groups wheel,lp \
  -m jeffrey

echo "Type new password for user 'jeffrey':"
passwd jeffrey

# Ensure wheel group has sudo rights
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheelsetup


# use jeffrey user to install yay

(
  cd /opt
  git clone https://aur.archlinux.org/yay-git.git
  chown -R jeffrey:jeffrey yay-git
  cd /opt/yay-git
  sudo -u jeffrey -c 'makepkg -si'
)


# use yay to install neat sw

echo 'WARNING: lots of apps going in'

sudo -u jeffrey -c 'yay -S sublime-text-3 oh-my-zsh-git tree '

sudo -u jeffrey -c 'yay -S xorg xorg-server xorg-startx-systemd xorg-xrandr mesa'

# sudo -u jeffrey -c 'yay -S mingw-w64-gcc-base mingw-w64-gcc'

# sudo -u jeffrey -c 'yay -S urxvt ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git'

# sudo -u jeffrey -c 'yay -S breeze-hacked-cursor-theme-git lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups'

# sudo -u jeffrey -c 'yay -S dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics'

# sudo -u jeffrey -c 'yay -S mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl'

# sudo -u jeffrey -c 'yay -S libreoffice chromium'

# sudo -u jeffrey -c 'yay -S startx strace'

# sudo -u jeffrey -c 'yay -S jdk-openjdk jd-gui-bin pavucontrol python python-pip xpra discount evolution'

echo 'WARNING: installing linux-ck'

sudo -u jeffrey -c 'yay -S intel-ucode linux-ck' || true # Don't fail on this if we don't get it



# Add autologin for jeffrey user



# Sync changes
sync
