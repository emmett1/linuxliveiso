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

chrootrun() {
	live-chroot $ROOT $@
}

enable_systemd_service() {
	[ -f $ROOT/usr/lib/systemd/system/$1.service ] && chrootrun systemctl enable $1
}

# hostname
echo "$HOSTNAME" > $ROOT/etc/hostname

# timezone
ln -sf /usr/share/zoneinfo/"$TIMEZONE" $ROOT/etc/localtime

# keymap
echo "KEYMAP=$KEYMAP" > $ROOT/etc/vconsole.conf

# services
enable_systemd_service lxdm
enable_systemd_service NetworkManager

# create user
# 'useradd -R' not copy all skel files, use xchroot instead
#useradd -R $ROOT -m -G users,wheel,audio,video -s /bin/bash $USERNAME
chrootrun useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PSWD" | chpasswd -R $ROOT -c SHA512

# root pswd
echo "root:$ROOT_PSWD" | chpasswd -R $ROOT -c SHA512

# locale
sed "s/#$LOCALE/$LOCALE/" -i  $ROOT/etc/locale.gen
echo "LANG=en_US.UTF-8" > $ROOT/etc/locale.conf
chrootrun locale-gen

# initramfs
chrootrun mkinitcpio -P

# grub
if [ "$BOOTLOADER" != skip ]; then
	echo GRUB_DISABLE_OS_PROBER=false >> $ROOT/etc/default/grub
	if [ "$EFI_SYSTEM" = 1 ]; then
		# EFI
		chrootrun grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=venom_grub --recheck $BOOTLOADER
	else
		# mbr
		chrootrun grub-install --target=i386-pc $BOOTLOADER
	fi
	chrootrun grub-mkconfig -o /boot/grub/grub.cfg
fi
