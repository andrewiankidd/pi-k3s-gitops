{ pkgs, lib, ... }: {

  time.timeZone = "Europe/London";
  users.users.root.initialPassword = "todo";

  networking = {
    hostName = "pi-k3s-gitops-sd-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
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

  services = {
    # Enable k3s
    k3s = {
      enable = true;
      role = "agent";
      token = "todo-pi-k3s-gitops";
      serverAddr = "https://192.168.0.108:6443";
      extraFlags = toString [
        "--debug"
      ];
    };

    # enable pipewire for multimedia
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # ArgoCD Helm chart installation
  environment.systemPackages = with pkgs; [
    helm
  ];

  # Enable rtkit for pipewire
  security = {
    rtkit = {
      enable = true;
    };
  };

  # Install ArgoCD using Helm in Kubernetes cluster
  systemd = {
    services = {
      argo-cd = {
        description = "ArgoCD server";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${pkgs.helm}/bin/helm upgrade --install argo-cd argo/argo-cd";
        };
      };
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
