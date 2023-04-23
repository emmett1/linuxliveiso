#!/bin/sh -e
#
# - Running Void Linux as host is required to run this script
# - modify this script to suit your need for your custom iso, mostly at the pkg part
# - this script is not required, you can do however you want to prepare the rootfs

if [ "$(id -u)" != 0 ]; then
	echo "this script need to run as root."
	exit 1
fi

xbps() {
	XBPS_ARCH=$ARCH xbps-install -r $ROOTFS -R $REPO -c $PKGDIR $@
}

xbpsi() {
	xbps -y $@
}

cd $(dirname $0)

# uncomment any to use it
#mirror=https://repo-fastly.voidlinux.org
#mirror=https://repo-fi.voidlinux.org
#mirror=https://repo-de.voidlinux.org
#mirror=https://mirrors.servercentral.com/voidlinux

DISTRONAME=${0#*-}           # remove 'mkrootfs-' from name
DISTRONAME=${DISTRONAME%.sh} # remove '.sh' from name

ROOTFS=$PWD/rootfs-$DISTRONAME
PKGDIR=/var/cache/xbps

case $DISTRONAME in
	*musl) musl="-musl";;
esac

ARCH=x86_64$musl
REPO=${mirror:-https://repo-default.voidlinux.org}/current/${musl#-}

mkdir -p $ROOTFS/var/db/xbps/keys
cp /var/db/xbps/keys/* $ROOTFS/var/db/xbps/keys/

mkdir -p $PKGDIR

# sync repo, and update
xbps -Suy

# base
xbpsi base-system linux-firmware

# must have
xbpsi grub grub-x86_64-efi squashfs-tools xz git xorriso

# extra
xbpsi xorg openbox xterm pcmanfm firefox geany xarchiver elogind tint2 arc-theme \
	dfc dunst feh gmrun liberation-fonts-ttf lxappearance-obconf neofetch \
	obmenu-generator paper-icon-theme picom slim slim-void-theme gparted mtools \
	ntfs-3g	polkit-gnome xdg-user-dirs xdg-utils vim NetworkManager gvfs leafpad \
	volumeicon network-manager-applet clipit
