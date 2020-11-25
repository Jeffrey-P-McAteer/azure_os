#!/bin/bash

# Jeff's OS install script.
# This assumes a fairly vanilla Arch .iso / live system
# and targets a laptop that boots EFI systems on an SSD.

# This script installs the OS, sets up the 'jeffrey' user
# with home directory '/j/' as well as some other directories.
# It copies some binaries over based on the `/j/` directory this was build with
# (mostly from /j/bins/)

# After the OS is setup this script uses arch-chroot to move into
# the new OS and install things like `yay`.

set -e

if (( $EUID != 0 )); then
    echo "Run it as root"
    exit 1
fi

while [ -z "$INSTALL_DEVICE" ] || ! [ -e "$INSTALL_DEVICE" ]
do
  lsblk
  read -p "Device to install partitions to: " INSTALL_DEVICE
  if ! [ -e "$INSTALL_DEVICE" ] && [ -e "/dev/$INSTALL_DEVICE" ] ; then
    INSTALL_DEVICE="/dev/$INSTALL_DEVICE"
  fi
done

cat <<EOF

INSTALL_DEVICE=$INSTALL_DEVICE

EOF

timedatectl set-ntp true

read -p 'About to remove partition table, continue? ' yn
if ! grep -q y <<<"$yn" ; then
  echo 'Exiting...'
  exit 1
fi

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${INSTALL_DEVICE}
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +4G # 4 GB boot partition
  n # new partition
  p # primary partition
  2 # partition number 2
    # default - start at beginning of disk 
  +2G # 2 GB swap partition
  t # set a partition's type
  2 # select second partition
  82 # id for linux-swap
  n # new partition
  p # primary partition
  3 # partion number 3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

echo "Done partitioning $INSTALL_DEVICE"

INSTALL_DEVICE_NAME=$(basename "$INSTALL_DEVICE")

# See https://unix.stackexchange.com/questions/226420/how-to-get-disk-name-that-contains-a-specific-partition
export LANG=en_US.UTF-8
# BOOT_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | head -n 2 | tail -n 1)
# SWAP_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | head -n 3 | tail -n 1)
# ROOT_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | tail -n 1)

BOOT_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 2 | tail -n 1)
SWAP_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 3 | tail -n 1)
ROOT_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 4 | tail -n 1)

cat <<EOF

BOOT_PARTITION=$BOOT_PARTITION
SWAP_PARTITION=$SWAP_PARTITION
ROOT_PARTITION=$ROOT_PARTITION

EOF

read -p 'Does this look right, continue? ' yn
if ! grep -q y <<<"$yn" ; then
  echo 'Exiting...'
  exit 1
fi

# Optimize mirrors (they will be copied to the new system)
echo 'Optimizing /etc/pacman.d/mirrorlist (running in the bg, should take 30 seconds)'
reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist &
reflector_pid=$!
echo "Forked process $reflector_pid"

echo 'Creating filesystems on partitions...'

mkfs.fat \
  -F32 \
  $BOOT_PARTITION

mkswap $SWAP_PARTITION

mkfs.btrfs \
  --label 'AzureOS-Root' \
  --force \
  $ROOT_PARTITION


echo "Waiting on reflector_pid ($reflector_pid)..."
wait $reflector_pid

if ! [ -e /mnt/ ] ; then
  mkdir /mnt/
fi

mount "$ROOT_PARTITION" /mnt/

mkdir -p /mnt/boot/

mount "$BOOT_PARTITION" /mnt/boot/

swapon "$SWAP_PARTITION" || true


# We now have the system mounted at /mnt/ and we are ready
# to copy packages + files in

echo 'Running pacstrap'

pacman-key --init
pacman -Sy

pacstrap /mnt \
  base \
  linux \
  linux-firmware \
  sudo \
  git \
  reflector \
  firefox \
  i3 \
  openssh \
  vim \
  dosfstools \
  btrfs-progs \
  iwd \
  zsh \


echo 'Generating fstab'
genfstab -U /mnt >> /mnt/etc/fstab


echo 'Copying /tools/ over...'

mkdir -p /mnt/tools/

cp -r /mnt/tools/. /mnt/tools/

echo 'Running arch-chroot and executing mnt_install.sh'

arch-chroot /mnt /tools/mnt_install.sh

echo 'Install complete! Spawning shell in new OS...'

arch-chroot /mnt

# Sync changes
sync


