---
title: Resources
description: Open Source
draft: true

---

I had a lot to learn while building this cluster. Thousands of tabs were opened and closed, hundreds were re-opened over and over. Here are the few I can remember

## Core Technologies

The main tech stack that makes up the cluster

### K3s
K3s is a lightweight Kubernetes distribution designed for production workloads in resource-constrained environments. It is optimized for ARM processors and low-resource devices, making it ideal for edge computing, IoT, and small-scale deployments. K3s simplifies the Kubernetes installation process and reduces the memory and CPU footprint, while still providing the full Kubernetes API.

[K3s](https://k3s.io)

### NixOS
NixOS is a declarative, reproducible, and reliable Linux distribution. It uses the Nix package manager to ensure that system configurations are consistent and reproducible. NixOS allows users to define their entire system configuration in a single file, making it easy to roll back changes and maintain system stability. This makes it an excellent choice for both development and production environments.

[NixOS](https://nixos.org)

### Raspberry Pi
Raspberry Pi is a series of affordable, small, and versatile single-board computers. These devices are widely used in education, hobbyist projects, and industrial applications due to their low cost, ease of use, and extensive community support. Raspberry Pi boards can run a variety of operating systems and are capable of handling a wide range of tasks, from simple automation to complex computing projects.

[Raspberry Pi](https://www.raspberrypi.org)

## Hardware

This is a list of the specific hardware I'm using in my cluster, not to say others wouldn't work, YMMV.

### Pi
- [Raspberry Pi 5 8GB](https://thepihut.com/products/raspberry-pi-5?variant=42531604955331): The latest Raspberry Pi model with 8GB of RAM.
- [PoE+ NVMe HAT](https://www.amazon.co.uk/dp/B0D8J7B47N): A Power over Ethernet plus NVMe HAT for Raspberry Pi.
- [NVMe SSD](https://www.amazon.co.uk/gp/product/B0822Y6N1C/): A high-speed NVMe SSD for storage.
- [SD Card](https://www.amazon.co.uk/dp/B07R7C3PW5/): A reliable SD card for Raspberry Pi.

### Network
- [PoE Switch](https://uk.store.ui.com/uk/en/products/usw-pro-24-poe): A PoE switch for network connectivity.
- (OR) [PoE Injector](https://www.amazon.co.uk/dp/B08LQP8CYD): An alternative to the PoE switch for providing power over Ethernet.

## Software
### Operating Systems
- [NixOS](https://nixos.org): A declarative, reproducible, and reliable Linux distribution.
- [RaspiOS](https://www.raspberrypi.org/software/): The official operating system for Raspberry Pi.

### Containerization
- [Docker](https://www.docker.com): A platform for developing, shipping, and running applications in containers.
- [Multipass](https://multipass.run): A tool to launch and manage lightweight Ubuntu VMs.

### Docker Containers
- [pghalliday/tftp](https://hub.docker.com/r/pghalliday/tftp): A TFTP server container used for hosting boot files.
- [erichough/nfs-server](https://hub.docker.com/r/erichough/nfs-server): An NFS server container used for hosting OS files.

### Additional Tools
- [Helm](https://helm.sh): A package manager for Kubernetes.
- [Longhorn](https://longhorn.io): A distributed block storage system for Kubernetes.
- [ArgoCD](https://argoproj.github.io/argo-cd/): A declarative, GitOps continuous delivery tool for Kubernetes.

### Documentation Site
- [Astro](https://astro.build): A modern static site builder.
- [Starlight](https://starlight.astro.build): A theme for building documentation sites with Astro.

### Sources
- [Project Repository](https://github.com/andrewiankidd/pi-k3s-gitops): The GitHub repository for this project.
- [Starlight Starter Kit](https://github.com/withastro/starlight/tree/main/examples/basics): The GitHub repository for the Starlight Starter Kit.
- [Raspberry Pi Nix](https://github.com/nix-community/raspberry-pi-nix): Declaratively configure, create and build NixOS SD Images for Raspberry Pi devices.


## Documentation
Tutorials / Steps / Guides / Wikis / Forum Posts in no particular order

### NixOS
- [NixOS Wiki: filesystems](https://nixos.wiki/wiki/Filesystems)
- [NixOS Wiki: Pi 5](https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_5)
- [NixOS Configuration Options](https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=systemd.services)
- [GitHub Issue: NixOS: Building aarch64 installer fails due to Exec format Error #59](https://github.com/nix-community/nixos-generators/issues/59)
- [GitHub Issue: NixOS: Raspberry Pi 5 support](https://github.com/NixOS/nixpkgs/issues/260754)

### Netboot
- [PXE Booting Raspberry Pis](https://ltm56.com/pxe-booting-raspberry-pis/)
- [Raspberry Pi PXE Boot – Network booting a Pi 4 without an SD card](https://linuxhit.com/raspberry-pi-pxe-boot-netbooting-a-pi-4-without-an-sd-card/)
