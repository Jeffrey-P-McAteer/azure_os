#!/bin/sh

set -e

crun() {
  if ! [ -e '.crun' ] ; then
    mkdir '.crun'
  fi
  RAN_FILE=".crun/${1}"
  if ! [ -e RAN_FILE ] ; then
    ${1} && touch $RAN_FILE
  fi
}

install_deps() {
  sudo pacman -S \
    archiso
}

crun install_deps

# archlive is checked in to source control, so this only runs if you've thrown it out.
if ! [ -e archlive ] ; then
  cp -r /usr/share/archiso/configs/profile/baseline archlive
fi

cd archlive
./build.sh







