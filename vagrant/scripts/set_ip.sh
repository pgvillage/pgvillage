#!/bin/bash
# Runs as root on every box: sets a static IP (172.30.1.0/24) on the private network.
# Usage: set_ip.sh <ip> [interface]
set -e

MYIP="${1}/24"
# The private network interface is the last one that is not the NAT interface (VirtualBox NAT is 10.0.2.0/24).
# It may already have a DHCP address (cloud-init on ubuntu configures all interfaces).
# Its name depends on the box: enp0s9 (ubuntu), eth1, enp0s8, ...
MYIFC=${2:-$(for IFC in /sys/class/net/*; do
  IFC=$(basename "${IFC}")
  [ "${IFC}" = lo ] && continue
  ip -4 -o addr show dev "${IFC}" | grep -q 'inet 10\.0\.2\.' || echo "${IFC}"
done | tail -n 1)}
[ -n "${MYIFC}" ] || { echo "No private network interface found"; exit 1; }
echo "Configuring static IP ${MYIP} on ${MYIFC}"

with_nmcli() {
  which nmcli >/dev/null 2>&1 || return 1
  nmcli con delete static-private || true
  nmcli con add type ethernet con-name static-private ifname "${MYIFC}" ip4 "${MYIP}"
  nmcli con mod static-private connection.autoconnect yes
  nmcli con up static-private
}

with_netplan() {
  which netplan >/dev/null 2>&1 || return 1
  cat >/etc/netplan/99-pgvillage.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${MYIFC}:
      dhcp4: no
      addresses:
        - ${MYIP}
EOF
  chmod 600 /etc/netplan/99-pgvillage.yaml
  netplan apply
}

with_wicked() {
  which wicked >/dev/null 2>&1 || return 1
  cat >"/etc/sysconfig/network/ifcfg-${MYIFC}" <<EOF
BOOTPROTO='static'
IPADDR='${MYIP}'
STARTMODE='auto'
EOF
  wicked ifreload "${MYIFC}"
}

with_nmcli || with_netplan || with_wicked
