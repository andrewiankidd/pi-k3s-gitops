{ pkgs, lib, ... }: {

  # System configuration
  time.timeZone = "Europe/London";
  users.users.root.initialPassword = "todo";

  # ArgoCD Helm chart installation
  environment.systemPackages = with pkgs; [
    helm
    openiscsi
  ];

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

    # Enable open-iscsi service for Longhorn
    openiscsi = {
      enable = true;
      # name = "<some-name>";
    };

    # enable pipewire for multimedia
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # Install ArgoCD using Helm in Kubernetes cluster
  systemd = {
    services = {

      # ArgoCD Server for managing Kubernetes applications
      argo-cd = {
        description = "ArgoCD server";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${pkgs.helm}/bin/helm upgrade --install argo-cd argo/argo-cd";
        };
      };
    };

    # Fix for https://github.com/longhorn/longhorn/issues/2166
    tmpfiles.rules = [
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
    ];
  };

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

  # Enable rtkit for pipewire
  security = {
    rtkit = {
      enable = true;
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
