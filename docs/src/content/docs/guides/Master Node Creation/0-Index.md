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
I want to give nodes in the cluster the ability to *become* the master node.

To do this I'm going to update my customized `default.nix` file to include logic that checks if an SD card is inserted, and if so flash it with a pre-prepared image file.


# TODO readonly fs
# TODO dependencies (k3s etc)

# Automated NixOS Installation
TODO document SD flash service
Since I expect the master node to be able to reproduce the
