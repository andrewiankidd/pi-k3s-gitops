#!/bin/sh
set -e

#############################
#        script params      #
#############################

# source config
REPO_URL="${REPO_URL:-https://github.com/andrewiankidd/raspberry-pi-nix.git}"
REPO_BRANCH="${REPO_BRANCH:-feat/netboot}"
DIR_NAME="raspberry-pi-nix"

#############################
#        script vars        #
#############################

# path vars
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# build vars
ASSETS_DIRECTORY=$SCRIPT_PARENT_DIR/assets/nixos

# export vars
BOOT_EXPORT_DIRECTORY=boot
OS_EXPORT_DIRECTORY=os

# debug vars
NIX_DEBUG=1
NIX_CONFIG_DIR=./example/

##############################
#        script body         #
##############################

nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update

# Set up cache
echo "Installing Cachix"
nix-env -iA cachix -f https://cachix.org/api/v1/install
echo "substituters = https://cache.nixos.org" >> /etc/nix/nix.conf

echo "Enabling the binary cache"
cachix use nix-community

echo "Cloning $REPO_URL into $DIR_NAME"
if [ -d "$DIR_NAME" ]; then
    echo "$DIR_NAME already exists. Pulling latest changes..."
    cd "$DIR_NAME"
    git pull origin $REPO_BRANCH
else
    echo "$DIR_NAME does not exist. Cloning repository..."
    git clone -b $REPO_BRANCH "$REPO_URL" "$DIR_NAME"
    cd "$DIR_NAME"
fi

# copying assets
SRC_CONFIG_DIR=$ASSETS_DIRECTORY/net
echo "Copying configs from '$SRC_CONFIG_DIR/' to '$NIX_CONFIG_DIR/'"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $SRC_CONFIG_DIR/* $NIX_CONFIG_DIR/"
ls -aR $NIX_CONFIG_DIR

# Build the filesystems
echo "Building netImage"
nix-collect-garbage
if [ -d ~/.cache ]; then
    rm -rf ~/.cache
fi
nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-net-example.config.system.build.netImage' --show-trace --print-build-logs -v
OS_OUTPUT_DIR=result/net-image/os/
OS_IMAGE_NAME=$(basename $(ls -td $OS_OUTPUT_DIR* | head -1))
BOOT_OUTPUT_DIR=result/net-image/boot/*
echo "Build complete."

# export to volume
echo "Copying netImage boot files to /mnt/netboot/$BOOT_EXPORT_DIRECTORY/"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $BOOT_OUTPUT_DIR /mnt/netboot/$BOOT_EXPORT_DIRECTORY/"

# export to volume
echo "Copying netImage os files to /mnt/netboot/$OS_EXPORT_DIRECTORY/"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $OS_OUTPUT_DIR/$OS_IMAGE_NAME /mnt/netboot/$OS_EXPORT_DIRECTORY/"

# If sd config exists,
# build the sd card image and copy it to the rootfs
SRC_CONFIG_DIR=$ASSETS_DIRECTORY/sd
if [ -d "$SRC_CONFIG_DIR" ]; then

    # reset the repo
    git reset --hard HEAD
    git clean -fdx

    # copying assets
    echo "Copying configs from '$SRC_CONFIG_DIR/' to '$NIX_CONFIG_DIR/'"
    nix-shell -p rsync --run "rsync -xarvv --inplace --progress $SRC_CONFIG_DIR/ $NIX_CONFIG_DIR/"

    # Build the sd card image
    echo "Building sdImage"
    nix-collect-garbage
    if [ -d ~/.cache ]; then
        rm -rf ~/.cache
    fi
    nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-example.config.system.build.sdImage' --show-trace --print-build-logs -v
    SD_OUTPUT_DIR=result/sd-image
    SD_IMAGE_NAME=$(basename $(ls -t $SD_OUTPUT_DIR/*.img.zst | head -1))
    SD_IMAGE_OUT_PATH=/boot/firmware/sd.img.zst

    echo "Copying sdImage from '$SD_OUTPUT_DIR/*' to '/mnt/netboot/$OS_EXPORT_DIRECTORY/$OS_IMAGE_NAME$SD_IMAGE_OUT_PATH'"
    nix-shell -p rsync --run "rsync -xarvv --inplace --progress $SD_OUTPUT_DIR/$SD_IMAGE_NAME /mnt/netboot/$OS_EXPORT_DIRECTORY/$OS_IMAGE_NAME$SD_IMAGE_OUT_PATH"
    if [ ! -f "/mnt/netboot/$OS_EXPORT_DIRECTORY/$OS_IMAGE_NAME$SD_IMAGE_OUT_PATH" ]; then
        echo "Error: SD image file was not copied successfully."
        echo "result"
        ls -aR $SD_OUTPUT_DIR
        echo "target"
        ls -aR /mnt/netboot/$OS_EXPORT_DIRECTORY/$OS_IMAGE_NAME/boot/firmware
        exit 1
    fi
fi