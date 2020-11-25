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
  read -s -p "Device to install partitions to: " INSTALL_DEVICE
  if ! [ -e "$INSTALL_DEVICE" ] && [ -e "/dev/$INSTALL_DEVICE" ] ; then
    INSTALL_DEVICE="/dev/$INSTALL_DEVICE"
  fi
done

echo "INSTALL_DEVICE=$INSTALL_DEVICE"

timedatectl set-ntp true

read -p 'About to remove partition table, continue?' yn
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
  1 # partition number 1
    # default - start at beginning of disk 
  +2G # 2 GB swap partition
  t # set a partition's type
  2 # select second partition
  82 # id for linux-swap
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF




