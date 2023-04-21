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
    cat > /etc/polkit-1/rules.d/venom-live.rules <<_EOF
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

if [ -x /etc/rc.d/networkmanager ]; then
	network=networkmanager
elif [ -x /etc/rc.d/wlan ]; then
	network=wlan
fi

for i in lo dbus slim $network crond; do
	[ -f /etc/rc.d/$i ] && D="$D $i"
	[ -d /etc/sv/$i ] && ln -s /etc/sv/$i /etc/runit/runsvdir/default/
done

echo "# tmp conf in liveiso
FONT=default
KEYMAP=us
TIMEZONE=UTC
HOSTNAME=live
SYSLOG=sysklogd
SERVICES=($D)
" > /etc/rc.conf

echo "# tmp conf in liveiso
FONT=default
KEYMAP=us
TIMEZONE=UTC
HOSTNAME=live
SYSLOG=sysklogd
" > /etc/runit/rc.conf

echo "default_user $LIVEUSER" >> /etc/slim.conf
echo "auto_login yes" >> /etc/slim.conf

# comment depmod line in rc.modules, it slow down boot
if [ -f /etc/rc.modules ]; then
	sed 's,^/,#/,g' -i /etc/rc.modules
fi

sh /root/update.sh
