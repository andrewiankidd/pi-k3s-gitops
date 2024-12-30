#!/bin/bash

echo "====================="
echo "mount-nfs.sh"
echo "====================="
uname -a
lsb_release -a

# mount vars
NFS_SERVER="localhost"
NFS_SHARE="/mnt/nfsshare"
NFS_MOUNT_POINT="/mnt/nfs"
NFS_FSTAB_ENTRY="${NFS_SERVER}:${NFS_SHARE} ${NFS_MOUNT_POINT} nfs vers=3,nolock 0 0"

# install nfs client
sudo apt-get update && sudo apt-get install -y nfs-common

# Create the mount point if it doesn't exist
if [ ! -d "${NFS_MOUNT_POINT}" ]; then
  echo "Creating mount point at ${NFS_MOUNT_POINT}..."
  sudo mkdir -p "${NFS_MOUNT_POINT}"
fi

# Check if the entry already exists in /etc/fstab
if ! grep -q "${NFS_SERVER}:${NFS_SHARE}" /etc/fstab; then
  echo "Adding entry to /etc/fstab..."
  echo "${NFS_FSTAB_ENTRY}" | sudo tee -a /etc/fstab > /dev/null
else
  echo "Entry already exists in /etc/fstab."
fi

# Mount all entries from /etc/fstab
echo "Mounting all filesystems from /etc/fstab..."
sudo mount -a

# Verify if the mount was successful
if mount | grep -q "${NFS_MOUNT_POINT}"; then
  echo "NFS share mounted successfully at ${NFS_MOUNT_POINT}."
else
  echo "Failed to mount NFS share. Please check the configuration."
  exit 1
fi
