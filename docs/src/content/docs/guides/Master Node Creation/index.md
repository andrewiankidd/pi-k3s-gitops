---
title: About
description: Master of Pi-ppets
draft: true
---

<center>
    <img
        src="/pi-k3s-gitops/_image?href=%2F%40fs%2FC%3A%2Fgit%2Fpi-k3s-gitops%2Fdocs%2Fsrc%2Fassets%2Ftodo.png"
        style="height:250px"
    >
    <h3>TODO: still a WIP</h3>
</center>

This guide covers creation of a 'master' node for the cluster. The purpose of this node is to run all essential services needed to provision new nodes.

### Explanation

We now have the ability to take a bare metal Pi with no storage and turn it into a usable machine by just plugging in a network cable.

This is good, but we're relying on an external machine (or VM) running a collection of random bash scripts and docker containers keeping this process going.

It's time to use what we've learned to build our first Kubernetes node, which will take over the responsibility of our NFS and TFTP servers, as well as other important workloads.

## Implementation

### The Plan
We want to give netboot nodes in the cluster the ability to *become* the master node in a situation where this is none, and we want it to happen without any manual intervention.

They will then take on the burden of hosting the netboot files for netboot nodes that come online afterwards.

To do this however, the node would need to (at the very least) run two servers, and without any existing servers to boot from there is just no way to do this... unless you plan in advance :)

The solution here is simple, but also something we have so far managed to avoid, adding an SD card to the Pi.

The plan is to add an SD card to at least two Pi's in the cluster, this allows them to boot without an existing Node, and when they come online they will attempt to become the new master node.

This might seem like a step backwards - all it takes is hearing the word 'SD card' and suddenly images of readers, adaptors, converters and corrupted files flash by.

But I've convinced myself it's a necessary evil, the SD is purely for OS bootstrapping incase of an outage, and I have ideas on how to do it completely automatically.

### Automating SD Flashing

To achieve this I created a second custom `default.nix` configuration file, leaving me with:
 - [`src/bootstrap/netboot/assets/nixos/net/default.nix`](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/assets/nixos/net/default.nix)
 - [`src/bootstrap/netboot/assets/nixos/sd/default.nix`](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/assets/nixos/sd/default.nix)

I then updated my `build-nix.sh` script to additionally build a NixOS SD card image if this new configuration file exists.

This allows me to tweak my system configuration depending on the boot method used, for example tweaking the hostname setting allows me to clearly tell at a glance if a node was booted via SD or Netboot:

|            net/default.nix                 |            sd/default.nix                 |
|--------------------------------------------|-------------------------------------------|
| networking.hostName = "pi-k3s-gitops-net"; | networking.hostName = "pi-k3s-gitops-sd"; |

Once the NixOS SD image is complete, it is exported to the OS filesystem on the NFS server, so it is available to the running OS at a known path of `/boot/firmware/sd.img.zst`

The last piece of the puzzle is updating the `net/default.nix` configuration file, adding a systemd service to check if an SD card is inserted, and if so flash it with the pre-prepared image.

```
systemd = {
    services = {
    # If this device has an SD card, flash OS to SD card
    # So long as there is at least one device with a flashed SD card
    # the cluster can rebuild itself
    detect-sd-and-flash-img = {
        description = "SD card snapshot";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
            Type = "oneshot";
            ExecStartPre = "${pkgs.bash}/bin/bash -c 'if ls /dev/mmcblk0 1> /dev/null 2>&1; then exit 0; else exit 1; fi'";
            ExecStart = pkgs.writeScript "detect-sd-and-flash-img" ''
                #!${pkgs.bash}/bin/bash
                set -euo pipefail

                # prepare pkgs paths
                export PATH="${pkgs.zstd}/bin:${pkgs.unixtools.wall}/bin:$PATH"

                # Flash the image and send output to the systemd journal
                {
                    echo "detect-sd-and-flash-img | SD card detected. Flashing image..."

                    # set expected path of sd image
                    SD_IMAGE_OUT_PATH=/boot/firmware/sd.img.zst
                    if [ ! -f $SD_IMAGE_OUT_PATH ]; then
                        echo "detect-sd-and-flash-img | SD image not found, skipping flash."
                        exit 0
                    fi

                    zstd -dc $SD_IMAGE_OUT_PATH | dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress 2>&1 \
                        | tee >(systemd-cat -t detect-sd-and-flash-img) | while IFS= read -r line; do
                            wall "$line"
                        done

                    echo "detect-sd-and-flash-img | Flashing complete."
                } | tee >(systemd-cat -t detect-sd-and-flash-img) | wall
            '';
        };
    };
  };
```
This means that Pi's with SD cards can now boot when there is no active Netboot server.

To prove this out, I restarted docker and allowed the nixos-builder to build my updated configuration. I then watched as the Pi booted into the Netboot NixOS, the systemd service fire up and the SD Card is flashed:

TODO SCREENSHOT HERE

Then when I rebooted the Pi and it happily booted from the SD, up and running and ready to go, without relying on the bootstrap VM anymore.

TODO SCREENSHOT HERE

### Creating Netboot server on Master Node

Progress feels good so far.

We can now take an Raspberry Pi with a blank SD card, plug it in to our network and without any further interaction it will turn itself into a fully configured and active NixOS install.

But we're **still** relying on the bootstrap VM for most of this process, we need to give master nodes the ability to fill this gap.

In order to do this I'm going to update my custom `sd/default.nix` configuration files, this time defining a kubernetes workload that reproduces our bootstrap server (NFS, TFTP and OS generation).

```
  services = {
    k3s = {
      enable = true;
      role = "agent";
      token = "todo-pi-k3s-gitops";
      serverAddr = "https://192.168.0.108:6443";
      extraFlags = toString [
        "--debug"
      ];
    };
  }

  networking = {
    hostName = "pi-k3s-gitops-sd-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
    firewall = {
      allowedTCPPorts = [
        # SSH
        22

        # Kubernetes API Server
        6443

        # NFSv3
        111
        2049
        32765-32768
      ];
      allowedUDPPorts = [
        # TFTP
        69

        # NFSv3
        111
        2049
        32765-32768
      ];
    };
  };
```

### IP Reconciliation
TODO
Nodes with SD cards should scan the network (arp? kubctl?) and detect if TFTP_IP/Option 66/192.168.0.108 exists
If the master node can not be found, then the SD card node tries to take the TFTP_IP for itself and become the new master