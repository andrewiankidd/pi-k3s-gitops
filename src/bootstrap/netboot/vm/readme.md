## About
This directory contains a collection of bash scripts designed to build a reproducible Linux VM. The VM can be used to run Docker Compose on Windows hosts, enabling features that are typically not possible on Windows, such as host mode bridged networking.

## Running
The VM is managed by [multipass](https://multipass.run/docs), a cross-platform tool that allows you to create, manage, and maintain ubuntu virtual machines with ease.

### Windows
1. Install chocolatey    
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    ```
2. Install multipass:
    ```powershell
    choco install multipass
    ```
3. Run `start.sh`
    ```powershell
    .\start.sh
    ```

### Mac
1. Install homebrew    
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
2. Install multipass:
    ```bash
    brew install --cask multipass
    ```
3. Run `start.sh`
    ```bash
    ./start.sh
    ```

### Linux
1. Install snapd
    ```bash
    sudo apt update
    sudo apt install snapd
    ```
2. Install multipass:
    ```bash
    sudo snap install multipass
    ```
3. Run `start.sh`
    ```bash
    ./start.sh
    ```