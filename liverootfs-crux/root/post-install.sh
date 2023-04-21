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

if [ -x $ROOT/etc/rc.d/networkmanager ]; then
	network=networkmanager
elif [ -x $ROOT/etc/rc.d/wlan ]; then
	network=wlan
fi

if [ -x $ROOT/etc/rc.d/lxdm ]; then
	dm=lxdm
elif [ -x $ROOT/etc/rc.d/lightdm ]; then
	dm=lightdm
elif [ -x $ROOT/etc/rc.d/sddm ]; then
	dm=sddm
elif [ -x $ROOT/etc/rc.d/slim ]; then
	dm=slim
fi

services="lo dbus $dm alsa bluetooth gpm $network"

# enable services
for d in $services; do
	if [ -x $ROOT/etc/rc.d/$d ]; then
		if [ "$dd" ]; then
			dd="$dd $d"
		else
			dd="$d"
		fi
	fi
	if [ -d $ROOT/etc/sv/$d ]; then
		ln -s /etc/sv/$d $ROOT/etc/runit/runsvdir/default
	fi
done

echo "#
# /etc/rc.conf: system configuration
#

FONT=default
KEYMAP=$KEYMAP
TIMEZONE=$TIMEZONE
HOSTNAME=$HOSTNAME
SYSLOG=sysklogd
SERVICES=($dd)

# End of file
" > $ROOT/etc/rc.conf

# fstab
echo "devpts /dev/pts devpts noexec,nosuid,gid=tty,mode=0620 0 0" >> $ROOT/etc/fstab
echo "shm /dev/shm tmpfs defaults 0 0" >> $ROOT/etc/fstab

# create user
# 'useradd -R' not copy all skel files, use live-chroot instead
#useradd -R $ROOT -m -G users,wheel,audio,video -s /bin/bash $USERNAME
live-chroot $ROOT useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PSWD" | chpasswd -R $ROOT -c SHA512

# root pswd
echo "root:$ROOT_PSWD" | chpasswd -R $ROOT -c SHA512

# locale
sed "s/#$LOCALE/$LOCALE/" -i $ROOT/etc/locale.gen
echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/locale.conf
live-chroot $ROOT locale-gen

# initramfs
live-chroot $ROOT mkinitramfs

# grub
if [ "$BOOTLOADER" != skip ]; then
	mkdir -p $ROOT/etc/default
	echo GRUB_DISABLE_OS_PROBER=false >> $ROOT/etc/default/grub
	if [ "$EFI_SYSTEM" = 1 ]; then
		# EFI
		live-chroot $ROOT grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=crux_grub --recheck $BOOTLOADER
	else
		# mbr
		live-chroot $ROOT grub-install --target=i386-pc $BOOTLOADER
	fi
	live-chroot $ROOT grub-mkconfig -o /boot/grub/grub.cfg
fi
