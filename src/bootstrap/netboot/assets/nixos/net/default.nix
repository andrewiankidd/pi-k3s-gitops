{ config, pkgs, ... }:

let
  # System
  rootPassword = builtins.getEnv "ROOT_PASSWORD";

  # Kubernetes
  k3sServerAddr = builtins.getEnv "K3S_SERVER_ADDRESS";
  k3sToken = builtins.getEnv "K3S_TOKEN";

  # Argo CD
  argoPassword = builtins.getEnv "ARGOCD_PASSWORD";

  # age
  # agePublicKey = builtins.getEnv "AGE_PUBLICKEY";
  # agePrivateKeyFile = pkgs.writeTextFile {
  #   name = "age-private-key";
  #   text = builtins.getEnv "AGE_PRIVATEKEY";
  #   destination = "/etc/secrets/secrets.yml";
  # };


  # gpgPrivateKeyBase64 = builtins.getEnv "GPG_PRIVATE_KEY_B64";
  # gpgPrivateKeyFileContents = pkgs.runCommand "gpg-private-key" { buildInputs = [ pkgs.openssl ]; } ''
  #   echo "${gpgPrivateKeyBase64}" | openssl base64 -d > $out
  # '';
  # gpgPrivateKeyFile = pkgs.writeTextFile {
  #   name = "gpg-private-key.asc";
  #   text = gpgPrivateKeyFileContents;
  #   destination = "/etc/secrets/gpg-private-key.asc";
  # };

  # Cloudflare
  cloudflareCredsB64 = builtins.getEnv "CLOUDFLARE_CREDS_B64";
  cloudflareCredsFileContents = pkgs.runCommand "gpg-private-key" { buildInputs = [ pkgs.openssl ]; } ''
    echo "${cloudflareCredsB64}" | openssl base64 -d > $out
  '';
  cloudflareCredsFile = pkgs.writeTextFile {
    name = "cloudflared-creds.json";
    text = cloudflareCredsFileContents;
    destination = "/etc/secrets/cloudflared-creds.json";
  };
  cloudflareTunnelId = builtins.getEnv "CLOUDFLARE_TUNNEL_ID";
  cloudflareDefault = builtins.getEnv "CLOUDFLARE_DEFAULT";
  cloudflareIngressService = builtins.getEnv "CLOUDFLARE_INGRESS_SERVICE";
  cloudflareDomain = builtins.getEnv "CLOUDFLARE_DOMAIN";

  # sopsSecrets = builtins.getEnv "SOPS_SECRETS";

  # hostname
  possibleHostnames = [ "manwe" "varda" "ulmo" "yavanna" "aule" "mandos" "nienna" "orome" ];
  # Get the MAC address of the first network interface
  #macAddress = lib.mkDefault (builtins.head (builtins.attrValues config.networking.interfaces));
  #macHash = builtins.hashString "sha256" macAddress;
  # Pick a random index based on the hash of the MAC address
  randomIndex = 1; # ((builtins.parseInt macHash) % (length names));
  randomHostName = builtins.elemAt possibleHostnames randomIndex;
