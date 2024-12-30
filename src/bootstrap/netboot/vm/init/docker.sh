#!/bin/bash

echo "====================="
echo "docker.sh"
echo "====================="

uname -a
lsb_release -a
ip a

sudo modprobe binfmt_misc
sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc

# install docker and docker-compose
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu

# dependencies for cross compilation
sudo apt-get install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
sudo apt-get install -y qemu-user-static

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
else
  sudo apt-get install -y git
  git clone https://github.com/andrewiankidd/pi-k3s-gitops.git /home/ubuntu/pi-k3s-gitops
  cd /home/ubuntu/pi-k3s-gitops/src/bootstrap/netboot
fi

# go
sudo docker compose up &