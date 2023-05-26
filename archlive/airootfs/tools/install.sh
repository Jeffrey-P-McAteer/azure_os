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
    echo "Run me as root"
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

locale_and_mirror_tasks 2>/dev/null >/dev/null &
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
  +2G # 2 GB boot partition
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

yn=''
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

yn=n
read -t 45 -p 'Update pacman keys? ' yn
if grep -qi y <<<"$yn" ; then

  pacman --noconfirm -Syy || true
  pacman --noconfirm -Sy archlinux-keyring || true
  pacman-key --init || true
  pacman-key --populate archlinux || true
  pacman-key --refresh-keys || true

fi

pacstrap /mnt \
  base \
  linux \
  linux-firmware \
  sudo \
  git \
  base-devel \
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

echo 'Running arch-chroot, please run /tools/install-pt2.sh'

arch-chroot /mnt

echo 'Install complete!'

# Sync changes
sync

