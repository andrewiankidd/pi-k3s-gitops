{ config, pkgs, ... }:

let
  # Define shared variables
  k3sServerAddr = "https://192.168.0.108:6443";
  k3sToken = "todo-pi-k3s-gitops";
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
    k3s =
      let
        nginxChart =
          pkgs.runCommand "nginx-chart"
            {
              nativeBuildInputs = with pkgs; [
                kubernetes-helm
                cacert
              ];
              outputHashAlgo = "sha256";
              outputHash = "sha256-e4zlCaK9mioU9A0Wr2YqCxwzlnS+ssPG46ixvFVXOqk=";
            }
            ''
              export HOME="$PWD"

              helm repo add repository https://charts.bitnami.com/bitnami
              helm pull repository/nginx --version 18.3.5
              mv ./*.tgz $out
            '';
      in
      {
      enable = true;
      role = "server";
      environmentFile = "/etc/k3s/cluster-config.env";
      extraFlags = toString [
        "--debug"
      ];
      charts.bitnamiNginx = nginxChart;
      manifests.nginx.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata = {
          name = "nginx";
          namespace = "kube-system";
        };
        spec = {
          targetNamespace = "test";
          createNamespace = true;
          # the chart name (bitnamiNginx) has to match the key that is used in services.k3s.charts
          chart = "https://%{KUBERNETES_API}%/static/charts/bitnamiNginx.tgz";
          valuesContent = ''
            replicaCount: 3
            tls:
              enabled: false
            metrics:
              enabled: true
          '';
        };
      };
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

      k3s-check-cluster = {
        description = "Check K3s cluster state and configure K3s";
        wantedBy = [ "multi-user.target" ];
        before = [ "k3s.service" ]; # Ensure this runs before K3s starts
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'mkdir -p /etc/k3s'";
          ExecStart = pkgs.writeScript "k3s-check-cluster" ''
            #!${pkgs.bash}/bin/bash
            set -euo pipefail

            # output file
            configFile="/etc/k3s/cluster-config.env"
            echo "K3S_URL=${k3sServerAddr}" >> "$configFile"
            echo "K3S_TOKEN=${k3sToken}" >> "$configFile"

            # Check if the cluster has already initialized on another node
            if curl -sfk -H "Authorization: Bearer ${k3sToken}" "${k3sServerAddr}/healthz" > /dev/null 2>&1; then
                echo "K3S_CLUSTER_INIT=false" > "$configFile"
            else
                echo "K3S_CLUSTER_INIT=true" > "$configFile"
            fi
          '';
        };
      };

      # ArgoCD Server for managing Kubernetes applications
      argo-cd = {
        description = "ArgoCD server";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${pkgs.helm}/bin/helm upgrade --install argo-cd argo/argo-cd";
        };
      };

      # # If this device has an NVMe drive, add it to the Longhorn pool
      # # User data will be stored on the pool and backed up remotely
      # # This is the only persistent storage in the cluster
      # detect-nvme-and-add-to-longhorn = {
      #   description = "Detect NVMe and add to Longhorn pool";
      #   wantedBy = [ "multi-user.target" ]; # This ensures the service runs after the system has booted
      #   # Script that checks for NVMe and adds it to Longhorn
      #   serviceConfig = {
      #     Type = "oneshot";
      #     ExecStartPre = "${pkgs.bash}/bin/bash -c 'if ls /dev/nvme0n1 1> /dev/null 2>&1; then exit 0; else exit 1; fi'";
      #     ExecStart = pkgs.writeScript "detect-nvme-and-add-to-longhorn" ''
      #       #!${pkgs.bash}/bin/bash
      #       set -euo pipefail
            
      #       # prepare pkgs paths
      #       export PATH="${pkgs.zstd}/bin:${pkgs.unixtools.wall}/bin:$PATH"

      #       # add NVMe to Longhorn
      #       {
      #         echo "detect-nvme-and-add-to-longhorn | NVMe drive detected, adding to Longhorn pool"
      #         longhorn volume create --name nvme-pool --size 100Gi /dev/nvme0n1
      #         echo "detect-nvme-and-add-to-longhorn | NVMe drive added to Longhorn pool"
      #       } | tee >(systemd-cat -t detect-sd-and-flash-img) | wall
      #     '';
      #   };
      # };
    };

    # Fix for https://github.com/longhorn/longhorn/issues/2166
    tmpfiles.rules = [
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
    ];
  };

  networking = {
    hostName = "pi-k3s-gitops-net-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
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
