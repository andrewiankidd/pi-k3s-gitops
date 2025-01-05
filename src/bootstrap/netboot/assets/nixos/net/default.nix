{ pkgs, lib, ... }: {

  time.timeZone = "Europe/London";
  users.users.root.initialPassword = "todo";

  networking = {
    hostName = "pi-k3s-gitops-net-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
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

  environment.systemPackages = with pkgs; [
    unixtools.wall
    zstd
  ];

  # Enable rtkit for pipewire
  security = {
    rtkit = {
      enable = true;
    };
  };

  # If this device has an SD card, flash OS to SD card
  # So long as there is at least one device with a flashed SD card
  # the cluster can rebuild itself
  systemd = {
    services = {
      sd-flash = {
        description = "SD card snapshot";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'if ls /dev/mmcblk0 1> /dev/null 2>&1; then exit 0; else exit 1; fi'";
          ExecStart = pkgs.writeScript "sd-flash" ''
            #!${pkgs.bash}/bin/bash
            set -euo pipefail

            # prepare pkgs paths
            export PATH="${pkgs.zstd}/bin:${pkgs.unixtools.wall}/bin:$PATH"

            # set expected path of sd image

            # Flash the image and send output to the systemd journal
            {
              SD_IMAGE_OUT_PATH=/boot/firmware/sd.img.zst

              if [ ! -f $SD_IMAGE_OUT_PATH ]; then
                echo "sd-flash | SD image not found, skipping flash."
                exit 0
              fi

              echo "sd-flash | SD card detected. Flashing image..."
              zstd -dc $SD_IMAGE_OUT_PATH | dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress 2>&1 \
                  | tee >(systemd-cat -t sd-flash) | while IFS= read -r line; do
                      wall "$line"
                  done
              echo "sd-flash | Flashing complete."
            } | tee >(systemd-cat -t sd-flash) | wall
          '';
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
