#!/bin/bash
# Creates and starts the PgVillage lima VMs (an Ansible VM, a backup VM and three database VMs), lets the Ansible VM
# log in on the others, and installs Ansible and the roles on it. Run it from anywhere; rerunning it is safe.
# PGV_OS selects the image and matches the OS inventory to deploy with: ubuntu (default) or el.
# See docs/administrators-guide/platforms/lima.md.
set -e

PGV_OS=${PGV_OS:-ubuntu}
case "${PGV_OS}" in
  ubuntu) IMAGE=template:_images/ubuntu-26.04 ;;
  el) IMAGE=template:_images/rocky-9 ;;
  *) echo "PGV_OS must be ubuntu or el, not ${PGV_OS}" >&2; exit 1 ;;
esac
LIMA_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "${LIMA_DIR}")

# name:cpus:memory(GiB)
VMS="pgv-ansible:1:1 pgv-backup:1:1 pgv-db-1:2:2 pgv-db-2:2:2 pgv-db-3:2:2"

for vm in ${VMS}; do
  IFS=: read -r name cpus memory <<<"${vm}"
  if ! limactl list --quiet | grep -qx "${name}"; then
    set='.mounts=[]'
    # The repository, so you deploy what you have checked out
    [ "${name}" = pgv-ansible ] &&
      set=".mounts=[{\"location\":\"${REPO}\",\"mountPoint\":\"{{.Home}}/git/pgvillage\",\"writable\":true}]"
    # The OS image (only the image, without the default mounts of e.g. template:ubuntu) and pgvillage.yaml
    printf 'base:\n- %s\n- %s\n' "${IMAGE}" "${LIMA_DIR}/pgvillage.yaml" |
      limactl create --tty=false --name="${name}" --cpus="${cpus}" --memory="${memory}" --set="${set}" -
  fi
  limactl start --tty=false "${name}"
done

# The data and wal mountpoints of inventories/standard (postgresql_data_mountpoint, postgresql_wal_mountpoint)
for name in pgv-db-1 pgv-db-2 pgv-db-3; do
  limactl shell "${name}" sudo mkdir -p /data/postgres/data /data/postgres/wal
done

# A key for the Ansible VM, authorized on all VMs (the user is the same everywhere: yours)
limactl shell pgv-ansible bash -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -f ~/.ssh/id_ed25519 -N ""'
PUBKEY=$(limactl shell pgv-ansible cat .ssh/id_ed25519.pub)
for vm in ${VMS}; do
  limactl shell "${vm%%:*}" bash -c "grep -qxF '${PUBKEY}' ~/.ssh/authorized_keys || echo '${PUBKEY}' >>~/.ssh/authorized_keys"
done

limactl shell --workdir=/ pgv-ansible env PGV_OS="${PGV_OS}" bash -c '~/git/pgvillage/vagrant/scripts/bootstrap.sh'
