## Turn your linux desktop rice into installable live iso!

Yeah as the title says, if your are a linux desktop ricer, why not make it an installable iso so you can share it to anyone who wanna test it or install it on their machines. With this scripts, make a custom iso with your own customization and linux distro of your choice is just easy. So far this script is tested myself with some distros like Archlinux, Void Linux, CRUX and Venom Linux.

## How to do it?

Basically you just need your rootfs somewhere then run `./mkiso.sh <path to your rootfs>`, then the iso iso is ready in `iso/` directory. But if you want include some customization and installable, theres a few extra step.

1. Prepare your rootfs of distro of your choice, i recommend write a script to do it, so you can just run it anytime when you want to make an iso. I've provide scripts for some distros `mkrootfs-<distro>.sh`, just modify it to suit your need. And i recommend your rootfs directory named `rootfs-<distro name>`, because `mkiso.sh` script use that 'distro name' for customization dir & output iso. I suggest make it clean, less modified as possible, any modification put it in `liverootfs-<distro name>`, `live_script.sh` or `post-install.sh` instead.
2. Prepare your customization files inside `liverootfs-<distro name>` dir. You can copy over from `liverootfs` (global customization files) directory then modify it to suit your need. For config files like '.Xdefaults', '.bash_profile', '.bashrc' and etc. that should be in user's HOME, place it in `liverootfs-<distro name>/etc/skel/` directory, this skel files will automatically copied over when user is created.
3. Modify `liverootfs-<distro name>/root/live_script.sh` for your live session like, make temporary live user, set its password, enable systemd services and etc. This `live_script.sh` is executed inside initramfs just before live system is loaded, so whatever change you made to live session in this script only affect live session.
4. Modify `liverootfs-<distro name>/root/post-install.sh` if you want your live distro installable, whatever value got from installer is passed to this script to configure final installed system, so this `post-install.sh` depends on your distro how to configure it. (see provided `post-install.sh`).
5. Run `./mkiso.sh rootfs-<distro name>` to generate live iso. The iso output is `iso/` directory.
6. Test your created iso using `run_qemu` script by running `./run_qemu <path to iso>`. (make sure qemu is installed).

*Note: use `live-installer` in live session to install the distro to disk.

## Requirements

### for host
- xorriso - to create iso
- squashfs-tools - to compress rootfs
- curl - to fetch necessary files
- gimp - to create custom grub/syslinux splash (optional)

### for target rootfs
- grub-efi - to support both bios and uefi boot
- squashfs-tools - to extract compressed rootfs to disk (optional, required if want to install to disk)
- generic kernel - required for necessary kernel modules to make bootable liveiso possible (non-sourcebased distro like gentoo or LFS dont worry :))

## Directory structure

Heres i'm provide directory structure and quick explanation for each dirs and files:
```
livelinuxiso/
 |- files/ - contains files required for the iso
 |   |- grub.cfg - grub config when booting using UEFI, you can modify it as you want
 |   |- isolinux.cfg - syslinux config when booting bios mode, you can modify it as you want
 |   \- liveiso.hook - hook file for mkinitramfs script, to generate and execute stuffs in initramfs
 |- iso/ - output directory for created isos
 |- liverootfs/ - global customization directory, copied over into iso (dont modify this, use liverootfs-<distro> instead)
 |   |- etc/
 |   |  \- issue - default /etc/issue for live iso
 |   |- root/
 |   |  |- live_scripts.sh - executed right before live session started, to temporarily modify live session
 |   |  |- post-extract.sh - executed right after uncompressed rootfs to disk, to copy over customization files (executed by live-installer)
 |   |  |- post-install.sh - executed by live-installer to configure final installed system
 |   |  \- splash.png - default splash image for grub and syslinux
 |   \- usr/
 |      \- bin/
 |          |- live-chroot - live-chroot script for live-installer configure final installed system
 |          \- live-installer - the installer
 |- liverootfs-<distro>/ - your distro customization directory, replacing global 'liverootfs' files
 |- rootfs-<distro>/ - your distro's rootfs directory
 |- work/ - working directory
 |- live-chroot - chroot script helper to modify your rootfs
 |- mkiso.sh - main script to generate iso
 |- mkrootfs-<distro>.sh - your custom script to prepare distro's rootfs (optional, not required at all)
 \- run_qemu - script to test iso using qemu
 ```
      
