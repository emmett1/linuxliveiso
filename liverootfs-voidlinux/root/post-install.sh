#!/bin/sh
#
# this script execute to apply changes to installed system from data from live-installer
#
# list variable:
#  $ROOT       - directory where system is installed
#  $HOSTNAME   - hostname
#  $TIMEZONE   - timezone (xxxx/yyyy)
#  $KEYMAP     - keymap
#  $USERNAME   - user's login name
#  $USER_PSWD  - user's password
#  $ROOT_PSWD  - root's password
#  $LOCALE     - locale
#  $BOOTLOADER - disk to install grub (either '/dev/sdX or skip)
#  $EFI_SYSTEM - 1 if boot in UEFI mode
#

[ -d $ROOT/etc/sv/wpa ] && network=wpa
[ -d $ROOT/etc/sv/NetworkManager ] && network=NetworkManager
[ -d $ROOT/etc/sv/lxdm ] && dm=lxdm
[ -d $ROOT/etc/sv/lightdm ] && dm=lightdm
[ -d $ROOT/etc/sv/sddm ] && dm=sddm
[ -d $ROOT/etc/sv/slim ] && dm=slim

services="elogind dbus $dm alsa bluetooth gpm $network"

# enable services
for d in $services; do
	[ -d $ROOT/etc/sv/$d ] && ln -s /etc/sv/$d $ROOT/etc/runit/runsvdir/default
done

sed "s,^#HOSTNAME=.*,HOSTNAME=\"$HOSTNAME\"," -i $ROOT/etc/rc.conf
sed "s,^#TIMEZONE=.*,TIMEZONE=\"$TIMEZONE\"," -i $ROOT/etc/rc.conf
sed "s,^#HARDWARECLOCK=.*,TIMEZONE=\"UTC\"," -i $ROOT/etc/rc.conf
sed "s,^#KEYMAP=.*,KEYMAP=\"$KEYMAP\"," -i $ROOT/etc/rc.conf

# fstab
echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> $ROOT/etc/fstab

# create user
# 'useradd -R' not copy all skel files, use live-chroot instead
#useradd -R $ROOT -m -G users,wheel,audio,video -s /bin/bash $USERNAME
live-chroot $ROOT useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PSWD" | chpasswd -R $ROOT -c SHA512

# root pswd
echo "root:$ROOT_PSWD" | chpasswd -R $ROOT -c SHA512

# locale
sed "s/#$LOCALE/$LOCALE/" -i $ROOT/etc/default/libc-locales
echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/locale.conf
live-chroot $ROOT xbps-reconfigure -f glibc-locales

if [ -d $ROOT/usr/share/slim/themes/slim-void-theme ] && [ -f $ROOT/etc/slim.conf ]; then
	# use void theme	
	sed 's/current_theme.*/current_theme slim-void-theme/' -i $ROOT/etc/slim.conf
fi

# grub
if [ "$BOOTLOADER" != skip ]; then
	mkdir -p $ROOT/etc/default
	echo GRUB_DISABLE_OS_PROBER=false >> $ROOT/etc/default/grub
	if [ "$EFI_SYSTEM" = 1 ]; then
		# EFI
		live-chroot $ROOT grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void_grub --recheck $BOOTLOADER
	else
		# bios
		live-chroot $ROOT grub-install --target=i386-pc $BOOTLOADER
	fi
	live-chroot $ROOT grub-mkconfig -o /boot/grub/grub.cfg
fi
