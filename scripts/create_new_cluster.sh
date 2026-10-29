#!/bin/bash
set -e

CLUSTER=${1:-azure}
OS=${2:-el}
INVENTORY="inventories/${CLUSTER}"

cd "$(dirname "$0")/.."
if [ ! -d "${INVENTORY}" ]; then
  echo "Cannot deploy. Missing inventory $PWD/${INVENTORY}/"
  exit 1
fi
if [ ! -d "inventories/${OS}" ]; then
  echo "Cannot deploy. Missing OS inventory $PWD/inventories/${OS}/"
  exit 1
fi
INVENTORIES=(-i inventories/standard -i "inventories/${OS}" -i "${INVENTORY}")

time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/create_resources.yml
echo "Sleeping 90 sec. for all scaleset vms to come alive"
sleep 90
time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/inventory.yml
time ansible-playbook "${INVENTORIES[@]}" playbooks/azure/mount.yml
time ansible-playbook "${INVENTORIES[@]}" functional-all.yml
