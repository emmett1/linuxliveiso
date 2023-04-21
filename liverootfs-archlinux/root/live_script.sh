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

# timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

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

systemctl enable lxdm
systemctl enable NetworkManager

sed -i "s/^# autologin=.*/autologin=$LIVEUSER/" /etc/lxdm/lxdm.conf
