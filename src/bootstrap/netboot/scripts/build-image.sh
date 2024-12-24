#!/bin/sh
set -e

#############################
#     environment params    #
#############################

CLEAN_BOOT_FILES=${CLEAN_BOOT_FILES:=""}
DOWNLOAD_LINK=${DOWNLOAD_LINK:="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-11-raspios-bookworm-arm64-lite.img.xz"}

#############################
#        script vars        #
#############################

# change working directory to netboot directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PARENT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$SCRIPT_PARENT_DIR"

# download vars
DOWNLOAD_FILE=$(basename "$DOWNLOAD_LINK")
DOWNLOAD_DIRECTORY=./download

# build vars
ASSETS_DIRECTORY=./assets
EXTRACT_DIRECTORY=$DOWNLOAD_DIRECTORY/extracted
EXTRACT_FILENAME="${DOWNLOAD_FILE%.*}"

# export vars
BOOT_EXPORT_DIRECTORY=./boot
OS_EXPORT_DIRECTORY=./os

##############################
#        script body         #
##############################

# download (likely compressed) Image File
echo "Downloading '$DOWNLOAD_FILE' [$DOWNLOAD_LINK]"
wget -N $DOWNLOAD_LINK -e robots=off --no-check-certificate -P "$DOWNLOAD_DIRECTORY"

# find compressed image file
ARCHIVE_FILE=$(find $DOWNLOAD_DIRECTORY -iname "$DOWNLOAD_FILE")

# extract the compressed file if not already done
if [ ! -f "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME" ]; then

    # Attempt to handle various formats
    echo "Extracting '$ARCHIVE_FILE'"
    mkdir -p "$EXTRACT_DIRECTORY"

    if [[ "$ARCHIVE_FILE" == *.zst ]]; then
        zstd -d "$ARCHIVE_FILE" -o "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME"
    elif [[ "$ARCHIVE_FILE" == *.xz ]]; then
        unxz -f -k -c "$ARCHIVE_FILE" > "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME"
    elif [[ "$ARCHIVE_FILE" == *.tar ]]; then
        tar -xf "$ARCHIVE_FILE" -C "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME"
    elif [[ "$ARCHIVE_FILE" == *.zip ]]; then
        unzip "$ARCHIVE_FILE" -d "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME"
    elif [[ "$ARCHIVE_FILE" == *.img ]]; then
        cp "$ARCHIVE_FILE" "$EXTRACT_DIRECTORY/$EXTRACT_FILENAME"
    else
        echo "Unsupported file extension"
        exit 1
    fi

    echo "Extraction Complete!"
else
    echo "Output file '$EXTRACT_DIRECTORY/$EXTRACT_FILENAME' already exists. Decompression skipped."
fi

# find extracted IMG file
MOST_RECENT_IMG_FILE=$EXTRACT_DIRECTORY/$EXTRACT_FILENAME #$(find "$EXTRACT_DIRECTORY" -type f -name "*.img" -exec ls -t {} + | head -n 1)
IMG_FILENAME_WITH_EXTENSION=$(basename "$MOST_RECENT_IMG_FILE")
IMG_FILENAME="${IMG_FILENAME_WITH_EXTENSION%.*}"

# mount IMG file using losetup
set +e
LOOP_MOUNT_PATH=$(losetup -Pf $MOST_RECENT_IMG_FILE --show)
while [ -z "$LOOP_MOUNT_PATH" ]; do
    if [ -e "$MOST_RECENT_IMG_FILE" ]; then
        echo "File exists."
    else
        echo "File does not exist."
    fi
    LOOP_MOUNT_PATH=$(losetup -Pf $MOST_RECENT_IMG_FILE --show)
done
set -e
echo "Mounted '$MOST_RECENT_IMG_FILE' at '$LOOP_MOUNT_PATH'"

# fix for running in docker
# for whatever reason (probably permission related) losetup does not create the partition mounts
# https://github.com/RPi-Distro/pi-gen/issues/482#issuecomment-1676103147
PARTITIONS=$(lsblk --raw --output "MAJ:MIN" --noheadings ${LOOP_MOUNT_PATH} | tail -n +2)
COUNTER=1
for i in $PARTITIONS; do
    echo "Creating node file for partition $i..."
    MAJ=$(echo $i | cut -d: -f1)
    MIN=$(echo $i | cut -d: -f2)
    if [ ! -e "${LOOP_MOUNT_PATH}p${COUNTER}" ]; then mknod ${LOOP_MOUNT_PATH}p${COUNTER} b $MAJ $MIN; fi
    COUNTER=$((COUNTER + 1))
done

