#!/bin/sh -e
#
# - Running Arch Linux as host is required to run this script
# - modify this script to suit your need for your custom iso, mostly at the pkg part
# - this script is not required, you can do however you want to prepare the rootfs

if [ "$(id -u)" != 0 ]; then
	echo "this script need to run as root."
	exit 1
fi

cd $(dirname $0)

ROOTFS=$PWD/rootfs-archlinux

echo "[options]
Architecture = auto

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[customrepo]
SigLevel = Optional TrustAll
Server = file:///home/emmett/aur/customrepo" > work/pacman.conf

mkdir -p $ROOTFS

pacstrap -C work/pacman.conf -KMc $ROOTFS base linux linux-firmware grub \
	squashfs-tools xorg xorg-xinit openbox xterm pcmanfm firefox geany xarchiver \
	tint2 dfc dunst feh gmrun lxappearance-obconf neofetch picom gparted mtools \
	sudo ttf-liberation lxdm-gtk3 ntfs-3g polkit-gnome xdg-user-dirs xdg-utils vim \
	networkmanager gvfs leafpad volumeicon network-manager-applet
	
# this use my custom repo for aur packages
# setup your own custom repo if you wanna add packages from aur
pacstrap -C work/pacman.conf -KMc $ROOTFS arc-gtk-theme openbox-theme-arcbox clipit obmenu-generator paper-icon-theme

# uncomment all mirrors
sed -i 's/^#Server/Server/' $ROOTFS/etc/pacman.d/mirrorlist
rm -f work/pacman.conf
rm -f rootfs-archlinux/var/lib/pacman/sync/customrepo.db
