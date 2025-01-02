# About

This directory contains a Docker Compose project designed to run TFTP and NFS servers for the purpose of booting Raspberry Pi devices and other systems from the network. 

Additionally, it includes optional 'builder' services to generate the necessary files for a desired OS on these servers. 

## Running
**Warning: If you are using Windows, you must use a VM.**

### Running in a VM
It is recommended to use the VM, it's reproducable via the provided scripts and pre-configured with all dependencies.

You can also make use of VMs to switch between different configurations.

See [vm/README.md](vm/README.md)

#### Running natively

To run the services natively on your system, simply use Docker Compose:

```sh
sudo docker compose --profile raspios up
```

## Directory Structure

- **assets/**: Files that will be copied to the server
  - **boot/**: Contains an OS configuration script `apply-config.sh` script and a configuration example file.
- **scripts/**: Contains scripts for building and preparing images.
  - `build-image.sh`: Script to download, extract, and prepare OS images for netboot.
  - `build-nix.sh`: Script to build a NixOS image.
- **vm/**: Contains scripts and configurations for setting up a virtual machine using Multipass.
  - `init/`: Initialization scripts for the VM.
    - `docker.sh`: Installs Docker and Docker Compose, and sets up the environment.
    - `mount-nfs.sh`: Mounts the NFS share to the VM to confirm it's working.
    - `mount-tftp.sh`: Mounts the TFTP share to the VM to confirm it's working.
    - `net.sh`: Configures network settings (TODO cloud-init).
  - `start.sh`: Script to start and configure the VM using Multipass.
  - `README.md`: Documentation for setting up and running the VM.