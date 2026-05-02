#!/bin/bash

# APPLY FOR OVH CLOUD
sudo iptables -F
IFACE=$(ip link show | awk -F: '/^[0-9]+:/ {print $2}' | tr -d ' ' | grep -v '^lo$' | head -n1)

if [ -z "$IFACE" ]; then
	echo "No network interface found."
	exit 1
else
	echo "First network interface: $IFACE"
fi

PUBLIC_IP=$(ip -4 addr show $IFACE | awk '/inet / && $2 ~ /\/32/ && $2 !~ /^10\./ {print $2}' | head -n1)
PRIVATE_IP="10.0.0.10/24"
GATEWAY=$(ip route get 1.1.1.1 | awk '{print $3}')

cat <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    $IFACE:
      addresses:
        - $PUBLIC_IP
        - $PRIVATE_IP
      routes:
        - to: default
          via: $GATEWAY
EOF

# fix permission
sudo chmod 600 /etc/netplan/00-installer-config.yaml

# apply
sudo netplan apply

# route private ip 
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o $IFACE -j MASQUERADE
