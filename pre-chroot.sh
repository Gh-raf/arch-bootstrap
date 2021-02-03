set -e

sdx=sda
sctr_l=$(cat /sys/block/$sdx/queue/hw_sector_size)
boot=512
swap=8192
root=30720

blk_dev=/dev/"$sdx"

cal () { awk "BEGIN{print $*}"; }
dec () { cal $* - $sctr_l; }
MiB_B () { cal $1 \* 1048576; }
mnt () { mkdir -p $2 && mount $1 $2; }

##################################
####     Pre-installation     ####
##################################

# Exit if boot mode isn't UEFI
[ -d /sys/firmware/efi ] || (printf 'Non-UEFI boot modes aren'\''t supported! Aborting' && \
				sleep 1 && printf . && sleep 1 && printf . && sleep 1 && echo .  && exit)

# Calculate disk space for each partition
boot_end=$(cal 2048 \* sctr_l + $(MiB_B $boot))
swap_end=$(cal $boot_end + $(MiB_B $swap))
root_end=$(cal $swap_end + $(MiB_B $root))

# Create and Format the partitions
parted $blk_dev mklabel gpt
parted -a optimal -s $blk_dev -- \
	 mkpart boot	fat32		2048s $(dec $boot_end)B \
	 set 1 boot on \
	 mkpart swap	linux-swap	"$boot_end"B $(dec $swap_end)B  \
	 mkpart rootfs	ext4 		"$swap_end"B $(dec $root_end)B \
	 mkpart home	ext4 		"$root_end"B -34s

mkfs.fat -F32 "$blk_dev"1
mkswap "$blk_dev"2
swapon "$blk_dev"2
mkfs.ext4 "$blk_dev"3
mkfs.ext4 "$blk_dev"4

# Mount and Setup Dirs
mnt "$blk_dev"3 /mnt
mnt "$blk_dev"1 /mnt/boot
mnt "$blk_dev"4 /mnt/home

# Install Base System
basestrap /mnt base base-devel runit elogind-runit linux linux-zen linux-firmware man-db man-pages
fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt /bin/bash post-chroot.sh
