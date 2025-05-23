# Arch Linux Installation

We always assume that this is an EFI installation.

1. Initial steps after booting from the Arch Linux installation medium:

   - `loadkeys de-latin1`
   - Identify disk: `lsblk -f`
   - `dd if=/dev/zero of=/dev/[device] bs=4M status=progress oflag=sync`

2. Partitioning: For GPT partition automounting, the EFI partion _must_ be on the same device as the Linux root partition!

   - `gdisk /dev/[device]`
   - EFI partition on the system: `+1G`, EFI partition, hex code `ef00`
   - 100% rest, Linux partition, Hex code `8304`
   - format EFI partition: `mkfs.vfat -F32 -n EFI /dev/[device]1`
   - `cryptsetup luksFormat /dev/[device]2`.
   - `cryptsetup luksOpen /dev/[device]2 root`
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

   ```bash
   mount -m -o umask=0077,noexec,nosuid,nodev /dev/[device]1 /mnt/boot
   ```

5. Install base system:

   - `pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs {intel|amd}-ucode sudo vim git reflector pacman-contrib networkmanager udisks2 fwupd bash-completion`
   - `genfstab -U /mnt >> /mnt/etc/fstab`
   - `arch-chroot /mnt`
   - `ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime # replace with your timezone`
   - `hwclock --systohc --utc`

   ```bash
   ---
   Set locale: uncomment desired locales from `/etc/locale.gen`.
   ---
   locale-gen
   ```

   - `echo "LANG=en_US.UTF-8" > /etc/locale.conf`

   - `export LANG=en_US.UTF-8`
   - `echo KEYMAP=de-latin1-nodeadkeys > /etc/vconsole.conf`
   - `echo "arch" > /etc/hostname # replace with your hostname`

   ```bash
   vim /etc/hosts
   ----
   127.0.0.1 <hostname>.localdomain localhost
   ::1 localhost.localdomain localhost
   ```

6. Install bootloader:

   ```bash
   bootctl --path=/boot install
   ```

7. Setup initial ramdisk:

   - configure mkinitcpio:

     ```bash
      vim /etc/mkinitcpio.conf
      ---
     HOOKS=(base systemd keyboard autodetect microcode modconf kms sd-vconsole block sd-encrypt filesystems fsck)
     ```

   - configure kernel command line:

   - `mkdir /etc/cmdline.d`

     ```bash
     vim /etc/cmdline.d/root.conf
     ---
      # Btrfs: GPT partition automount
     rootflags=subvol=@
     bgrt_disable quiet loglevel=4
     ```

     ```bash
     vim /etc/cmdline.d/performance.conf
     ---
     preempt=full threadirqs
     ```

   - Configure `.preset` for mkinitcpio (UKI).

     ```bash
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

   - `pacman -S libfido2`
   - `systemd-cryptenroll /dev/[device]2 --fido2-device=auto --fido2-with-client-pin=yes --fido2-with-user-presence=yes`
   - configure /etc/crypttab.initramfs

     ```bash
     vim /etc/crypttab.initramfs
      ---
     root UUID=<blkid /dev/[device]2> none fido2-device=auto
     ```

   - `mkinitcpio -P`

10. Enrolling recovery key:

    - `systemd-cryptenroll /dev/[device]2 --recovery-key`
    - `systemd-cryptenroll /dev/[device]2 --wipe-slot=SLOT` # replace SLOT with the slot of the original password

11. Create user

     ```bash
     useradd -mG wheel,storage,power,log,adm,uucp,tss,rfkill -s /bin/bash <username> # replace with your username
    
     passwd <username>
     ```

12. sudo

    - set vim editor for visudo

      ```bash
      vim /etc/sudoers
      ---
      Defaults editor=/usr/bin/vim
      ```

    - allow group wheel to run with root privileges

      ```bash
      visudo
      ---
      %wheel ALL=(ALL:ALL) ALL
      ```

13. pacman & reflector

    - Enable color and parallel downloads:

      ```bash
      sudo vim /etc/pacman.conf
      ---
      Uncomment: Color
      Uncomment: ParallelDownloads 5
      ```

    - Discard unused packages: `sudo systemctl enable paccache.timer`

    - Configure reflector

      ```bash
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

      ```bash
      systemctl enable reflector.timer
      ```

14. Improving compile times - makepkg

    - Parallel compilation

      ```bash
      vim /etc/makepkg.conf
      ---
      MAKEFLAGS="-j$(nproc --ignore=2)" # 2 less than total threads
      OPTIONS=(... !debug ...)
      ```

15. Install yay

     ```bash
     cd /tmp
     git clone https://aur.archlinux.org/yay.git
     cd yay
     makepkg -si
     ```

