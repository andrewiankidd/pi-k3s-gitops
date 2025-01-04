#!/bin/bash

echo "====================="
echo "net.sh"
echo "====================="
uname -a
lsb_release -a

# Networking vars
INTERFACE="eth1"  # Replace with your network interface name
STATIC_IP="192.168.0.108/24"
GATEWAY="192.168.0.1"  # Replace with your gateway IP
DNS="192.168.0.1"  # Replace with your DNS servers
NETPLAN_CONFIG_PATH="/etc/netplan/99-static-ip.yaml"

# Check if the interface already has the static IP
if ip a show $INTERFACE | grep -q "$STATIC_IP"; then
    echo "Interface $INTERFACE already has the static IP $STATIC_IP. Exiting."
    exit 0
fi

# Create the new Netplan configuration file
echo "Creating Netplan configuration file..."
echo "network:
  version: 2
  renderer: networkd
  ethernets:
      eth0:
        activation-mode: off
      $INTERFACE:
          dhcp4: false
          dhcp6: false
          addresses:
              - $STATIC_IP
          routes:
              - to: default
                via: $GATEWAY
          nameservers:
            addresses: [$DNS]
" | sudo tee $NETPLAN_CONFIG_PATH > /dev/null
sudo chmod 600 $NETPLAN_CONFIG_PATH

# show current config
ip a show $INTERFACE

# Apply the new configuration
# Shows unrelated warnings https://bugs.launchpad.net/ubuntu/+source/netplan.io/+bug/2041727
echo "netplan apply $(sudo cat $NETPLAN_CONFIG_PATH)"
sudo netplan apply

echo "netplan applied!"
ip a show $INTERFACE