# Arch Linux Installation
We always assume that this is an EFI installation.

- `loadkeys de-latin1`
- Identify disk: `lsblk -f`
- `dd if=/dev/zero of=/dev/[device] bs=4M status=progress oflag=sync`

For GPT partition automounting, the EFI partion _must_ be on the same device as the Linux root partition!

- `gdisk /dev/[device]`
  - EFI partition on the system: `+256M`, EFI partition, hex code `ef00`
  - 100% rest, Linux partition, Hex code `8304`
- format EFI partition: `mkfs.vfat -F32 -n EFI /dev/[device]1`
- `cryptsetup luksFormat /dev/[device]2`.
- `cryptsetup luksOpen /dev/[device]2 luks`
- `mkfs.btrfs -L arch /dev/mapper/luks`
- `mount /dev/mapper/luks /mnt`


- btrfs fun basics
  - `btrfs subvolume create /mnt/@`
  - `btrfs subvolume create /mnt/@swap`
  - `btrfs subvolume create /mnt/@home`
  - `btrfs subvolume create /mnt/@snapshots`
  - `umount /mnt`
  - `mount -o noatime,ssd,compress=lzo,subvol=@ /dev/mapper/luks /mnt`
  - `mount -m -o noatime,ssd,compress=lzo,subvol=@home /dev/mapper/root /mnt/home`
  - `mount -m -o noatime,ssd,compress=lzo,subvol=@swap /dev/mapper/root /mnt/swap`
  - `mount -m -o noatime,ssd,compress=lzo,subvol=@snapshots /dev/mapper/root /mnt/.snapshots`

- `mount -m -o umask=0077,noexec,nosuid,nodev /dev/[device]1 /mnt/boot`

Install base system:
`pacstrap -K /mnt base base-devel linux-lts linux-firmware btrfs-progs {intel|amd}-ucode sudo vim git reflector dhcpcd udisks2 fwupd`

- `genfstab -U /mnt >> /mnt/etc/fstab`
- `arch-chroot /mnt`
- `ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime # replace with your timezone`
- `hwclock --systohc --utc`
- Set locale: uncomment desired locales from `/etc/locale.gen`.
- `locale-gen`
- `echo "LANG=en_US.UTF-8" > /etc/locale.conf`
- `export LANG=en_US.UTF-8`
- `echo KEYMAP=de-latin1-nodeadkeys > /etc/vconsole.conf`
- `echo "arch" > /etc/hostname # replace with your hostname`
- `vim /etc/hosts
127.0.0.1 <hostname>.localdomain localhost
::1 localhost.localdomain localhost`

- `bootctl --path=/boot install`
- mkinitcpio:
	```
 	vim /etc/mkinitcpio.conf
 	---
	HOOKS=(systemd keyboard autodetect microcode modconf kms sd-vconsole sd-encrypt filesystems fsck)`
	```
- kernel command line:
	```
 	mkdir /etc/cmdline.d
	vim /etc/cmdline.d/root.conf
 	# Btrfs: GPT partition automount
	rootflags=subvol=@
	bgrt_disable quiet loglevel=4
	---
	vim /etc/cmdline.d/performance.conf
	preempt=full threadirqs
	```
 - Configure `.preset` for mkinitcpio (UKI).
	```
	vim /etc/mkinitcpio.d/linux.preset
	```
	- Uncomment `*_uki=` lines, replace any `/efi/*` with `/boot/*`, comment out `*_image=` lines, uncomment splash if desired.
	- Make sure `/boot/EFI/Linux` exists (where `uki` points to)
- `mkinitcpio -P`
- `exit`
- `umount -R /mnt`
- `reboot`