# mount boot partition at desired mountpoint
BOOT_MOUNT_PATH=/mnt/tmp-img-boot
echo "Creating mountpoint '$BOOT_MOUNT_PATH'"
mkdir -p $BOOT_MOUNT_PATH
! mountpoint -q "$BOOT_MOUNT_PATH" || umount "$BOOT_MOUNT_PATH"
echo "Mounting Partiton 1 at '$BOOT_MOUNT_PATH'"
mount ${LOOP_MOUNT_PATH}p1 $BOOT_MOUNT_PATH

# copy boot files from mountpoint to export directory
if [ -n "$CLEAN_BOOT_FILES" ]; then
    echo "Warning: CLEAN_BOOT_FILES is set. Existing files will be removed."
    rm -rf $BOOT_EXPORT_DIRECTORY/*
fi
echo "Copying boot files to '$BOOT_EXPORT_DIRECTORY'"
rsync -xar --inplace --progress $BOOT_MOUNT_PATH/* $BOOT_EXPORT_DIRECTORY
umount -f -l $BOOT_MOUNT_PATH

# mount OS partition at desired mountpoint
OS_MOUNT_PATH=/mnt/tmp-img-os
echo "Creating mountpoint '$OS_MOUNT_PATH'"
mkdir -p $OS_MOUNT_PATH
! mountpoint -q "$OS_MOUNT_PATH" || umount "$OS_MOUNT_PATH"
echo "Mounting Partiton 2 at '$OS_MOUNT_PATH'"
mount ${LOOP_MOUNT_PATH}p2 $OS_MOUNT_PATH

# copy OS files from mountpoint to export directory
if [ -n "$CLEAN_OS_FILES" ]; then
    echo "Warning: CLEAN_OS_FILES is set. Existing files will be removed."
    rm -rf $OS_EXPORT_DIRECTORY/$IMG_FILENAME/*
fi
echo "Copying OS files to '$OS_EXPORT_DIRECTORY/$IMG_FILENAME'"
rsync -xar --inplace --progress $OS_MOUNT_PATH/* $OS_EXPORT_DIRECTORY/$IMG_FILENAME
umount -f -l $OS_MOUNT_PATH

# patch cmdline.txt to use NFS
echo "Patching '$BOOT_EXPORT_DIRECTORY/cmdline.txt'"
CMDLINE_CONTENTS="selinux=0 dwc_otg.lpm_enable=0 console=tty1 rootwait rw nfsroot=192.168.0.108:/mnt/nfsshare/$IMG_FILENAME,v3 ip=dhcp root=/dev/nfs elevator=deadline systemd.log_level=info systemd.log_target=console systemd.debug-shell=1 init=/boot/apply-config.sh"
echo $CMDLINE_CONTENTS > $BOOT_EXPORT_DIRECTORY/cmdline.txt

# patch /etc/fstab to use NFS
echo "Patching '$OS_EXPORT_DIRECTORY/$IMG_FILENAME/etc/fstab'"
FSTAB_CONTENTS="proc                       /proc           proc   defaults          0       0\n192.168.0.108:/mnt/nfsshare/$IMG_FILENAME/boot/firmware  /boot/firmware  nfs    defaults          0       2\n192.168.0.108:/mnt/nfsshare/$IMG_FILENAME                /               nfs    defaults,noatime  0       1"
echo -e $FSTAB_CONTENTS > $OS_EXPORT_DIRECTORY/$IMG_FILENAME/etc/fstab

# copying assets
echo "Copying assets from '$ASSETS_DIRECTORY' to '$OS_EXPORT_DIRECTORY/$IMG_FILENAME/'"
find $ASSETS_DIRECTORY -type f -name "*.sh" -exec chmod +x {} +;
rsync -xar --inplace --progress $ASSETS_DIRECTORY/ $OS_EXPORT_DIRECTORY/$IMG_FILENAME/

# # Find all .service files in the specified directory
# echo "Enabling services"
# # mkdir -p /etc/systemd/system/multi-user.target.wants/
# find "$OS_EXPORT_DIRECTORY/$IMG_FILENAME/etc/systemd/system" -type f -name '*.service' -exec bash -c '
#     # Set permissions to 644
#     echo "Marking service file $0 as executable"
#     echo "chmod 644 "$0""
#     #chmod 644 "$0"

#     # Create a symlink in /etc/systemd/system/multi-user.target.wants/
#     echo "Enabling Service via SymLink"
#     echo "ln -sf \"$0\" \"/etc/systemd/system/multi-user.target.wants/$(basename \"$0\")\""
#     ln -sf "$0" "/etc/systemd/system/multi-user.target.wants/$(basename "$0")"
# ' {} \;

# we're done 🎉
echo "Done!"