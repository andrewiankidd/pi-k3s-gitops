---
title: About
description: Master of Pippets
---

This guide covers creation of a 'master' node for the cluster. The purpose of this node is to run all essential services needed to provision new nodes.

### Explanation

We now have the ability to take a bare metal Pi with no storage and turn it into a usable machine by just plugging in a network cable.

This is good, but we're relying on an external machine (or VM) running a collection of random bash scripts and docker containers keeping this process going.

It's time to use what we've learned to build our first Kubernetes node, which will take over the responsibility of our NFS and TFTP servers, as well as other important workloads.

## Implementation

### The Plan
The bootstrap netboot process provisions a master node with read-only access to the system. This master node will run Kubernetes via K3S and then the necessary services need to provision further nodes.

### OS Selection (NixOS)

NixOS is a Linux distribution built around the Nix package manager. It provides a declarative, immutable, and reproducible approach to system configuration and package management, making it a unique choice among Linux distributions.

This means your OS configuration can be fully described and stored in Git, and can reproduced at any time. This seems ideal for my scenario, all configuration and updates will be handled via Git and the nodes are unable to drift from that configuration as they have no ability to persist any changes.

So NixOS it is, specifically [`nix-community/raspberry-pi-nix`](https://github.com/nix-community/raspberry-pi-nix) - a community project which allows you to configure NixOS for Pi in the declarative Nix interface way.

The caveat here is that NixOS is incompatible with the steps and scripts I previously wrote for netbooting Raspberry Pi OS, all the work I put in suddenly felt useless.

However, after putting on my dunce cap and spending some time learning Nix, I learned we can now make these changes at the source level instead of hacking at an SD card image.

So I took what I learned from working on Raspberry Pi OS netboot and applied it to a fork of the above repo, and after a few days of back and forward I finally got it working: [`andrewiankidd/raspberry-pi-nix`](https://github.com/andrewiankidd/raspberry-pi-nix).

So now I can generate NixOS netboot images for the Pi with [`build-nix.sh`](../../../../../../src/bootstrap/netboot/scripts/build-nix.sh)

# TODO readonly fs
# TODO dependencies (k3s etc)

# Node cost
| Configuration               | Master | Slave | Cluster Storage  | Cost                   |
|-----------------------------|--------|-------|------------------|------------------------|
| Pi + SD + NVMe + PoE        |  ✅   |  ❌   |  ✅              | £80+£5+£15+£22 = £122 |
| Pi + SD + NVMe              |  ✅   |  ❌   |  ✅              | £80+£5+£15 = £100     |
| Pi + SD + PoE               |  ✅   |  ❌   |  ❌              | £80+£5+£22 = £107     |
| Pi + SD                     |  ✅   |  ❌   |  ❌              | £80+£5 = £85          |
| Pi + NVMe + PoE             |  ❌   |  ✅   |  ✅              | £80+£15+£22 = £117    |
| Pi + NVMe                   |  ❌   |  ✅   |  ✅              | £80+£15 = £95         |
| Pi + PoE                    |  ❌   |  ✅   |  ❌              | £80+£22 = £102        |
| Pi                          |  ❌   |  ✅   |  ❌              | £80                   |
