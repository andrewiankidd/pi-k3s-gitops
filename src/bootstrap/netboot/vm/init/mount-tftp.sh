#!/bin/bash

echo "====================="
echo "mount-tftp.sh"
echo "====================="
uname -a
lsb_release -a

# TFTP server and configuration
TFTP_SERVER="localhost"
TFTP_DIR="/tftpboot"
TFTP_MOUNT_POINT="/mnt/tftp"  # Mount point for TFTP
TFTP_FSTAB_ENTRY="${TFTP_SERVER}:${TFTP_DIR} ${TFTP_MOUNT_POINT} tftp mode=udp,nolock 0 0"

# Install TFTP client
sudo apt-get update && sudo apt-get install -y tftp-hpa

# Create the mount point if it doesn't exist
if [ ! -d "${TFTP_MOUNT_POINT}" ]; then
  echo "Creating directory for TFTP at ${TFTP_MOUNT_POINT}..."
  sudo mkdir -p "${TFTP_MOUNT_POINT}"
fi

# Check if the entry already exists in /etc/fstab (this is purely for reference, as TFTP doesn't actually mount like NFS)
if ! grep -q "${TFTP_SERVER}:${TFTP_DIR}" /etc/fstab; then
  echo "Adding entry to /etc/fstab (for reference only)..."
  echo "${TFTP_FSTAB_ENTRY}" | sudo tee -a /etc/fstab > /dev/null
else
  echo "Entry already exists in /etc/fstab."
fi

# Use TFTP client to fetch a file as a test
echo "Testing TFTP connection..."
tftp -v ${TFTP_SERVER} -c get cmdline.txt -o ${TFTP_MOUNT_POINT}/cmdline.txt

# Check if the TFTP operation was successful and the file is not empty
if [ -f "${TFTP_MOUNT_POINT}/cmdline.txt" ] && [ -s "${TFTP_MOUNT_POINT}/cmdline.txt" ]; then
    echo "TFTP file transfer successful, file saved to ${TFTP_MOUNT_POINT}/cmdline.txt."
    cat "${TFTP_MOUNT_POINT}/cmdline.txt"
else
    echo "Failed to transfer file from TFTP server or the file is empty. Please check the configuration."
fi