#!/bin/sh -e

msg() {
	echo "-> $@"
}

run_chroot() {
	./live-chroot $ROOTFS $@
}

unmount() {
	while true; do
		mountpoint -q $1 || break
		umount $1 2>/dev/null
	done
}

if [ ! $(command -v mksquashfs) ]; then
	echo "mksquashfs not found"
	exit 1
fi

if [ ! $(command -v xorriso) ]; then
	echo "xorriso not found"
	exit 1
fi

if [ ! "$1" ]; then
	echo "usage:
	$0 <rootfs dir>"
	exit 1
fi

if [ ! -d "$1" ]; then
	echo "rootfs directory not exist"
	exit 1
fi

ROOTFS=$(realpath $1)

#case ${ROOTFS##*/} in
	#rootfs-*) continue;;
	       #*) echo "please use name format 'rootfs-<whatever distro name>' for rootfs directory"
	          #echo "'<whatever distro name>' will be use as the output name of your iso"
	          #echo "eg:"
	          #echo "  rootfs-gentoo-systemd-multilib"
	          #echo
	          #echo "your output iso is gentoo-systemd-multilib-<yyyymmdd>.iso"
	          #exit 1;;
#esac

distroname=${ROOTFS##*/}; distroname=${distroname#*-}
ISONAME=$distroname-$(date +"%Y%m%d")

# your exclude dirs here eg: var/cache/somedir/*
#YOUR_EXCLUDE_DIRS=""

# slackware
EXCLUDE_DIRS="$EXCLUDE_DIRS var/lib/sbopkg/* var/cache/sbopkg/* var/lib/slackpkg/*"

# gentoo
EXCLUDE_DIRS="$EXCLUDE_DIRS var/cache/distfiles/* var/tmp/*"

# summerize exclude dirs
for i in $EXCLUDE_DIRS $YOUR_EXCLUDE_DIRS; do
	squashfsexclude="$squashfsexclude -e $ROOTFS/$i"
done

if [ -f $ROOTFS/usr/lib/os-release ]; then
	. $ROOTFS/usr/lib/os-release
elif [ -f $ROOTFS/etc/os-release ]; then
	. $ROOTFS/etc/os-release
fi
DISTRONAME=${PRETTY_NAME:-LIVEISO LINUX}

for i in $ROOTFS/boot/*; do
	file $i | grep -q bzImage || continue
	KERNELFILE=$i
	KERNELVER=$(file $i | awk '{print $9}')
done

if [ ! "$KERNELFILE" ]; then
	echo "kernel file does not exist"
	exit 1
fi

if [ ! -d "$ROOTFS/usr/lib/modules/$KERNELVER" ] && [ ! -d "$ROOTFS/lib/modules/$KERNELVER" ]; then
	echo "kernel directory does not exist"
	exit 1
fi

if [ -d "$ROOTFS/usr/lib/grub/x86_64-efi" ]; then
	GRUBEFIDIR="$ROOTFS/usr/lib/grub/x86_64-efi"
elif [ -d "$ROOTFS/usr/lib64/grub/x86_64-efi" ]; then
	GRUBEFIDIR="$ROOTFS/usr/lib64/grub/x86_64-efi"
else
	echo "grub-efi files not found on target system"
	exit 1
fi

# overview
echo
echo "distro : $DISTRONAME"
echo "output : iso/$ISONAME.iso"
echo "kernel : $KERNELFILE ($KERNELVER)"
echo

msg "preparing working dirs..."
rm -fr work/_live
mkdir -p work/_live/boot
mkdir -p work/_live/isolinux
mkdir -p work/_live/rootfs

msg "copy over liverootfs..."
if [ -d liverootfs ]; then
	cp -ra liverootfs/* work/_live/rootfs/
	chown -R 0:0 work/_live/rootfs
fi

if [ -d liverootfs-$distroname ]; then
	msg "copy over liverootfs-$distroname..."
	cp -ra liverootfs-$distroname/* work/_live/rootfs/
	chown -R 0:0 work/_live/rootfs
fi

[ -f work/_live/rootfs/root/splash.png ] && {
	mv work/_live/rootfs/root/splash.png work/_live/isolinux
}

[ -f work/mkinitramfs ] || {
	msg "fetching mkinitramfs script..."
	curl -o work/mkinitramfs https://raw.githubusercontent.com/venomlinux/mkinitramfs/master/mkinitramfs
}

[ -f work/init.in ] || {
	msg "fetching init script..."
	curl -o work/init.in https://raw.githubusercontent.com/venomlinux/mkinitramfs/master/init.in
}

[ -f work/syslinux-6.03.tar.xz ] || {
	msg "fetching syslinux sources..."
	curl -L -o work/syslinux-6.03.tar.xz http://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
}

rm -fr work/syslinux-6.03
tar xf work/syslinux-6.03.tar.xz -C work

for i in $(findmnt --list | awk '{print $1}' | grep $ROOTFS | sort -r); do
	[ "$i" = "$ROOTFS" ] && continue
	echo ">> unmounting $i"
	unmount $i
done

msg "copy over needed syslinux files..."
cp work/syslinux-6.03/bios/core/isolinux.bin work/_live/isolinux
cp work/syslinux-6.03/bios/com32/chain/chain.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/libutil/libutil.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/lib/libcom32.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/menu/vesamenu.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/menu/menu.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/modules/reboot.c32 work/_live/isolinux
cp work/syslinux-6.03/bios/com32/modules/poweroff.c32 work/_live/isolinux

if [ -f rootfs-$distroname.sfs ]; then
	msg "use existing 'rootfs-$distroname.sfs'..."
	cp rootfs-$distroname.sfs work/_live/boot/rootfs.sfs
else
	msg "squashing '$ROOTFS'..."
	mksquashfs $ROOTFS work/_live/boot/rootfs.sfs \
		-b 1048576 \
		-comp xz \
		-e $ROOTFS/root/* \
		-e $ROOTFS/home/* \
		-e $ROOTFS/tools* \
		-e $ROOTFS/tmp/* \
		-e $ROOTFS/dev/* \
		-e $ROOTFS/proc/* \
		-e $ROOTFS/sys/* \
		-e $ROOTFS/run/* \
		$squashfsexclude 2>/dev/null
fi

install -m755 work/mkinitramfs $ROOTFS/tmp/mkinitramfs
install -m755 work/init.in $ROOTFS/tmp/init
install -m644 files/liveiso.hook $ROOTFS/tmp/liveiso.hook
touch $ROOTFS/tmp/mkinitramfs.conf
msg "generating livecd initramfs..."
run_chroot /tmp/mkinitramfs -c /tmp/mkinitramfs.conf -k $KERNELVER -i /tmp/init -a /tmp/liveiso -o /tmp/initrd
rm $ROOTFS/tmp/mkinitramfs $ROOTFS/tmp/init $ROOTFS/tmp/mkinitramfs.conf $ROOTFS/tmp/liveiso.hook 

cp $KERNELFILE work/_live/boot/vmlinuz
mv $ROOTFS/tmp/initrd work/_live/boot/initrd

msg "setup UEFI mode..."
mkdir -p work/_live/boot/grub/x86_64-efi work/_live/boot/grub/fonts
echo "set prefix=/boot/grub" > work/_live/boot/grub-early.cfg
cp -a $GRUBEFIDIR/*.mod work/_live/boot/grub/x86_64-efi
cp -a $GRUBEFIDIR/*.lst work/_live/boot/grub/x86_64-efi
#if [ -f $ROOTFS/usr/share/grub/*.pf2 ]; then
	#cp $ROOTFS/usr/share/grub/*.pf2 work/_live/boot/grub/fonts/unicode.pf2
#fi
cp files/unicode.pf2 work/_live/boot/grub/fonts/
mkdir -p work/_live/efi/boot
grub-mkimage -c work/_live/boot/grub-early.cfg -o work/_live/efi/boot/bootx64.efi -O x86_64-efi -p "" iso9660 normal search search_fs_file
modprobe loop
dd if=/dev/zero of=work/_live/boot/efiboot.img count=4096
mkdosfs -n LIVE-UEFI work/_live/boot/efiboot.img
mkdir -p work/_live/boot/efiboot
mount -o loop work/_live/boot/efiboot.img work/_live/boot/efiboot
mkdir -p work/_live/boot/efiboot/EFI/boot
cp work/_live/efi/boot/bootx64.efi work/_live/boot/efiboot/EFI/boot
unmount work/_live/boot/efiboot
rm -fr work/_live/boot/efiboot

sed "s/@DISTRONAME@/$DISTRONAME/g" files/grub.cfg > work/_live/boot/grub/grub.cfg
sed "s/@DISTRONAME@/$DISTRONAME/g" files/isolinux.cfg > work/_live/isolinux/isolinux.cfg

mkdir -p iso
rm -f iso/$ISONAME.iso    
xorriso -as mkisofs \
	-isohybrid-mbr work/syslinux-6.03/bios/mbr/isohdpfx.bin \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	  -no-emul-boot \
	  -boot-load-size 4 \
	  -boot-info-table \
	-eltorito-alt-boot \
	-e boot/efiboot.img \
	  -no-emul-boot \
	  -isohybrid-gpt-basdat \
	  -volid LIVEISO \
	-o iso/$ISONAME.iso work/_live

echo "iso created : iso/$ISONAME.iso"
echo "iso size    : $(du -h iso/$ISONAME.iso | awk '{print $1}')"
echo

#rm -fr work/_live work/syslinux-6.03
