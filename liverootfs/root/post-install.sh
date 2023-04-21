#!/bin/sh
#
# this script execute to apply changes to installed system from data from venom-installer
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
elif [ -x $ROOT/etc/rc.d/network ]; then
	network=network
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

daemons="sysklogd dbus $dm alsa bluetooth gpm $network"

# enable services
for d in $daemons; do
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

# hostname
echo "$HOSTNAME" > $ROOT/etc/hostname

# hardware clock
#sed "s;#HARDWARECLOCK=.*;HARDWARECLOCK=\"$clock_var\";" -i $ROOT/etc/rc.conf
# temporarily set default to localtime
sed "s;#HARDWARECLOCK=.*;HARDWARECLOCK=\"localtime\";" -i $ROOT/etc/rc.conf
sed "s;#HARDWARECLOCK=.*;HARDWARECLOCK=\"localtime\";" -i $ROOT/etc/runit/runit.conf

# timezone
sed "s;#TIMEZONE=.*;TIMEZONE=\"$TIMEZONE\";" -i $ROOT/etc/rc.conf
sed "s;#TIMEZONE=.*;TIMEZONE=\"$TIMEZONE\";" -i $ROOT/etc/runit/runit.conf

# keymap
sed "s;#KEYMAP=.*;KEYMAP=\"$KEYMAP\";" -i $ROOT/etc/rc.conf
sed "s;#KEYMAP=.*;KEYMAP=\"$KEYMAP\";" -i $ROOT/etc/runit/runit.conf

# daemons
sed "s;#DAEMONS=.*;DAEMONS=\"$dd\";" -i $ROOT/etc/rc.conf

# create user
# 'useradd -R' not copy all skel files, use xchroot instead
#useradd -R $ROOT -m -G users,wheel,audio,video -s /bin/bash $USERNAME
xchroot $ROOT useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PSWD" | chpasswd -R $ROOT -c SHA512

# root pswd
echo "root:$ROOT_PSWD" | chpasswd -R $ROOT -c SHA512

# locale
sed "s/#$LOCALE/$LOCALE/" -i $ROOT/etc/locales
echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/locale.conf
xchroot $ROOT genlocales

# initramfs
xchroot $ROOT mkinitramfs

# grub
if [ "$BOOTLOADER" != skip ]; then
	echo GRUB_DISABLE_OS_PROBER=false >> $ROOT/etc/default/grub
	if [ "$EFI_SYSTEM" = 1 ]; then
		# EFI
		xchroot $ROOT grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=venom_grub --recheck $BOOTLOADER
	else
		# mbr
		xchroot $ROOT grub-install --target=i386-pc $BOOTLOADER
	fi
	xchroot $ROOT grub-mkconfig -o /boot/grub/grub.cfg
fi
