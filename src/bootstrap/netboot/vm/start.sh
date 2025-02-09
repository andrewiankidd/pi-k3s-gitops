#!/bin/bash

echo "====================="
echo "start.sh"
echo "====================="
uname -a

#############################
#        script vars        #
#############################

# options
VM_OS=${VM_OS:-"22.04"}
VM_NAME=${VM_NAME:-"ubuntu-vm"}
VM_CPUS=${VM_CPUS:-"4"}
VM_MEMORY=${VM_MEMORY:-"4G"}
VM_DISK=${VM_DISK:-"30G"}
VM_REBUILD=${VM_REBUILD:-false}

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

# source .env
if [ -f "$PARENT_DIR/.env" ]; then
    export ENV_FILE="$PARENT_DIR/.env"
    echo "Sourcing $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "No .env file found."
    ls -la $PARENT_DIR
    exit 1
fi

# Set the default bridged network for created VMs
NETWORK_NAME=$(multipass networks | grep -v 'switch' | awk 'NR > 1 {print $1}' | head -n 1)
echo "Setting default bridged network to '$NETWORK_NAME'..."
multipass set local.bridged-network="$NETWORK_NAME"
if [ $? -ne 0 ]; then
    echo "Failed to set bridged network."
    exit 1
fi

# check if we need to create vm
echo "checking for existing VM '$VM_NAME'..."
VM_EXISTS=$(multipass list | grep -q "^$VM_NAME\s" && echo true || echo false)

# if vm doesn't exist or VM_REBUILD is true
# create vm
if [ "$VM_EXISTS" = false ] || [ "$VM_REBUILD" = true ]; then

    # if rebuild then delete existing
    if [ "$VM_EXISTS" = true -a "$VM_REBUILD" = true ]; then
        echo "[VM_REBUILD] Deleting existing VM..."
        multipass delete $VM_NAME --purge
        if [ $? -ne 0 ]; then
            echo "Failed to delete VM."
            exit 1
        fi
    fi

    # Create VM using Multipass
    echo "Creating new VM '$VM_NAME' with the following settings:"
    echo "CPUs: $VM_CPUS, Memory: $VM_MEMORY, Disk: $VM_DISK"
    multipass launch $VM_OS --name $VM_NAME --cpus $VM_CPUS --memory $VM_MEMORY --disk $VM_DISK --bridged --cloud-init $SCRIPT_DIR/cloud-config.yaml
    if [ $? -ne 0 ]; then
        echo "Failed to create VM. Please ensure Multipass is installed and running."
        exit 1
    fi
fi

# enable privileged mounts
if [[ "$OS" == "Windows_NT" ]]; then
    CURRENT_SETTING=$(multipass get local.privileged-mounts)
    if [[ "$CURRENT_SETTING" != "true" ]]; then
        echo "Enabling privileged mounts for Windows..."
        multipass set local.privileged-mounts=true
    fi
fi

# Mount the parent directory to the VM if not already mounted
# FYI Multipass mounts seem to be broken so I would avoid using them
# echo "Checking if parent directory '$PARENT_DIR' is already mounted to VM '$VM_NAME'..."
# MOUNT_PATH="/home/ubuntu/netboot"
# MOUNT_STR="$VM_NAME:$MOUNT_PATH"
# if ! multipass info "$VM_NAME" | grep -q "$PARENT_DIR_NAME => $MOUNT_PATH"; then
#     echo "Mounting parent directory '$PARENT_DIR' to VM '$VM_NAME'..."
#     MOUNT_OUTPUT=$(multipass mount "$PARENT_DIR" "$MOUNT_STR")
#     if [[ $? -eq 0 ]] || [[ "$MOUNT_OUTPUT" == *"is already mounted"* ]]; then
#         echo "Parent directory mounted successfully to '$MOUNT_STR'"
#     else
#         echo "Failed to mount '$MOUNT_STR'"
#         exit 1
#     fi
# else
#     echo "Parent directory '$PARENT_DIR' is already mounted to VM '$VM_NAME'"
# fi


# Copy files to the VM
SOURCE_PATH="."
MOUNT_PATH="/home/ubuntu/netboot"
# CLR_CMD="multipass exec $VM_NAME -- rm -rf '$MOUNT_PATH'"
# echo "Executing: $CLR_CMD"
# eval $CLR_CMD
COPY_CMD="multipass transfer -v -r '$SOURCE_PATH' '$VM_NAME:$MOUNT_PATH'"
echo "Executing: $COPY_CMD"
eval $COPY_CMD
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "Failed to copy files to VM. ($EXIT_CODE)"
    exit 1
fi

# check can access internet
echo "checking network"
multipass exec "$VM_NAME" -- ping -c 1 1.1.1.1
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "Failed to set up networking inside the VM ($EXIT_CODE)"
    exit 1
fi

# Execute the init.sh script inside the VM
echo "Starting docker configuration on VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- bash -c "chmod +x //home/ubuntu/netboot/vm/init/docker.sh"
multipass exec "$VM_NAME" --working-directory //home/ubuntu/netboot -- bash //home/ubuntu/netboot/vm/init/docker.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "docker.sh executed successfully inside the VM"
else
    echo "Failed to execute docker.sh inside the VM ( $EXIT_CODE )"
    exit 1
fi

echo "Mounting TFTP share for testing..."
multipass exec "$VM_NAME" --working-directory //home/ubuntu/netboot -- bash //home/ubuntu/netboot/vm/init/mount-tftp.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "mount-tftp.sh executed successfully inside the VM"
else
    echo "Failed to execute mount-tftp.sh inside the VM ($EXIT_CODE)"
    exit 1
fi

echo "Mounting NFS share for testing..."
multipass exec "$VM_NAME" --working-directory //home/ubuntu/netboot -- bash //home/ubuntu/netboot/vm/init/mount-nfs.sh
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "mount-nfs.sh executed successfully inside the VM"
else
    echo "Failed to execute mount-nfs.sh inside the VM ($EXIT_CODE)"
    exit 1
fi

# print docker logs
multipass exec $VM_NAME --working-directory //home/ubuntu/netboot -- docker compose --profile $COMPOSE_PROFILE logs --follow --tail 100
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "Failed to get docker logs inside the VM ($EXIT_CODE)"
fi

multipass shell $VM_NAME