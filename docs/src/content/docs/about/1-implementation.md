---
title: Project Implementation
description: How it's done
draft: true
---

In reality I have no idea what I'm doing here, so I'll be figuring it out as I go along.

## Software



My primary concern with having multiple physical nodes is managing them, for example
 - Keeping them updated
 - Keeping them consistent with each other / preventing drift
 - Keeping data safe
 - Networking issues
 - Hardware failure

The list could go on forever really. I needed a way to theoretically (but never actually) unlimited devices in a consistent and supported way.

I know I want to run Kubernetes first, in the past I have defaulted to ProxMox and at best ran rancher/portainer/etc in VMs - this time I wanted to go bare-metal Kubernetes.

So originally I looked at running [Talos](https://talos.dev), which is an immutable (read-only) OS created for exactly that purpose, but I [found it doesn't yet support Pi 5](https://github.com/siderolabs/talos/discussions/7821).

This was a bit of a blessing in disguise, as truthfully I wanted to start experimenting with NixOS and was putting it off, but now I had no choice.

NixOS lets you define your entire system in a single configuration file, every aspect from which packages you have installed, your timezone, services, drivers and user accounts. With NixOS I can create real reproducible OS images that


## Hardware
TODO

### Nodes
I want the machines running in the cluster to:
 - Be compact
 - Be rack mountable
 - Support SSD storage (NVMe)
 - Support Power over Ethernet (PoE)

This would allow me to add new nodes to the cluster by simply placing them in the rack and adding a patch cable.

Many different types of machine can fill this gap, but because I'm extremely boring and predictable I made a questionable choice and decided to use some Raspberry Pi 5's - which don't.

In order to get NVMe and PoE support, you have to then pick up a additional "HATs" (Hardware Attached on Top), add-on circuits that sit on on top of the Pi and connect to it's GPIO headers.

This alone is enough to make the Pi not an option for a lot people, for a lesser price point you can get alternative SBCs (Single Board Computers) with these features, or even traditional x86 Mini-PCs with these features and superior power.

But for now I've committed and the Pi 5 it is.

![alt text](../../../assets/docs/about/node.png)

### Power Management

Switch/ UPS TODO