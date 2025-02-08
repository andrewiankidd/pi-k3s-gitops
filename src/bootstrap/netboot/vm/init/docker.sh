#!/bin/bash

echo "====================="
echo "docker.sh"
echo "====================="

uname -a
lsb_release -a
ip a

# source .env
ENV_FILE=${ENV_FILE:-"./.env"}
if [ -f "$ENV_FILE" ]; then
    echo "Sourcing $ENV_FILE file..."
    source "$ENV_FILE"
else
    echo "No $ENV_FILE found."
    exit 1
fi

# Enable support for additional binary formats
sudo modprobe binfmt_misc
sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc

# install docker and docker-compose
# sudo apt-get update -q && sudo apt-get install -yq docker.io docker-compose-v2
sudo usermod -aG docker ubuntu

# dependencies for cross compilation
# sudo apt-get install -yq gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
# sudo apt-get install -yq qemu-user-static

# stop services that interfere with our servers
sudo modprobe nfs
sudo modprobe nfsd
sudo systemctl stop rpcbind
sudo systemctl stop rpcbind.socket
sudo systemctl disable rpcbind
sudo systemctl disable rpcbind.socket
sudo systemctl mask rpcbind
sudo systemctl mask rpcbind.socket

# use mounted repo if available, otherwise clone
if [ -d "/home/ubuntu/netboot" ]; then
  cd /home/ubuntu/netboot/
# else
#   sudo apt-get install -y git
#   git clone https://github.com/andrewiankidd/pi-k3s-gitops.git /home/ubuntu/pi-k3s-gitops
#   cd /home/ubuntu/pi-k3s-gitops/src/bootstrap/netboot
fi

# firewall
sudo ufw allow 111/tcp
sudo ufw allow 111/udp
sudo ufw allow 2049/tcp
sudo ufw allow 2049/udp
sudo ufw allow 32765:32768/tcp
sudo ufw allow 32765:32768/udp
sudo ufw allow 69/tcp

# go
echo "running: docker compose --profile $COMPOSE_PROFILE up --detach"
sudo docker compose --profile $COMPOSE_PROFILE up --detach
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    exit 1
fi
sudo docker ps -a