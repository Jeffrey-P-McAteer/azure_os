#!/bin/bash

# Jeff's OS install script.
# This assumes a fairly vanilla Arch .iso / live system
# and targets the internal SSD of a laptop that boots EFI systems.

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

locale_and_mirror_tasks() {
  timedatectl set-ntp true
  # Setup time + locale
  ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
  hwclock --systohc

  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
  echo 'LANG="en_US.UTF-8"' > /etc/locale.conf

  # Optimize mirrors (they will be copied to the new system)
  echo 'Optimizing /etc/pacman.d/mirrorlist (running in the bg, should take 30 seconds)'
  #reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist &
  sh -c 'sleep 1' # TODO move back to reflector once mirrors are more decently maintained

}

locale_and_mirror_tasks &
locale_and_mirror_subsh_pid=$!
echo "Forked process $locale_and_mirror_subsh_pid"
sleep 2 # for timedatectl and hwclock, that's a tad more important.

# This script may be called like "/tools/install.sh sda" to automatically use /dev/sda for partitions
INSTALL_DEVICE="$1"
if ! [ -z "$INSTALL_DEVICE" ] && ! [ -e "$INSTALL_DEVICE" ] && [ -e "/dev/$INSTALL_DEVICE" ] ; then
  INSTALL_DEVICE="/dev/$INSTALL_DEVICE"
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

read -p 'About to remove partition table, continue? ' yn
if ! grep -q y <<<"$yn" ; then
  echo 'Exiting...'
  exit 1
fi

# for second runs this undoes what we did before
umount "$INSTALL_DEVICE"* || true
swapoff "$INSTALL_DEVICE"* || true

set +e
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${INSTALL_DEVICE}
  g # replace the in memory partition table with an empty GPT table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +4G # 4 GB boot partition
  n # new partition
  2 # partition number 2
    # default - start at beginning of disk 
  +2G # 2 GB swap partition
  t # set a partition's type
  1 # select first partition
  1 # GPT id for EFI type
  t # set a partition's type
  2 # select second partition
  19 # GPT id for linux-swap (82 is for DOS disks)
  n # new partition
  3 # partion number 3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF
set -e

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

echo 'Creating filesystems on partitions...'

mkfs.fat \
  -F32 \
  $BOOT_PARTITION

mkswap $SWAP_PARTITION

mkfs.btrfs \
  --label 'AzureOS-Root' \
  --force \
  $ROOT_PARTITION


echo "Waiting on locale_and_mirror_subsh_pid ($locale_and_mirror_subsh_pid)..."
wait $locale_and_mirror_subsh_pid

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

# Right now GPG servers are being dumb.
# Ideally we'd use pool.sks-keyservers.net but I don't know where pacman's gpg config file is.
sed -i 's/SigLevel = .*/SigLevel = Never/g' /etc/pacman.conf

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
pacman-key --init || true
pacman-key --populate archlinux || true
pacman-key --refresh-keys || true

pacstrap /mnt \
  base \
  linux \
  linux-firmware \
  sudo \
  git \
  openssh \
  vim \
  dosfstools \
  btrfs-progs \
  iwd \
  zsh


echo 'Generating fstab'
genfstab -U /mnt >> /mnt/etc/fstab


echo 'Copying /tools/ over...'

mkdir -p /mnt/tools/
cp -r /tools/. /mnt/tools/

echo 'azure-angel' > /mnt/etc/hostname
cat <<EOF >/mnt/etc/hosts
#<ip-address> <hostname.domain.org> <hostname>
127.0.0.1   localhost.localdomain localhost azure-angel
::1         localhost.localdomain localhost azure-angel

EOF

if [ -e /mnt/etc/resolv.conf ] ; then
  rm /mnt/etc/resolv.conf
fi
#ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
cat <<EOF >/mnt/etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad
EOF

echo 'Running arch-chroot, please run /tools/mnt_install.sh'

arch-chroot /mnt

echo 'Install complete!'

# Sync changes
sync


