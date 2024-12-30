#!/bin/bash

echo "====================="
echo "start.sh"
echo "====================="
uname -a

#############################
#        script vars        #
#############################

# options
VM_OS=22.04
VM_NAME="ubuntu-vm"
VM_CPUS=4
VM_MEMORY="4G"
VM_DISK="30G"
VM_REBUILD=true

# Get the parent directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR_NAME="$(basename $PARENT_DIR)"

##############################
#        script body         #
##############################

# Check if multipass is installed
if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Exiting script."
    exit 1
fi

# Set the default bridged network for created VMs
NETWORK_NAME=$(multipass networks | grep -v 'switch' | awk 'NR > 1 {print $1}' | head -n 1)
multipass set local.bridged-network="$NETWORK_NAME"

# check if we need to create vm
VM_EXISTS=$(multipass list | grep -q "^$VM_NAME\s" && echo true || echo false)
if [ "$VM_REBUILD" = true ] || [ "$VM_EXISTS" = false ]; then
    if [ "$VM_REBUILD" = true ]; then
        echo "[VM_REBUILD] Deleting existing VM..."
        multipass delete $VM_NAME
        multipass purge
    fi

    echo "Creating new VM '$VM_NAME' with the following settings:"
    echo "CPUs: $VM_CPUS, Memory: $VM_MEMORY, Disk: $VM_DISK"

    # Create VM using Multipass
    multipass launch $VM_OS --name $VM_NAME --cpus $VM_CPUS --memory $VM_MEMORY --disk $VM_DISK --bridged
    if [ $? -ne 0 ]; then
        echo "Failed to create VM. Please ensure Multipass is installed and running."
        exit 1
    fi
fi

# enable privileged mounts
if [[ "$OS" == "Windows_NT" ]]; then
    multipass set local.privileged-mounts=true
fi

# Mount the parent directory to the VM if not already mounted
echo "Checking if parent directory '$PARENT_DIR' is already mounted to VM '$VM_NAME'..."
MOUNT_PATH="/home/ubuntu/netboot"
MOUNT_STR="$VM_NAME:$MOUNT_PATH"
if ! multipass info "$VM_NAME" | grep -q "$PARENT_DIR_NAME => $MOUNT_PATH"; then
    echo "Mounting parent directory '$PARENT_DIR' to VM '$VM_NAME'..."
    MOUNT_OUTPUT=$(multipass mount "$PARENT_DIR" "$MOUNT_STR")
    if [[ $? -eq 0 ]] || [[ "$MOUNT_OUTPUT" == *"is already mounted"* ]]; then
        echo "Parent directory mounted successfully to '$MOUNT_STR'"
    else
        echo "Failed to mount '$MOUNT_STR'"
        exit 1
    fi
else
    echo "Parent directory '$PARENT_DIR' is already mounted to VM '$VM_NAME'"
fi

# Execute the net.sh script inside the VM
echo "Applying network configuration on VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- bash -c "chmod +x //home/ubuntu/netboot/vm/init/net.sh"
timeout 10 multipass exec "$VM_NAME" -- bash //home/ubuntu/netboot/vm/init/net.sh
multipass restart $VM_NAME

# Display VM information
multipass info $VM_NAME

# Execute the init.sh script inside the VM
echo "Starting docker configuration on VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- bash -c "chmod +x //home/ubuntu/netboot/vm/init/docker.sh"
multipass exec "$VM_NAME" -- bash //home/ubuntu/netboot/vm/init/docker.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "docker.sh executed successfully inside the VM"
else
    echo "Failed to execute docker.sh inside the VM ( $EXIT_CODE )"
    exit 1
fi

echo "Mounting TFTP share for testing..."
multipass exec "$VM_NAME" -- bash //home/ubuntu/netboot/vm/init/mount-tftp.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "mount-tftp.sh executed successfully inside the VM"
else
    echo "Failed to execute mount-tftp.sh inside the VM ($EXIT_CODE)"
    exit 1
fi

echo "Mounting NFS share for testing..."
multipass exec "$VM_NAME" -- bash //home/ubuntu/netboot/vm/init/mount-nfs.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "mount-nfs.sh executed successfully inside the VM"
else
    echo "Failed to execute mount-nfs.sh inside the VM ($EXIT_CODE)"
    exit 1
fi

sudo docker compose logs --follow --tail 100
multipass shell $VM_NAME