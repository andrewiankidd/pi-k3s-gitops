---
title: 'Serving NixOS Netboot'
description: Nix(t) level stuff, I do declare
---

This guide covers explanation and implementation of creating a customizable and netboot capable NixOS build for Raspberry Pi

## Explanation

RaspiOS was not the intended platform for my cluster, I originally intended on using something immutable and declarative like [NixOS](https://nixos.org/) - However at the beginning of this project I did not have any experience at all with netboot or Nix and didn't want to set the bar too high.

Now it's time to face the inevitable 😅.

### About NixOS

NixOS is a Linux distribution built around the [Nix package manager](https://nixos.org/guides/how-nix-works/). It provides a declarative, immutable, and reproducible approach to system configuration and package management.

This means your OS configuration can be fully described in text and can be reproduced at any time.

The true selling point of this is you can you can now configure your entire OS entirely using GitOps - NixOS simplifies system management with atomic upgrades and rollbacks, eliminating configuration drift and making system state predictable and fully reproducible.

### Components
- **Nix (Package Manager)**
    - Nix: A package manager that ensures reproducible builds and declarative system configurations.
- **NixOS**
    - NixOS: A declarative, and reproducible Linux distribution for complete system configuration control.
- **Raspberry Pi Nix**
    - Declaratively configure, create and build NixOS SD Images for Raspberry Pi devices.
- **Raspberry Pi Nix (Netboot fork)**
    - Adds build configuration to flake that is preconfigured for netboot

## Implementation

### Obtaining the Boot + OS files

NixOS doesn't use a traditional filesystem so the `cmdline.txt` and `fstab` hacks we made for RaspiOS won't work here.

Instead for this we'll be using the [nix-community/raspberry-pi-nix](https://github.com/nix-community/raspberry-pi-nix) project, which allows you to generate pre-configured SD card images:
> The primary goal of this flake is to make it easy to create working NixOS configurations for Raspberry Pi products.

However, since this project aims at building SD images specifically, I have a [fork available that adds support for building for netboot](https://github.com/andrewiankidd/raspberry-pi-nix/blob/master/net-image/net-image.nix).

## Running
:::tip[Requirement]
[You need Nix (the package manager) installed to run these steps.](https://nixos.org/download/)
:::

First ensure Nix is updated

```
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update
```

Then install Cachix, which allows us to use projects binary cache for the build process
```
# Set up cache
echo "Installing Cachix"
nix-env -iA cachix -f https://cachix.org/api/v1/install
echo "substituters = https://cache.nixos.org" >> /etc/nix/nix.conf

echo "Enabling the binary cache"
cachix use nix-community
```

Clone the project and cd into it
```
git clone https://github.com/andrewiankidd/raspberry-pi-nix.git raspberry-pi-nix
cd raspberry-pi-nix
```

You should probably take this chance to look at [the default example configuration file](https://github.com/andrewiankidd/raspberry-pi-nix/blob/master/example/default.nix), which defines some basic settings including timezone and the root user password.

Let's go ahead and build this example configuration, the target is `.#nixosConfigurations.rpi-net-example.config.system.build.netImage'` but I've added some extra flags I've found useful:
```
# Build the filesystems
echo "Building netImage"
nix-collect-garbage
if [ -d ~/.cache ]; then
    rm -rf ~/.cache
fi
NIX_DEBUG=1
nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-net-example.config.system.build.netImage' --show-trace --print-build-logs -v
```

The process takes a while, but once complete the `boot` and `os` directories will be created:
```
$ ls result/net-image/os
nixos-net-image-24.05.20241006.ecbc1ca-aarch64-linux
$ ls result/net-image/boot
bcm2708-rpi-b-plus.dtb    bcm2710-rpi-zero-2.dtb      cmdline.txt   overlays
bcm2708-rpi-b-rev1.dtb    bcm2711-rpi-4-b.dtb         config.txt    start.elf
bcm2708-rpi-b.dtb         bcm2711-rpi-400.dtb         env-vars      start4.elf
bcm2708-rpi-cm.dtb        bcm2711-rpi-cm4-io.dtb      fixup.dat     start4cd.elf
bcm2708-rpi-zero-w.dtb    bcm2711-rpi-cm4.dtb         fixup4.dat    start4db.elf
bcm2708-rpi-zero.dtb      bcm2711-rpi-cm4s.dtb        fixup4cd.dat  start4x.elf
bcm2709-rpi-2-b.dtb       bcm2712-rpi-5-b.dtb         fixup4db.dat  start_cd.elf
bcm2709-rpi-cm2.dtb       bcm2712-rpi-cm5-cm4io.dtb   fixup4x.dat   start_db.elf
bcm2710-rpi-2-b.dtb       bcm2712-rpi-cm5-cm5io.dtb   fixup_cd.dat  start_x.elf
bcm2710-rpi-3-b-plus.dtb  bcm2712-rpi-cm5l-cm4io.dtb  fixup_db.dat  test.txt
bcm2710-rpi-3-b.dtb       bcm2712-rpi-cm5l-cm5io.dtb  fixup_x.dat
bcm2710-rpi-cm3.dtb       bcm2712d0-rpi-5-b.dtb       initrd
bcm2710-rpi-zero-2-w.dtb  bootcode.bin                kernel.img
```

You'll maybe have noticed `config.txt` is in here - these are the files the Pi needs to boot, and is looking for on the TFTP server!

So all we have to do now is copy the contents over to the appropriate locations - to potentially support multiple OS's/configurations I've put my OS files in a relevantly-named subdirectory `nixos-net-image-24.05.20241006.ecbc1ca-aarch64-linux`

```
cp -r result/net-image/os/nixos-net-image-24.05.20241006.ecbc1ca-aarch64-linux ../src/bootstrap/netboot/os/nixos-net-image-24.05.20241006.ecbc1ca-aarch64-linux
cp -r result/net-image/boot ../src/bootstrap/netboot/boot
```

🥳 We now have the files we need!

### Modifying the Bootloader & OS to use NFS

When configuring RaspiOS, we had to use bash commands to hack at the extracted `cmdline.txt` and `/etc/fstab` files to configure NFS mounting.

However since our NixOS build is fully declarative, we have already configured this in ahead of the build.

So if we peek into `cmdline.txt`, we can see it's already configured to boot to the OS:
```
$ ls result/net-image/boot/cmdline.txt
ro nfsroot=192.168.0.108:/mnt/nfsshare/nixos-net-image-24.05.20241006.ecbc1ca-aarch64-linux,v3 root=/dev/nfs rootwait elevator=deadline systemd.debug_shell=1 systemd.log_level=info disable_splash earlyprintk=serial,ttyS0,115200 initcall_debug printk.time=1 console=tty1 console=serial0,115200n8 init=/sbin/init loglevel=8
```

### Unattended Installation

Again, at this stage with RaspiOS we had to use custom bash scripts and filesystem manipulation to generate automate OS setup and installation.

With NixOS, we have already defined our system settings in [the aforementioned default example configuration file](https://github.com/andrewiankidd/raspberry-pi-nix/blob/master/example/default.nix)

However, that doesn't mean you need to fork the repo to have your own settings, I keep my custom `default.nix` file in this repo, which I can copy before running `nix-build`:
 - [`src/bootstrap/netboot/assets/nixos/net/default.nix`](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/assets/nixos/net/default.nix)

For example, say I want to have a different set of services for Pi's running from NFS, compared to Pi's running from SD, USB or NVME, I could simply copy the custom configuration, replacing the original before building:
```
NIX_DEBUG=1
NIX_CONFIG_DIR=./example/
SRC_CONFIG_DIR=assets/nixos/net
nix-shell -p rsync --run "rsync -xarvv --inplace --progress $SRC_CONFIG_DIR/* $NIX_CONFIG_DIR/"
nix build --repair --option substitute true --option fallback false --system aarch64-linux --extra-experimental-features "nix-command flakes" '.#nixosConfigurations.rpi-net-example.config.system.build.netImage' --show-trace --print-build-logs -v
```

## Result
Now, with the files copied to the NFS and TFTP server, let's try turning on the Pi...

<video controls width="100%" title="NixOs Boot">
    <source src="/pi-k3s-gitops/assets/docs/guides/bootstrap/prep/nixos-boot.mp4" type="video/mp4">
    Your browser does not support the video tag.
</video>

## Automation

And yes, I've automated this process too. Originally I tried to avoid forking the `raspberry-pi-nix` as I'm totally new to Nix, but after realizing it needed to happen I created equivalent automation to the previous RaspiOS ones ⚡

Within the pi-k3s-gitops repo, I've created a ['nixos-builder' service](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/docker-compose.yml), as well as a Bash script called [build-nixos.sh](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/scripts/build-nixos.sh) that tries to do all this automatically.

When I run `docker compose --profile nixos up` the nixos-builder is fired up. It will then download the repo, build it, patch in any assets and export the files.

See [Bootstrap Automation](../../../reference/bootstrap-automation) for more information

## Next Steps

If you came here to learn more about booting a Raspberry Pi over the network, then I hope this helped.

That requirement is now fulfilled, however for my needs there is much more to do 🤠