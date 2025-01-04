#!/bin/sh
set -e

#############################
#        script params      #
#############################

REPO_URL="${REPO_URL:-https://github.com/andrewiankidd/raspberry-pi-nix.git}"
REPO_BRANCH="${REPO_BRANCH:-feat/netboot}"
DIR_NAME="raspberry-pi-nix"

#############################
#        script vars        #
#############################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# build vars
ASSETS_DIRECTORY=$SCRIPT_PARENT_DIR/assets/nixos

# export vars
BOOT_EXPORT_DIRECTORY=./boot
OS_EXPORT_DIRECTORY=./os

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

# Clone nix-community/raspberry-pi-nix repository
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
NIX_CONFIG_DIR=./example/
echo "Copying assets from '$ASSETS_DIRECTORY' to '$NIX_CONFIG_DIR/'"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $ASSETS_DIRECTORY/ $NIX_CONFIG_DIR/"

# Build the sd card image
echo "Building netImage"
NIX_DEBUG=1
nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-net-example.config.system.build.netImage' --show-trace --print-build-logs -v
OS_OUTPUT_DIR=result/net-image/os/*
BOOT_OUTPUT_DIR=result/net-image/boot/*
echo "Build complete."

# # copying assets
# echo "Copying assets from '$ASSETS_DIRECTORY' to '$OS_OUTPUT_DIR/'"
# find $ASSETS_DIRECTORY -type f -name "*.sh" -exec chmod +x {} +;
# rsync -xar --inplace --progress $ASSETS_DIRECTORY/ $OS_OUTPUT_DIR/

# export to volume
echo "Copying netImage boot files to /mnt/netboot/$BOOT_EXPORT_DIRECTORY/"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $BOOT_OUTPUT_DIR /mnt/netboot/$BOOT_EXPORT_DIRECTORY/"

# export to volume
echo "Copying netImage os files to /mnt/netboot/$OS_EXPORT_DIRECTORY/"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $OS_OUTPUT_DIR /mnt/netboot/$OS_EXPORT_DIRECTORY/"