16. Installing xfce

    - `pacman -S lightdm lightdm-gtk-greater lightdm-gtk-greater-settings xorg-server nvidia nvidia-utils xfce4 network-manager-applet xfce4-whiskermenu-plugin xfce4-clipman-plugin xfce4-goodies file-roller`
    - `systemctl enable lightdm.service`
    - `sudo localectl --no-convert set-x11-keymap de pc105 nodeadkeys`

17. Configure timesyncd

    ```bash
    sudo vim /etc/systemd/timesyncd.conf
    ---
    edit NTP=
    Comment out FallbackNTP
    ---
    yay -S networkmanager-dispatcher-timesyncd
    ```

18. Swap

    - create swapfile: `sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile`
    - `sudo swapon /swap/swapfile`

     ```bash
     sudo vim /etc/fstab
     ---
     # /swap/swapfile
     /swap/swapfile none swap defaults 0 0
     ```

    - lower swappiness value:
     `echo "vm.swappiness = 10" |sudo tee /etc/sysctl.d/99-swappiness.conf`

19. Limit journal size

    ```bash
    sudo vim /etc/systemd/journald.conf
    ---
    Uncomment SystemMaxUse=200M
    ```

20. Enable periodic trim: `sudo systemctl enable fstrim.timer`

21. Install fonts: `yay -S ttf-liberation ttf-carlito noto-fonts noto-fonts-emoji adobe-source-sans-fonts adobe-source-serif-fonts acroread-fonts-systemwide ttf-inconsolata`

22. Browser: `yay -S google-chrome firefox firefox-i18n-en-us firefox-i18n-de`

23. Audio: `yay -S pipewire pipewire-audio pipewire-pulse xfce4-pulseaudio-plugin pavucontrol sof-firmware`

24. gstreamer: `yay -S gstreamer gst-plugin-pipewire gst-plugin-libcamera`

25. optical disc: `yay -S libcdio libdvdread libdvdcss libdvdnav libblueray libaacs libbdplus`

26. Setting up Epson Workforce Pro WF-4820

    ```bash
    sudo vim /etc/nsswitch.conf
    ---
    hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns
    ```

    ```bash
    yay -S cups cups-pdf system-config-printer avahi nss-mdns epson-inkjet-printerescpr2
    systemctl enable avahi-daemon.service
    systemctl start avahi-daemon.service
    systemctl enable cups
    systemctl start cups
    sudo system-config-printer
   
    ```

27. gvfs: `yay -S gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb`

28. The rest: `yay -S thunderbird tmux openssh cscope`

29. xelatex: `yay -S texlive-xetex texlive-latex texlive-latexrecommended texlive-latexextra texlive-fontsrecommended texlive-langenglish texlive-langgerman texlive-miniopro-git texlive-myriadpro-git`

30. pdf viewer: `yay -S atril evince xournalpp`
31. docbook (html, epub, pdf): `yay -S docbook-xsl docbook-xml zip epubcheck fop`
32. Updates: `yay -Syu && yay -Qtdq | yay -Rns -`
33. git aware prompt: `mkdir ~/.bash ; cd ~/.bash ; git clone https://github.com/jimeh/git-aware-prompt.git`
34. wireguard:

    ```bash
    yay -S wireguard-tools
    nmcli connection import type wireguard file <wireguard configuration file>   
    ```

35. Power Optimization with TLP:

    ```bash
    yay -S tlp tlp-rdw ethtool smartmontools
    sudo systemctl enable tlp.service
    ```

36. bluetooth:

    ```bash
    yay -S bluez bluez-utils blueman
    systemctl enable bluetooth.service
    ```

    For proton VPN connections proton advices to disable IPv6 traffic:

    ```bash
    vim /etc/sysctl.d/90-disable_ipv6.conf
    ---
    net.ipv6.conf.all.disable_ipv6 = 1
    net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1
    net.ipv6.conf.wlp0s20f3.disable_ipv6 = 1
    ```

    In addtion, to prevent DNS leaks, the DNS server used should be only the server assigned by proton VPN. Using network-manager, you can achive this like this

    ```bash
    nmcli connection modify proton-wg-is-de ipv4.dns-priority -10
    ```

    -10 is an example. The value should be negative to flush out formerly assigned DNS servers.

37. key management:

    ```bash
    yay -S gnome-keyring seahorse gcr-4
    systemctl --user enable gcr-ssh-agent.socket
    systemctl --user start gcr-ssh-agent.socket
    echo "export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh" > /etc/profile.d/ssh_auth_gcr.sh
    reboot
    ```
