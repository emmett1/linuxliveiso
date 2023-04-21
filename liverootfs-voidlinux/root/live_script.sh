#!/bin/sh

LIVEUSER=live
PASSWORD=live

useradd -m -G users,wheel,audio,video -s /bin/bash $LIVEUSER
passwd -d $LIVEUSER &>/dev/null
passwd -d root &>/dev/null

echo "root:root" | chpasswd -c SHA512
echo "$LIVEUSER:$PASSWORD" | chpasswd -c SHA512

# hostname for live
echo liveiso > /etc/hostname

# enable sudo permission for all user in live
if [ -f /etc/sudoers ]; then
    echo "$LIVEUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# allow polkit for wheel group in live
if [ -d /etc/polkit-1 ]; then
    cat > /etc/polkit-1/rules.d/live.rules <<_EOF
polkit.addAdminRule(function(action, subject) {
    return ["unix-group:wheel"];
});
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
_EOF
fi

[ -d /etc/sv/wpa ] && network=wpa
[ -d /etc/sv/NetworkManager ] && network=NetworkManager
[ -d /etc/sv/lxdm ] && dm=lxdm
[ -d /etc/sv/lightdm ] && dm=lightdm
[ -d /etc/sv/sddm ] && dm=sddm
[ -d /etc/sv/slim ] && dm=slim

services="elogind dbus $dm alsa bluetooth gpm $network"

# enable services
for d in $services; do
	[ -d /etc/sv/$d ] && ln -s /etc/sv/$d /etc/runit/runsvdir/default
done

if [ -f /etc/slim.conf ]; then
	# slim autologin
	echo "default_user $LIVEUSER" >> /etc/slim.conf
	echo "auto_login yes" >> /etc/slim.conf
	if [ -d /usr/share/slim/themes/slim-void-theme ]; then
		# use void theme	
		sed 's/current_theme.*/current_theme slim-void-theme/' -i /etc/slim.conf
	fi
fi

# use en_US as default locale
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
echo "en_US ISO-8859-1" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
