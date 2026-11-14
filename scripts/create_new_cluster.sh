#!/bin/bash
set -e

# Usage: scripts/create_new_cluster.sh [cluster] [os]
#   cluster: an inventory in inventories/platform/ or inventories/ (default: azure, i.e. inventories/platform/azure)
#   os:      el (default), suse or debian (ubuntu is accepted for debian): inventories/os/<os>
CLUSTER=${1:-azure}
OS=${2:-el}
[ "${OS}" = ubuntu ] && OS=debian

cd "$(dirname "$0")/.."
if [ -d "inventories/platform/${CLUSTER}" ]; then
  INVENTORY="inventories/platform/${CLUSTER}"
else
  INVENTORY="inventories/${CLUSTER}"
fi
if [ ! -d "${INVENTORY}" ]; then
  echo "Cannot deploy. Missing inventory $PWD/${INVENTORY}/"
  exit 1
fi
if [ ! -d "inventories/os/${OS}" ]; then
  echo "Cannot deploy. Missing OS inventory $PWD/inventories/os/${OS}/"
  exit 1
fi
INVENTORIES=(-i inventories/standard -i "inventories/os/${OS}" -i "${INVENTORY}")

time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/create_resources.yml
echo "Sleeping 90 sec. for all scaleset vms to come alive"
sleep 90
time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/inventory.yml
time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/mount.yml
time ansible-playbook "${INVENTORIES[@]}" functional-all.yml
