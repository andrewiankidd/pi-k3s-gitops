---
title: Cloudflare
description: Things to do
draft: true
---

<center>
    <img
        src="/pi-k3s-gitops/_image?href=%2F%40fs%2FC%3A%2Fgit%2Fpi-k3s-gitops%2Fdocs%2Fsrc%2Fassets%2Ftodo.png"
        style="height:250px"
    >
    <h3>TODO: still a WIP</h3>
</center>


## tunnel, ssl

## age
mkdir -p ~/.config/sops/age
brew install age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
set public key env var
copy keys o build dir

export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt


## GPG
generate a gpg key:
```
export KEY_NAME="Tiexin Guo"
export KEY_COMMENT="test key for sops"

gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
EOF
```

find your key id
```
gpg --list-keys
```

export private key:
```
gpg --export-secret-keys --armor <your-key-fingerprint> > gpg-private-key.asc
```

base64 it put it in env var

## cloudflare credentials file

install cloudflared:

`choco install cloudflared`

login:

`cloudflared tunnel login`

run cloudflared:

`cloudflared tunnel create <NAME>`

it gives you ie:
`Tunnel credentials written to 00000000-0000-0000-0000-000000000000.json. cloudflared chose this file based on where your origin certificate was found. Keep this file secret. To revoke these credentials, delete the tunnel.`

### encrypt with gpg

Encrypt the cloudflared credentials JSON file:
```
gpg --encrypt --armor --recipient <YOUR_GPG_KEY_EMAIL> /path/to/00000000-0000-0000-0000-000000000000.json
```

This will generate an encrypted file, e.g., `00000000-0000-0000-0000-000000000000.json.asc`.

base64 it put it in env var


## sops

env:
```
 environment.systemPackages = with pkgs; [
    sops
  ];

  config.sops.secrets = {
    "cloudflared-creds" = {
      path = "/etc/secrets/cloudflared-creds.json.asc";
    };
  };
```

take this json file and provide use it in nixos [like this](https://search.nixos.org/options?channel=unstable&show=services.cloudflared.tunnels&from=0&size=50&sort=relevance&type=packages&query=services.cloudflared.tunnels)
```
services.cloudflared.tunnels = {
  "00000000-0000-0000-0000-000000000000" = {
    credentialsFile = "/tmp/test";
    default = "http_status:404";
    ingress = {
      "*.domain.com" = {
        service = "http://traefik.kube-system.svc.cluster.local:80";
      };
    };
  };
};

```