#!/bin/sh
#
# this script will be execute by live-installer after system unsquashed
#
 
# copy over all customs configs and customization except some unnecessary files
for i in $(find $LIVEROOTFS -type f | sed "s,$LIVEROOTFS,,"); do
    case $i in
        *live-installer*|*live_script.sh|*fstab|*issue|*live-installer.desktop|*post-install.sh|*post-extract.sh|*live-chroot) continue;;
    esac
    install -D $LIVEROOTFS/$i $ROOT/$i
done

exit 0
