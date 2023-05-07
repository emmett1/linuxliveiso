#!/bin/sh

# get distro's info
if [ -f /etc/os-release ]; then
	. /etc/os-release
fi

LIVEUSER=live
PASSWORD=live

useradd -m -G users,wheel,audio,video -s /bin/bash $LIVEUSER
passwd -d $LIVEUSER &>/dev/null
passwd -d root &>/dev/null

echo "root:root" | chpasswd -c SHA512
echo "$LIVEUSER:$PASSWORD" | chpasswd -c SHA512

# hostname for live
case $NAME in
	Slackware) echo liveiso > /etc/HOSTNAME;;
	        *) echo liveiso > /etc/hostname;;
esac

# timezone
case $NAME in
	Gentoo) echo "$TIMEZONE" > $ROOT/etc/timezone
	        emerge --config sys-libs/timezone-data;;
	     *) ln -sf /usr/share/zoneinfo/UTC /etc/localtime;;
esac

# a little path to avoid these pseudofs mount again, its already handled by initramfs
if [ "$NAME" = Slackware ]; then	
	sed -i 's,/sbin/mount -v proc /proc.*,true,' /etc/rc.d/rc.S
	sed -i 's,/sbin/mount -v sysfs /sys.*,true,' /etc/rc.d/rc.S
	sed -i 's,/sbin/mount -v -n -t tmpfs tmpfs.*,true,' /etc/rc.d/rc.S
fi

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
