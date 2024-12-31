#!/bin/sh
set -e
uname -a

nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update

# Set up cache
echo "Installing Cachix"
nix-env -iA cachix -f https://cachix.org/api/v1/install
echo "substituters = https://cache.nixos.org" >> /etc/nix/nix.conf

echo "Enabling the binary cache"
cachix use nix-community

# Clone nix-community/raspberry-pi-nix repository
REPO_URL="https://github.com/andrewiankidd/raspberry-pi-nix.git"
REPO_BRANCH="feat/netboot"
DIR_NAME="raspberry-pi-nix"
echo "Cloning $REPO_URL into $DIR_NAME"
if [ -d "$DIR_NAME" ]; then
    echo "$DIR_NAME already exists. Pulling latest changes..."
    cd "$DIR_NAME"
    # git pull origin $REPO_BRANCH
else
    echo "$DIR_NAME does not exist. Cloning repository..."
    git clone -b $REPO_BRANCH "$REPO_URL" "$DIR_NAME"
    cd "$DIR_NAME"
fi

# Build the sd card image
echo "Building netImage"
NIX_DEBUG=1
nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-example.config.system.build.netImage' --show-trace --print-build-logs -v

echo "Build complete."

# export to volume
echo "boot files"
ls -l result/net-image/boot
echo "Copying netImage boot files to /mnt/netboot/boot/"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress result/net-image/boot/* /mnt/netboot/boot/"

echo "os files"
ls -l result/net-image/nixos*/*-root-fs/*
echo "Copying netImage os files to /mnt/netboot/nixos*/*-root-fs/*"
nix-shell -p rsync --run "rsync -xarvv --inplace --progress result/net-image/nixos*/*-root-fs/* /mnt/netboot/os/"

# # mark as completed (container health check)
# LOCK_FILE="/mnt/netboot/.nix_ready"
# touch $LOCK_FILE
# echo "Done!"

# # Wait for the builder to complete (it will delete the lock file)
# while [ -f $LOCK_FILE ]; do
#     echo "Waiting for builder to complete..."
#     sleep 10
# done