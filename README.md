# Arch Linux Installation
We always assume that this is an EFI installation.

1. Initial steps after booting from the Arch Linux installation medium:
	- `loadkeys de-latin1`
	- Identify disk: `lsblk -f`
	- `dd if=/dev/zero of=/dev/[device] bs=4M status=progress oflag=sync`
2. Partitioning: For GPT partition automounting, the EFI partion _must_ be on the same device as the Linux root partition!
	- `gdisk /dev/[device]`
	- EFI partition on the system: `+256M`, EFI partition, hex code `ef00`
	- 100% rest, Linux partition, Hex code `8304`
	- format EFI partition: `mkfs.vfat -F32 -n EFI /dev/[device]1`
	- `cryptsetup luksFormat /dev/[device]2`.
	- `cryptsetup luksOpen /dev/[device]2 luks`
	- `mkfs.btrfs -L arch /dev/mapper/root`
	- `mount /dev/mapper/root /mnt`
3. btrfs setup:
	- `btrfs subvolume create /mnt/@`
	- `btrfs subvolume create /mnt/@swap`
	- `btrfs subvolume create /mnt/@home`
	- `btrfs subvolume create /mnt/@snapshots`
	- `umount /mnt`
	- `mount -o noatime,ssd,compress=lzo,subvol=@ /dev/mapper/root /mnt`
	- `mount -m -o noatime,ssd,compress=lzo,subvol=@home /dev/mapper/root /mnt/home`
	- `mount -m -o noatime,ssd,compress=lzo,subvol=@swap /dev/mapper/root /mnt/swap`
	- `mount -m -o noatime,ssd,compress=lzo,subvol=@snapshots /dev/mapper/root /mnt/.snapshots`
4. Mount EFI partition:
	```
	mount -m -o umask=0077,noexec,nosuid,nodev /dev/[device]1 /mnt/boot
	```
5. Install base system:
	- `pacstrap -K /mnt base base-devel linux-lts linux-firmware btrfs-progs {intel|amd}-ucode sudo vim git reflector pacman-contrib networkmanager udisks2 fwupd`
	- `genfstab -U /mnt >> /mnt/etc/fstab`
	- `arch-chroot /mnt`
	- `ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime # replace with your timezone`
	- `hwclock --systohc --utc`
	```
	---
	Set locale: uncomment desired locales from `/etc/locale.gen`.
	---
	locale-gen
	```
	- `echo "LANG=en_US.UTF-8" > /etc/locale.conf`
	- `export LANG=en_US.UTF-8`
	- `echo KEYMAP=de-latin1-nodeadkeys > /etc/vconsole.conf`
	- `echo "arch" > /etc/hostname # replace with your hostname`
	```
	vim /etc/hosts
	----
	127.0.0.1 <hostname>.localdomain localhost
	::1 localhost.localdomain localhost`
	```
6. Install bootloader:
	```
	bootctl --path=/boot install
	```
7. Setup initial ramdisk:
	- configure mkinitcpio:
		```
 		vim /etc/mkinitcpio.conf
 		---
		HOOKS=(base systemd keyboard autodetect microcode modconf kms sd-vconsole sd-encrypt filesystems fsck)`
		```
	- configure kernel command line:
 		- `mkdir /etc/cmdline.d`
		```
		vim /etc/cmdline.d/root.conf
		---
 		# Btrfs: GPT partition automount
		rootflags=subvol=@
		bgrt_disable quiet loglevel=4
		```
		```
		vim /etc/cmdline.d/performance.conf
		---
		preempt=full threadirqs
		```
 	- Configure `.preset` for mkinitcpio (UKI).
		```
		vim /etc/mkinitcpio.d/linux.preset
		```
		- Uncomment `*_uki=` lines, replace any `/efi/*` with `/boot/*`, comment out `*_image=` lines, uncomment splash if desired.
		- Make sure `/boot/EFI/Linux` exists (where `uki` points to)
	- `mkinitcpio -P`
	- `rm /boot/initramfs-linux*.img`
8. The rest:
	- `systemctl enable NetworkManager`
	- `passwd`
	- `exit`
	- `umount -R /mnt`
	- `reboot`

9. Enrolling fido2 key:
	- `systemd-cryptenroll /dev/[device]2 --fido2-device=auto --fido2-with-client-pin=yes --fido2-with-user-presence=yes`
	- configure /etc/crypttab.initramfs
		```
		vim /etc/crypttab.initramfs
	 	---
		root UUID=<blkid /dev/[device]2> none fido2-device=auto
		```
	- `mkinitcpio -P`

10. Create user
	```
	useradd -mG wheel,storage,power,log,adm,uucp,tss,rfkill -s /bin/bash <username> # replace with your username

	passwd <username>
	```

11. sudo
	- set vim editor for visudo
		```
		vim /etc/sudoers
		---
		Defaults editor=/usr/bin/vim
		```
	- allow group wheel to run with root privileges
		```
		visudo
		---
		%wheel ALL=(ALL:ALL) ALL
		```

12. pacman & reflector
	- Enable color and parallel downloads:
		```
		sudo vim /etc/pacman.conf
		---
		Uncomment: Color
		Uncomment: ParallelDownloads 5
		```
	- Discard unused packages: `sudo systemctl enable paccache.timer`
	- Configure reflector
		```
		cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.ori
		vim /etc/xdg/reflector/reflector.conf
		---
		--save /etc/pacman.d/mirrorlist
		--protocol https
		--country Germany # replace Germany with you country
		--latest 5
		--sort rate
		```
	- Enable reflector
		```
		systemctl enable reflector.timer
		```
13. Improving compile times - makepkg
	- Parallel compilation
		```
		vim /etc/makepkg.conf
	 	---
		MAKEFLAGS="-j$(nproc --ignore=2)" # 2 less than total threads
		```

14. Install yay
	```
	cd /tmp
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	```

15. Installing xfce
	- `pacman -S lightdm lightdm-gtk-greater lightdm-gtk-greater-settings xorg-server nvidia nvidia-utils xfce4 network-manager-applet`
	- `systemctl enbale lightdm.service`

16. Configure timesynd
	```
	sudo vim /etc/systemd/timesyncd.conf
	---
	edit NTP=
	Comment out FallbackNTP
	---
	yay -S networkmanager-dispatcher-timesyncd
	```

17. Swap
	- create swapfile: `sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile`
	- `sudo swapon /swap/swapfile`
	```
	sudo vim /etc/fstab
	---
	# /swap/swapfile
	/swap/swapfile	none	swap	defaults 0 0
	```