#!/bin/sh -e

run_chroot() {
	./xchroot $ROOTFS $@
}

if [ ! "$1" ]; then
	echo "usage:
	$0 <rootfs dir>"
	exit 1
fi

ROOTFS=$(realpath $1)
distroname=${ROOTFS##*/}
distroname=${distroname#*-}
ISONAME=$distroname-$(date +"%Y%m%d")

if [ ! -d $ROOTFS ]; then
	echo "rootfs directory not exist"
	exit 1
fi

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

rm -fr work/_live
mkdir -p work/_live/boot
mkdir -p work/_live/isolinux
mkdir -p work/_live/rootfs

if [ -d liverootfs ]; then
	cp -ra liverootfs/* work/_live/rootfs/
	chown -R 0:0 work/_live/rootfs
fi

if [ -d liverootfs-$distroname ]; then
	cp -ra liverootfs-$distroname/* work/_live/rootfs/
	chown -R 0:0 work/_live/rootfs
fi

[ -f work/_live/rootfs/root/splash.png ] && {
	mv work/_live/rootfs/root/splash.png work/_live/isolinux
}

[ -f work/mkinitramfs ] || {
	curl -o work/mkinitramfs https://raw.githubusercontent.com/venomlinux/mkinitramfs/master/mkinitramfs
}

[ -f work/init.in ] || {
	curl -o work/init.in https://raw.githubusercontent.com/venomlinux/mkinitramfs/master/init.in
}

[ -f work/syslinux-6.03.tar.xz ] || {
	curl -L -o work/syslinux-6.03.tar.xz http://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
}

rm -fr work/syslinux-6.03
tar xf work/syslinux-6.03.tar.xz -C work

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
	cp rootfs-$distroname.sfs work/_live/boot/rootfs.sfs
else
	mksquashfs $ROOTFS work/_live/boot/rootfs.sfs \
		-b 1048576 \
		-comp xz \
		-e $ROOTFS/root/* \
		-e $ROOTFS/tools* \
		-e $ROOTFS/tmp/* \
		-e $ROOTFS/dev/* \
		-e $ROOTFS/proc/* \
		-e $ROOTFS/sys/* \
		-e $ROOTFS/run/* 2>/dev/null
fi

install -m755 work/mkinitramfs $ROOTFS/tmp/mkinitramfs
install -m755 work/init.in $ROOTFS/tmp/init
install -m644 files/liveiso.hook $ROOTFS/tmp/liveiso.hook
touch $ROOTFS/tmp/mkinitramfs.conf
run_chroot /tmp/mkinitramfs -c /tmp/mkinitramfs.conf -k $KERNELVER -i /tmp/init -a /tmp/liveiso -o /tmp/initrd
rm $ROOTFS/tmp/mkinitramfs $ROOTFS/tmp/init $ROOTFS/tmp/mkinitramfs.conf $ROOTFS/tmp/liveiso.hook 

cp $KERNELFILE work/_live/boot/vmlinuz
mv $ROOTFS/tmp/initrd work/_live/boot/initrd

# Setup UEFI mode...
mkdir -p work/_live/boot/grub/x86_64-efi work/_live/boot/grub/fonts
echo "set prefix=/boot/grub" > work/_live/boot/grub-early.cfg
cp -a $ROOTFS/usr/lib/grub/x86_64-efi/*.mod work/_live/boot/grub/x86_64-efi
cp -a $ROOTFS/usr/lib/grub/x86_64-efi/*.lst work/_live/boot/grub/x86_64-efi
cp $ROOTFS/usr/share/grub/unicode.pf2 work/_live/boot/grub/fonts
mkdir -p work/_live/efi/boot
grub-mkimage -c work/_live/boot/grub-early.cfg -o work/_live/efi/boot/bootx64.efi -O x86_64-efi -p "" iso9660 normal search search_fs_file
modprobe loop
dd if=/dev/zero of=work/_live/boot/efiboot.img count=4096
mkdosfs -n LIVE-UEFI work/_live/boot/efiboot.img
mkdir -p work/_live/boot/efiboot
mount -o loop work/_live/boot/efiboot.img work/_live/boot/efiboot
mkdir -p work/_live/boot/efiboot/EFI/boot
cp work/_live/efi/boot/bootx64.efi work/_live/boot/efiboot/EFI/boot
umount work/_live/boot/efiboot
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

#rm -fr work/_live work/syslinux-6.03
