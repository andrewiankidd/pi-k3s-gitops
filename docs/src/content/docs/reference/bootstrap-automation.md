---
title: '[WIP] Bootstrap Automation'
description: TODO
---

## About

I am a very lazy person and this drives me to automate everything. Additionally my memory is terrible and attempting to automate things not only drills it into my memory, but provides a form of practical documentation.

Like most code, it's about turning human actions into more efficient and reliable code, I guess it always has been.

With this project I aimed to automate most of it with Docker, but soon faced limitations on Windows.
So then I scripted an Ubuntu VM using Multipass, which is prepared via bash scripts to run Docker and beat those limitations.

To avoid Platform issues, I'd recommend just using the VM for bootstrapping - but all the real magic is in the Docker compose file and you can run that natively on Linux or Mac if you please.

## Automation options

### I want to bootstrap from the network

<details>
<summary>Using VM (Recommended)</summary>

1. Pick an unused IP in your network (ie `192.168.0.108`)
2. Set 'Option 66' config on your DHCP server to the selected IP
3. Update `src\bootstrap\netboot\.env`
   1. Set the `IP_ADDRESS` to the selected IP
   2. Set the `COMPOSE_PROFILE` to the desired value (`raspios`|`nixos`|`nobuild`)
4. Open a CLI and CD to `src\bootstrap\netboot`
5. Follow the 'Running' steps in [`vm/README.md`](https://github.com/andrewiankidd/pi-k3s-gitops/blob/master/src/bootstrap/netboot/vm/README.md)
</details>

<details>
<summary>Using Docker</summary>

1. Don't be on Windows
2. Have Docker installed
3. Get your local network IP (ie `192.168.0.108`)
4. Set 'Option 66' config on your DHCP server to the selected IP
5. Update `src\bootstrap\netboot\.env`
   1. Set the `IP_ADDRESS` to the selected IP
   2. Set the `COMPOSE_PROFILE` to the desired value (`raspios`|`nixos`|`nobuild`)
6. Open a CLI and CD to `src\bootstrap\netboot`
7. Run
    ```
    source .env
    docker compose --profile $COMPOSE_PROFILE up
    ```
</details>

### I want to bootstrap from USB

### I want to bootstrap from NVMe

### I want to bootstrap from an SD card