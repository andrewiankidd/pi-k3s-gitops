#!/bin/sh
set -e

sudo docker compose down
sudo docker volume prune -a
sudo losetup -D
sudo docker compose up