
# Azure OS

An Arch-derived operating system for Jeffrey's laptop.

Quickstart: 

```bash
sudo rm -rf archlive/out archlive/work ; ./build.sh
sudo dd if=archlive/out/azure-os-baseline-2020.11.26-x86_64.iso of=/dev/sda status=progress oflag=sync bs=4M
```

# Why?

There are hundreds of people who have invested in forking
arch or building their own install scripts for their business domain
or personal use cases.

I have found that my systems get cluttered pretty quickly
and other OSes (manjaro) take too much control away to be worth
their nice features and quick deployments.

This project exists for one person (me!) to go from new hardware -> uefi+linx+systemd+all-my-config
in about 15 minutes. I keep bootable backups that are to this day used to
fire up a 3 year old copy of firefox when I need a password I forgot about.

If you're interested in the same I can link you to the official docs:

 - https://wiki.archlinux.org/index.php/Archiso

 - https://wiki.archlinux.org/index.php/installation_guide
 - https://wiki.archlinux.org/index.php/General_recommendations

as well as some less-than-official people who are doing similar things:

 - https://www.google.com/search?q=arch+linux+install+script+-site%3Aarchlinux.org


# Notes

```
pacman -Q | wc -l # 827 packages as of 2020-12-05
pacman -Q | wc -l # 855 packages as of 2020-12-07

```


