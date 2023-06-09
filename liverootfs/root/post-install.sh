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

_run() {
	live-chroot $ROOT $@
}

# get distro's info
if [ -f /etc/os-release ]; then
	. /etc/os-release
fi

# hostname
case $NAME in
	Slackware) echo "$HOSTNAME" > $ROOT/etc/HOSTNAME;;
	        *) echo "$HOSTNAME" > $ROOT/etc/hostname;;
esac

# hardware clock
case $NAME in
	Venom*) sed "s;#HARDWARECLOCK=.*;HARDWARECLOCK=\"localtime\";" -i $ROOT/etc/rc.conf
	        sed "s;#HARDWARECLOCK=.*;HARDWARECLOCK=\"localtime\";" -i $ROOT/etc/runit/runit.conf;;
	  Void) sed "s,^#HARDWARECLOCK=.*,HARDWARECLOCK=\"localtime\"," -i $ROOT/etc/rc.conf;;
esac

# timezone
case $NAME in
	Slackware) ln -sf /usr/share/zoneinfo/$TIMEZONE $ROOT/etc/localtime;;
	   Gentoo) echo "$TIMEZONE" > $ROOT/etc/timezone
	           emerge --config sys-libs/timezone-data;;
	     Void) sed "s,^#TIMEZONE=.*,TIMEZONE=\"$TIMEZONE\"," -i $ROOT/etc/rc.conf;;
	   Venom*) sed "s;#TIMEZONE=.*;TIMEZONE=\"$TIMEZONE\";" -i $ROOT/etc/rc.conf
               sed "s;#TIMEZONE=.*;TIMEZONE=\"$TIMEZONE\";" -i $ROOT/etc/runit/runit.conf;;
esac

# keymap
case $NAME in
	   Gentoo) echo "keymap=\"$KEYMAP\"" > $ROOT/etc/conf.d/keymaps;;
	     Void) sed "s,^#KEYMAP=.*,KEYMAP=\"$KEYMAP\"," -i $ROOT/etc/rc.conf;;
   	   Venom*) sed "s;#KEYMAP=.*;KEYMAP=\"$KEYMAP\";" -i $ROOT/etc/rc.conf
               sed "s;#KEYMAP=.*;KEYMAP=\"$KEYMAP\";" -i $ROOT/etc/runit/runit.conf;;
esac

# locale
case $NAME in
	Slackware) sed "s,LANG=en_US,LANG=$LOCALE,g" -i $ROOT/etc/profile.d/lang.sh;;
	   Gentoo) sed "s/#$LOCALE/$LOCALE/g" -i $ROOT/etc/locale.gen
	           echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/env.d/02locale
	           _run locale-gen;;
	     Void) sed "s/#$LOCALE/$LOCALE/" -i $ROOT/etc/default/libc-locales
	           echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/locale.conf
	           _run xbps-reconfigure -f glibc-locales;;
	   Venom*) sed "s/#$LOCALE/$LOCALE/" -i $ROOT/etc/locales
	           echo "LANG=$LOCALE.UTF-8" > $ROOT/etc/locale.conf
	           _run genlocales;;
esac

# fstab
case $NAME in
	Slackware) echo "/dev/fd0 /mnt/floppy auto noauto,owner 0 0" >> $ROOT/etc/fstab
	           echo "devpts /dev/pts devpts gid=5,mode=620 0 0" >> $ROOT/etc/fstab
	           echo "proc /proc proc defaults 0 0" >> $ROOT/etc/fstab
	           echo "tmpfs /dev/shm tmpfs nosuid,nodev,noexec 0 0" >> $ROOT/etc/fstab;;
	     Void) echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> $ROOT/etc/fstab;;
esac

if [ "$NAME" = Void ]; then
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
	# use void theme	
	if [ -d $ROOT/usr/share/slim/themes/slim-void-theme ] && [ -f $ROOT/etc/slim.conf ]; then
		sed 's/current_theme.*/current_theme slim-void-theme/' -i $ROOT/etc/slim.conf
	fi
fi

if [ "$NAME" = "Venom Linux" ]; then
	[ -x $ROOT/etc/rc.d/network ] && network=network
	[ -x $ROOT/etc/rc.d/networkmanager ] && network=networkmanager
	[ -x $ROOT/etc/rc.d/lxdm ] && dm=lxdm
	[ -x $ROOT/etc/rc.d/lightdm ] && dm=lightdm
	[ -x $ROOT/etc/rc.d/sddm ] && dm=sddm
	[ -x $ROOT/etc/rc.d/slim ] && dm=slim
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
	sed "s;#DAEMONS=.*;DAEMONS=\"$dd\";" -i $ROOT/etc/rc.conf
fi

if [ "$NAME" = Gentoo ]; then
	[ -f $ROOT/etc/init.d/elogind ] && _run rc-update add elogind boot
	[ -f $ROOT/etc/init.d/dbus ] && _run rc-update add elogind boot
	[ -f $ROOT/etc/init.d/display-manager ] && {
		sed 's,DISPLAYMANAGER=.*,DISPLAYMANAGER=\"slim\"' -i $ROOT/etc/conf.d/display-manager
		_run rc-update add display-manager default
	}
fi

# create user
# 'useradd -R' not copy all skel files, use _run instead
#useradd -R $ROOT -m -G users,wheel,audio,video -s /bin/bash $USERNAME
_run useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PSWD" | chpasswd -R $ROOT -c SHA512

# root pswd
echo "root:$ROOT_PSWD" | chpasswd -R $ROOT -c SHA512

# initramfs
case $NAME in
	Slackware) echo "#!/bin/sh" > $ROOT/tmp/geninitrd.sh
	           _run /usr/share/mkinitrd/mkinitrd_command_generator.sh | grep ^mkinitrd >> /tmp/geninitrd.sh
	           _run sh /tmp/geninitrd.sh
	           rm -f $ROOT/tmp/geninitrd.sh;;
	   Venom*) _run mkinitramfs;;
	   Gentoo) _run emerge --config sys-kernel/gentoo-kernel
esac

# grub
if [ "$BOOTLOADER" != skip ]; then
	echo GRUB_DISABLE_OS_PROBER=false >> $ROOT/etc/default/grub
	if [ "$EFI_SYSTEM" = 1 ]; then
		# EFI
		_run grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=live_grub --recheck $BOOTLOADER
	else
		# mbr
		_run grub-install --target=i386-pc $BOOTLOADER
	fi
	_run grub-mkconfig -o /boot/grub/grub.cfg
fi
