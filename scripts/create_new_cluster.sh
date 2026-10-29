#!/bin/bash
set -e

function cluster_exists() {
  if [ ! -d "environments/${CLUSTER}" ]; then
    echo "Cannot deploy. Missing environment $PWD/environments/${CLUSTER}/"
    exit 1
  fi
}


CLUSTER=${1:-cluster1}
cd ~/git/pgv_azure && cluster_exists
time ansible-playbook -i environments/${CLUSTER} create_resources.yml
echo "Sleeping 90 sec. for all scaleset vms to come alive"
sleep 90
time ansible-playbook -i environments/${CLUSTER} inventory.yml
time ansible-playbook -i environments/${CLUSTER} mount.yml

cd ~/git/pgvillage && cluster_exists
time ansible-playbook -i environments/${CLUSTER} functional-all.yml
