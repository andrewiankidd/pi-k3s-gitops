#!/bin/sh
set -e

docker compose down
docker volume prune -a
losetup -D
docker compose up