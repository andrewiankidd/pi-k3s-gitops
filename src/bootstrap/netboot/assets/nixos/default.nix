{ pkgs, lib, ... }: {
  time.timeZone = "Europe/London";
  users.users.root.initialPassword = "root";

  # Enable rtkit for pipewire
  security.rtkit.enable = true;

  services = {
    # enable pipewire for multimedia
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Enable k3s
    k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        "--debug" # Optionally add additional args to k3s
      ];
    };
  };

  networking = {
    hostName = "pi-k3s-gitops-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      eth0.useDHCP = false;
    };
    firewall = {
      allowedTCPPorts = [
        22    # SSH
        6443  # Kubernetes API Server
      ];
      allowedUDPPorts = [
        53  # DNS
        67  # DHCP
        68  # DHCP
        8472 # Flannel
      ];
    };
  };

  # hardware configuration
  raspberry-pi-nix.board = "bcm2712";
  hardware = {
    raspberry-pi = {
      config = {
        all = {
          base-dt-params = {
            BOOT_UART = {
              value = 1;
              enable = true;
            };
            uart_2ndstage = {
              value = 1;
              enable = true;
            };
          };
          dt-overlays = {
            disable-bt = {
              enable = true;
              params = { };
            };
          };
        };
      };
    };
  };
}