in
{
  # System configuration
  time.timeZone = "Europe/London";
  users.users.root.initialPassword = rootPassword;

  environment.systemPackages = with pkgs; [
    helm
    openiscsi
    fuse-overlayfs
    fuse3
    nfs-utils
    cloudflared
    # sops
  ];

  # files to create in /etc/
  environment.etc."secrets/k3s/cluster-config.env" = {
    text = ''
      K3S_URL=${k3sServerAddr}
      K3S_TOKEN=${k3sToken}
      PATH=${pkgs.fuse-overlayfs}/bin:/run/current-system/sw/bin:$PATH
    '';
  };
#   environment.etc."secrets/secrets.yml" = {
#     source = pkgs.writeTextFile {
#       name = "sops-secrets";
#       text = ''
#         ${sopsSecrets}
#       '';
#     };
#   };
#   environment.etc."sops.yaml" = {
#     source = pkgs.writeTextFile {
#       name = "sops-config";
#       text = ''
#         keys:
#           - &primary ${agePublicKey}
#         creation_rules:
#           - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
#             key_groups:
#             - age:
#               - *primary
#         '';
#     };
#   };

#   sops = {
#     age.keyFile = "/etc/secrets/key.txt";
#     defaultSopsFile = "/etc/secrets/secrets.yml";
#     validateSopsFiles = false;
#     secrets = {
#       "cloudflared-creds" = {
#         path = "/etc/secrets/cloudflared-cred.json";
#       };
#     };
#   };

  # boot.postBootCommands = ''
  #   # Import the private key into the GPG keyring after boot
  #   gpg --import ${gpgPrivateKeyFile}
  # '';

  services = {

    # Enable Multi-Node k3s
    k3s =
      let
        # Generate the hashed password using the htpasswd command
        hashedArgoPassword =
          pkgs.runCommand "generate-argo-password" {
            nativeBuildInputs = with pkgs; [
              apacheHttpd
            ];
        }
        ''
          echo -n ${argoPassword} | htpasswd -nbBC 10 "" - | tr -d ':\n' > $out
        '';

        # Create timestamp for passwordmtime
        currentTimestamp =
          pkgs.runCommand "generate-timestamp" {
            nativeBuildInputs = with pkgs; [
              pkgs.coreutils
              pkgs.gnused
              pkgs.dateutils
            ];
          }
          ''
            date --utc '+%Y-%m-%dT%H:%M:%SZ' > $out
          '';

        # Download the helm chart at build time so it is immediately available when the OS starts
        # https://artifacthub.io/packages/helm/argo/argo-cd
        argocdChart =
          pkgs.runCommand "argocd-chart"
            {
              nativeBuildInputs = with pkgs; [
                kubernetes-helm
                cacert
              ];
              # outputHashAlgo = "sha256";
              # outputHash = "sha256-156376281f14ab90c6684febef5889ea7ef221e241e73604ab33dfd39b23cf31";
            }
            ''
              export HOME="$PWD"

              helm repo add repository https://argoproj.github.io/argo-helm
              helm pull repository/argo-cd --version 7.7.16
              mv ./*.tgz $out
            '';

        # Download the helm chart at build time so it is immediately available when the OS starts
        # https://artifacthub.io/packages/helm/argo/argocd-apps
        argocdappsChart =
          pkgs.runCommand "argocdapps-chart"
            {
              nativeBuildInputs = with pkgs; [
                kubernetes-helm
                cacert
              ];
              # outputHashAlgo = "sha256";
              # outputHash = "sha256-156376281f14ab90c6684febef5889ea7ef221e241e73604ab33dfd39b23cf31";
            }
            ''
              export HOME="$PWD"

              helm repo add repository https://argoproj.github.io/argo-helm
              helm pull repository/argocd-apps --version 2.0.2
              mv ./*.tgz $out
            '';
      in
      {
      enable = true;
      role = "server";
      environmentFile = "/etc/secrets/k3s/cluster-config.env";
      extraFlags = toString [
        "--snapshotter=fuse-overlayfs"
        "--etcd-snapshot-schedule-cron=0"
        "--etcd-disable-snapshots"
        "--datastore-endpoint=sqlite:///var/lib/rancher/k3s/k3s.db"
        "--kubelet-arg=eviction-hard=nodefs.available<1%,imagefs.available<1%,containerfs.available<1%"
        "--debug"
      ];
      # Apply our pre-downloaded Argo CD chart at runtime
      charts.ArgoCD = argocdChart;
      manifests.argocd.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata = {
          name = "argocd";
          namespace = "kube-system";
        };
        spec = {
          targetNamespace = "argocd";
          createNamespace = true;
          chart = "https://%{KUBERNETES_API}%/static/charts/ArgoCD.tgz";
          valuesContent = ''
            global:
              domain: argocd.kidd.network
              priorityClassName: system-cluster-critical
            server:
              autoscaling:
                enabled: false
                minReplicas: 1
              extraArgs:
                - --insecure

            repoServer:
              autoscaling:
                enabled: true
                minReplicas: 1

            applicationSet:
              replicas: 1

            configs:
              params:
                application.namespaces: "*"
            #   secret:
            #     argocdServerAdminPassword: "${hashedArgoPassword}"
            #     argocdServerAdminPasswordMtime: "${currentTimestamp}"

            # rbac:
            #   create: true
            #   policy.default: role:admin
            #   policy.csv: |
            #     # Grant admin role full access to everything
            #     p, role:admin, applications, *, */*, allow
            #     p, role:admin, clusters, get, *, allow
            #     p, role:admin, repositories, *, *, allow
            #     p, role:admin, logs, get, *, allow
            #     p, role:admin, exec, create, */*, allow
            #     p, role:admin, *, *, *, allow

            #     # Assign the admin user to the admin role
            #     g, admin, role:admin

            #     # Map the admin user to the quendi-admin role
            #     g, admin, role:quendi-admin
            #     # Grant admin permissions to the quendi namespace
            #     p, role:quendi-admin, applications, *, quendi/*, allow
            #     p, role:quendi-admin, projects, *, quendi, allow

            #     # Map the admin user to the atani-admin role
            #     g, admin, role:atani-admin
            #     # Grant admin permissions to the atani namespace
            #     p, role:atani-admin, applications, *, atani/*, allow
            #     p, role:atani-admin, projects, *, atani, allow

            #     # Map the admin user to the perian-admin role
            #     g, admin, role:perian-admin
            #     # Grant admin permissions to the perian namespace
            #     p, role:perian-admin, applications, *, perian/*, allow
            #     p, role:perian-admin, projects, *, perian, allow
            #   scopes: "[groups]"
            #   policy.matchMode: "glob"
          '';
        };
      };
      # Apply our pre-packaged ArgoCD Apps chart at runtime
      charts.ArgoCDApps = argocdappsChart;
      manifests.argocd-apps.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata = {
          name = "argocd-apps";
          namespace = "kube-system";
        };
        spec = {
          targetNamespace = "argocd";
          createNamespace = true;
          chart = "https://%{KUBERNETES_API}%/static/charts/ArgoCDApps.tgz";
          valuesContent = ''
            applications:
              quendi:
                namespace: argocd
                finalizers:
                - resources-finalizer.argocd.argoproj.io
                project: "quendi"
                sources:
                - repoURL: https://github.com/andrewiankidd/pi-k3s-gitops.git
                  path: src/kubernetes/quendi
                  targetRevision: feature/master-node
                destination:
                  server: https://kubernetes.default.svc
                  namespace: quendi
                syncPolicy:
                  syncOptions:
                    - CreateNamespace=true
                  automated:
                    prune: true
                    selfHeal: true
              atani:
                namespace: argocd
                finalizers:
                - resources-finalizer.argocd.argoproj.io
                project: "atani"
                sources:
                - repoURL: https://github.com/andrewiankidd/pi-k3s-gitops.git
                  path: src/kubernetes/atani
                  targetRevision: feature/master-node
                destination:
                  server: https://kubernetes.default.svc
                  namespace: atani
                syncPolicy:
                  syncOptions:
                    - CreateNamespace=true
                  automated:
                    prune: true
                    selfHeal: true
              perian:
                namespace: argocd
                finalizers:
                - resources-finalizer.argocd.argoproj.io
                project: "perian"
                sources:
                - repoURL: https://github.com/andrewiankidd/pi-k3s-gitops.git
                  path: src/kubernetes/perian
                  targetRevision: feature/master-node
                destination:
                  server: https://kubernetes.default.svc
                  namespace: perian
                syncPolicy:
                  syncOptions:
                    - CreateNamespace=true
                  automated:
                    prune: true
                    selfHeal: true

            projects:
              quendi:
                namespace: argocd
                description: "Project for managing Critical applications"
                sourceRepos:
                  - "https://github.com/andrewiankidd/pi-k3s-gitops.git"
                  - "*"
                sourceNamespaces:
                  - quendi
                  - argocd
                destinations:
                  - namespace: quendi*
                    server: "https://kubernetes.default.svc"
                clusterResourceWhitelist:
                  - group: "*"
                    kind: "*"
                orphanedResources:
                  warn: true
                # roles:
                #   - name: quendi-admin
                #     description: "Admin role for Quendi project"
                #     policies:
                #       - "p, proj:quendi:quendi-admin, applications, *, quendi/*, allow"
                #     groups:
                #       - "quendi-admin-group"
              atani:
                namespace: argocd
                description: "Project for managing Important applications"
                sourceRepos:
                  - "https://github.com/andrewiankidd/pi-k3s-gitops.git"
                  - "*"
                sourceNamespaces:
                  - atani
                  - argocd
                destinations:
                  - namespace: atani*
                    server: "https://kubernetes.default.svc"
                clusterResourceWhitelist:
                  - group: "*"
                    kind: "*"
                orphanedResources:
                  warn: true
                # roles:
                #   - name: atani-admin
                #     description: "Admin role for Atani project"
                #     policies:
                #       - "p, proj:atani:atani-admin, applications, *, atani/*, allow"
                #     groups:
                #       - "atani-admin-group"
              perian:
                namespace: argocd
                description: "Project for managing Other applications"
                sourceRepos:
                  - "https://github.com/andrewiankidd/pi-k3s-gitops.git"
                  - "*"
                sourceNamespaces:
                  - perian
                  - argocd
                destinations:
                  - namespace: perian*
                    server: "https://kubernetes.default.svc"
                clusterResourceWhitelist:
                  - group: "*"
                    kind: "*"
                orphanedResources:
                  warn: true
                # roles:
                #   - name: perian-admin
                #     description: "Admin role for Perian project"
                #     policies:
                #       - "p, proj:perian:perian-admin, applications, *, perian/*, allow"
                #     groups:
                #       - "perian-admin-group"
          '';
        };
      };
      manifests.argocd-ingress.content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "argocd-ingress";
          namespace = "argocd";
          annotations = {
            "nginx.ingress.kubernetes.io/limit-rps" = "5";
            "nginx.ingress.kubernetes.io/limit-rpm" = "100";
            "nginx.ingress.kubernetes.io/ssl-redirect" = "false";
            "traefik.ingress.kubernetes.io/router.tls" = "false";
            "kubernetes.io/ingress.class" = "traefik";
          };
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = "argocd.kidd.network";
              http = {
                paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend = {
                      service = {
                        name = "argocd-server";
                        port = {
                          number = 80;
                        };
                      };
                    };
                  }
                ];
              };
            }
          ];
        };
      };
      # manifests.cloudflareSecret.content = {
      #   apiVersion = "v1";
      #   kind = "Secret";
      #   metadata = {
      #       name = "cloudflare";
      #       namespace = "cloudflare-gateway";
      #   };
      #   type = "Opaque";
      #   stringData = {
      #     ACCOUNT_ID = builtins.getEnv "CLOUDFLARE_ACCOUNT_ID" or "";
      #     TOKEN = builtins.getEnv "CLOUDFLARE_TOKEN" or "";
      #   };
      # };
    };

    #TODO
    cloudflared = {
      enable = true;
      tunnels = {
        cloudflareTunnelId = {
          # credentialsFile = config.sops.secrets.cloudflared-creds.path;
          credentialsFile = cloudflareCredsFile.outPath;
          default = cloudflareDefault;
          ingress = {
            cloudflareDomain = {
              service = cloudflareIngressService;
            };
          };
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
      name = "${config.networking.hostName}-initiatorhost";
    };

    # enable pipewire for multimedia
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  fileSystems = {
    "/etc/secrets" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=1M" ];
    };
  };

  systemd = {
    services = {
      # append to k3s PATH
      k3s.path = [
        pkgs.fuse-overlayfs
        pkgs.fuse3
      ];

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
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'mkdir -p /etc/secrets/k3s'";
          ExecStart = pkgs.writeScript "k3s-check-cluster" ''
            #!${pkgs.bash}/bin/bash
            set -euo pipefail

            # output file
            envFile="/etc/secrets/k3s/cluster-config.env"

            # TODO: Check if the cluster has already initialized on another node
            if curl -sfk -H "Authorization: Bearer ${k3sToken}" "${k3sServerAddr}/healthz" > /dev/null 2>&1; then
                echo "K3S_CLUSTER_INIT=false" > "$envFile"
            else
                echo "K3S_CLUSTER_INIT=true" > "$envFile"
            fi
          '';
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

    tmpfiles.rules = [
      # Fix for https://github.com/longhorn/longhorn/issues/2166
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"

      # tmpfs-backed filesystem for secrets
      "d /etc/secrets 0750 root root -"
      "d /etc/sops 0755 root root -"
    ];
  };

  networking = {
    hostName = "pi-k3s-gitops-${randomHostName}-${builtins.substring 0 10 (builtins.hashString "sha256" "pi-k3s-gitops")}";
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
