---
title: About
description: Master of muppets
---

This guide covers creation of a 'master' node for the cluster. The purpose of this node is to run all essential services needed to provision new nodes.

### Explanation

We now have the ability to take a bare metal raspberry pi with no storage and turn it into a usable machine by just plugging in a network cable.

This is good, but we're relying on an external machine (or VM) running some random bash scripts and docker containers keeping this process going.

It's time to use what we've learned to build our first Kubernetes node, which will take over the responsibility of our NFS and TFTP servers, as well as other important workloads.

## Implementation

