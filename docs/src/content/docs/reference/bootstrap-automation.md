---
title: '[WIP] Bootstrap Automation'
description: TODO
---

## I want to bootstrap from the network
1. Pick an unused IP in your network (ie `192.168.108`)
2. Set Option 66 on your DHCP server to the IP
3. Update `src\bootstrap\netboot\.env`
   1. Set the IP Address
   2. Set the COMPOSE_PROFILE
4. Open a CLI and CD to src\bootstrap\netboot
5. Follow the 'Running' steps in `vm/README.md`[`vm/README.md`](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/vm/README.md)

## I want to bootstrap from USB

## I want to bootstrap from NVMe

## I want to bootstrap from an SD card