# Arch Linux Installation
We always assume that this is an EFI installation.

- `loadkeys de-latin1`
- Identify disk: `lsblk -f`
- `dd if=/dev/zero of=/dev/[device] bs=4M status=progress oflag=sync`
- `gdisk /dev/[device]`
  - if there's no EFI partition on the system: `+256M`, EFI partition, hex code `ef00`
  - 100% rest, Linux partition, Hex code `8304`
- if there was no EFI partition: `mkfs.vfat -F32 -n EFI /dev/[device]1`
- `cryptsetup --type=luks2 --cipher=aes-xts-plain64 --hash=sha512 --iter-time=3000 --key-size=512 --pbkdf=pbkdf2 --use-urandom --verify-passphrase luksFormat /dev/[device]2`. There might be performance differences in using aes-xts-plain64 on storages with <2TB disk size, you therefore might want to go with aes-xts-plain instead.
- `cryptsetup luksOpen /dev/[device]2 root`
- `vgcreate [groupName] /dev/mapper/root`
- `lvcreate -L [RAM]GB -n [volumeName-swap] [groupName] (make it big, also due to hibernate)`
- `lvcreate -l 100%FREE -n [volumeName-root] [groupName]`
- `mkswap -L swap /dev/mapper/[groupName]-[volumeName-swap]`
- `swapon /dev/mapper/[groupName]-[volumeName-swap]`
- `mkfs.btrfs -L [partitionName] -n 16k /dev/mapper/[groupName]-[volumeName-root] -f`
- `mount -o compress=lzo /dev/mapper/[groupName]-[volumeName-root] /mnt`
- btrfs fun basics
    - `btrfs subvolume create /mnt/root`
    - `btrfs subvolume create /mnt/home`
    - `btrfs subvolume create /mnt/snapshots`
    - `mount -t btrfs -o subvol=root /dev/mapper/[groupName]-[volumeName-root] /mnt/root`
    - `mount -t btrfs -o subvol=home /dev/mapper/[groupName]-[volumeName-root] /mnt/home`
    - `mount -t btrfs -o subvol=snapshots /dev/mapper/[groupName]-[volumeName-root] /mnt/snapshots`
- mkdir /mnt/boot/efi -p
- mount /dev/[device]1 /mnt/boot/efi
- mkdir /mnt/var/backup/cryptsetup -p
