#!/bin/bash
# Creates the VMs of a PgVillage demo environment with up.sh:
#   pgv-ansible            management VM: you deploy from here (bootstrap.sh: PgVillage in ~/git/pgvillage, Ansible)
#   pgv-backup             backup VM
#   pgv-db-1 .. pgv-db-3   database VMs (with the data and wal directories of inventories/standard)
#
#   platforms/libvirt/create-demo.sh
#
# The management VM gets its own ssh key, which all VMs accept (next to PGV_LIBVIRT_SSH_KEY). The key is new on every run:
# remove all demo VMs before you run this again. The setup on the management VM runs on its first boot and takes a few
# minutes; wait for it with: ssh <user>@pgv-ansible.<domain> cloud-init status --wait
#
# Settings: those of up.sh, plus
#   PGV_LIBVIRT_REPO    repository the management VM clones  (https://github.com/pgvillage/pgvillage.git)
#   PGV_LIBVIRT_BRANCH  branch of that repository            (main)
set -euo pipefail

LIBVIRT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_URL=${PGV_LIBVIRT_REPO:-https://github.com/pgvillage/pgvillage.git}
BRANCH=${PGV_LIBVIRT_BRANCH:-main}
VM_USER=${PGV_LIBVIRT_USER:-${USER}}
SSH_KEY=${PGV_LIBVIRT_SSH_KEY:-~/.ssh/id_ed25519.pub}

# Checked here too (up.sh checks it), so the message names your file and not the combined one below
if grep -v '^ *$' "${SSH_KEY}" | grep -qvE '^(ssh-|ecdsa-|sk-)'; then
  echo "${SSH_KEY} must hold public keys only (one per line, e.g. ~/.ssh/id_ed25519.pub)" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

# The key of the management VM, and the keys that all VMs accept: yours and that one
ssh-keygen -q -t ed25519 -N '' -C "${VM_USER}@pgv-ansible" -f "${WORK}/id_ed25519"
cat "${SSH_KEY}" "${WORK}/id_ed25519.pub" >"${WORK}/keys.pub"

# Management VM: its private key and bootstrap.sh, then run bootstrap.sh as the user. The files are base64, so their
# content can't break the YAML. defer: the key is written after the user exists.
cat >"${WORK}/ansible.yaml" <<EOF
write_files:
  - path: /home/${VM_USER}/.ssh/id_ed25519
    owner: ${VM_USER}:${VM_USER}
    permissions: '0600'
    encoding: b64
    content: $(base64 -w0 "${WORK}/id_ed25519")
    defer: true
  - path: /usr/local/bin/pgv-bootstrap.sh
    permissions: '0755'
    encoding: b64
    content: $(base64 -w0 "${LIBVIRT_DIR}/bootstrap.sh")
runcmd:
  - runuser -l ${VM_USER} -c '/usr/local/bin/pgv-bootstrap.sh ${REPO_URL} ${BRANCH}'
EOF

# Database VMs: the data and wal mountpoints of inventories/standard (postgresql_data_mountpoint, postgresql_wal_mountpoint)
cat >"${WORK}/db.yaml" <<EOF
runcmd:
  - mkdir -p /data/postgres/data /data/postgres/wal
EOF

export PGV_LIBVIRT_SSH_KEY="${WORK}/keys.pub" PGV_LIBVIRT_USER="${VM_USER}"
PGV_LIBVIRT_CLOUD_CONFIG="${WORK}/ansible.yaml" "${LIBVIRT_DIR}/up.sh" pgv-ansible
"${LIBVIRT_DIR}/up.sh" pgv-backup
PGV_LIBVIRT_CLOUD_CONFIG="${WORK}/db.yaml" "${LIBVIRT_DIR}/up.sh" pgv-db-1 pgv-db-2 pgv-db-3
