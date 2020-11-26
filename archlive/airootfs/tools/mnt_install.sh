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
    sublime-text-3 oh-my-zsh-git tree 

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    xorg xorg-server xorg-startx-systemd xorg-xrandr mesa
sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    i3

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    mingw-w64-gcc

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    rxvt-unicode ttf-scientifica adobe-source-code-pro-fonts ttf-nerd-fonts-hack-complete-git

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    breeze-hacked-cursor-theme-git lxappearance xorg-xcursorgen xorg-xhost xdotool nitrogen cups

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    dmenu maim freerdp barrier spice-gtk arandr xf86-input-synaptics

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    mpv feh llpp ripgrep transmission-cli transmission-gtk brightnessctl curl wget

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    radicale

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    firefox libreoffice chromium

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    strace

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    jdk-openjdk jd-gui-bin pavucontrol python python-pip xpra discount evolution

echo 'WARNING: installing linux-ck'

sudo -u jeffrey yay -S \
    --noconfirm --answerdiff=None \
    intel-ucode linux-ck || true # Don't fail on this if we don't get it

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
default azureos.conf
EOF

# Add an example wifi network
cat <<EOF >/etc/systemd/network/24-home-wifi-network.network
[Match]
Name=wl*
SSID=MacHome 5ghz
# BSSID=aa:bb:cc:dd:ee:ff

[Network]
DHCP=true

EOF

# install rust in jeff's account
sudo -u jeffrey sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

# Extract old files, overwriting any which exist.
tar -C / -zxvf /tools/jconfigs.tar.gz

# Sync changes
sync

cat <<EOF

DONE!

$0 has finished setting up Jeff's system packages and personal configs.
Exit the chroot environment with 'exit' then shutdown and reboot
into the new OS!

EOF
