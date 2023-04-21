#!/bin/sh

[ -f "$PWD"/qemu-vm.img ] || {
	qemu-img create -f qcow2 "$PWD"/qemu-vm.img 50G
}

qemu-system-x86_64 -enable-kvm \
        -cpu host \
        -drive file="$PWD"/qemu-vm.img,if=virtio \
        -device virtio-rng-pci \
        -m 2G \
        -smp 4 \
        -monitor stdio \
        -name "LIVE LINUX VM" \
        -boot d \
        -cdrom $@

rm -f "$PWD"/qemu-vm.img

exit 0
