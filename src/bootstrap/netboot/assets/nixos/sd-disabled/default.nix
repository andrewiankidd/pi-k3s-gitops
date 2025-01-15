{ config, pkgs, ... }:

let
  # Define shared variables
  k3sServerAddr = "https://192.168.0.108:6443";
  k3sToken = "todo-pi-k3s-gitops";

  # Run a command to check if the cluster exists
  clusterStatus = pkgs.runCommand "check-k3s-cluster" {} ''
    serverAddr="${k3sServerAddr}"
    token="${k3sToken}"

    # Check if the Kubernetes API is reachable
    if curl -sfk -H "Authorization: Bearer $token" "$serverAddr/healthz" > /dev/null 2>&1; then
      echo "exists" > $out
    else
      echo "not-exists" > $out
    fi
  '';
in
{
  # System configuration
  time.timeZone = "Europe/London";
  users.users.root.initialPassword = "todo";

  environment.systemPackages = with pkgs; [
    helm
    openiscsi
  ];

  services = {

    # Enable Multi-Node k3s
    k3s = {
        enable = true;
        role = "server";
        token = k3sToken;
        clusterInit = builtins.readFile clusterStatus == "not-exists";
        serverAddr = k3sServerAddr;
        extraFlags = toString [
            "--debug"
        ];
    };

    # Enable SSH login for root
    openssh = {
        enable = true;
        ports = [
            22
        ];
        settings = {
            PasswordAuthentication = true;
            AllowUsers = [
                "root"
            ];
            UseDns = true;
            X11Forwarding = false;
            PermitRootLogin = "yes";
        };
    };

    # Fail2ban is highly recommended as a base standard of security.
    fail2ban = {
        enable = true;
    };

    # Enable open-iscsi service for Longhorn
    openiscsi = {
      enable = true;
      name = "open-iscsi";
    };

    # enable pipewire for multimedia
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

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
        # SSH
        22

        # Kubernetes API Server
        6443

        # NFSv3
        111
        2049
        32765
        32766
        32767
        32768
      ];
      allowedUDPPorts = [
        # Flannel
        8472

        # TFTP
        69

        # NFSv3
        111
        2049
        32765
        32766
        32767
        32768
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
