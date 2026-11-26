#!/bin/bash
# Create PgVillage VMs with libvirt (QEMU/KVM) from a cloud image, with cloud-init.
#
#   platforms/libvirt/up.sh <vm> [<vm> ...]
#
# Each VM gets a disk on top of the cloud image (copy-on-write), a login user with passwordless sudo and your ssh key,
# and the hostname <vm>, so the libvirt network's DHCP registers <vm>.<domain> in its DNS.
# A VM that already exists is left alone.
#
# Settings (environment variables, defaults between brackets):
#   LIBVIRT_DEFAULT_URI  libvirt connection           (virsh default: qemu:///system as root, else qemu:///session)
#   PGV_LIBVIRT_IMAGE        cloud image (qcow2)          (~/images/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2)
#   PGV_LIBVIRT_OSINFO       os variant for virt-install  (rocky9; must match the image. List: virt-install --osinfo list)
#   PGV_LIBVIRT_POOL         storage pool for VM disks    (vms)
#   PGV_LIBVIRT_BRIDGE       bridge of the libvirt network (virbr-pgv)
#   PGV_LIBVIRT_DOMAIN       DNS domain of that network   (pgv.internal)
#   PGV_LIBVIRT_USER         login user in the VMs        ($USER)
#   PGV_LIBVIRT_SSH_KEY      public key(s) for that user, one per line (~/.ssh/id_ed25519.pub)
#   PGV_LIBVIRT_MEMORY       memory in MiB                (2048)
#   PGV_LIBVIRT_VCPUS        virtual cpus                 (2)
#   PGV_LIBVIRT_DISK         disk size                    (20G)
#   PGV_LIBVIRT_CLOUD_CONFIG extra cloud-config, added to the user-data (none). Top-level keys only, not users/hostname/fqdn.
set -euo pipefail

IMAGE=${PGV_LIBVIRT_IMAGE:-~/images/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2}
OSINFO=${PGV_LIBVIRT_OSINFO:-rocky9}
POOL=${PGV_LIBVIRT_POOL:-vms}
BRIDGE=${PGV_LIBVIRT_BRIDGE:-virbr-pgv}
DOMAIN=${PGV_LIBVIRT_DOMAIN:-pgv.internal}
VM_USER=${PGV_LIBVIRT_USER:-${USER}}
SSH_KEY=${PGV_LIBVIRT_SSH_KEY:-~/.ssh/id_ed25519.pub}
MEMORY=${PGV_LIBVIRT_MEMORY:-2048}
VCPUS=${PGV_LIBVIRT_VCPUS:-2}
DISK=${PGV_LIBVIRT_DISK:-20G}
CLOUD_CONFIG=${PGV_LIBVIRT_CLOUD_CONFIG:-}

if [ $# -eq 0 ]; then
  echo "usage: $0 <vm> [<vm> ...]" >&2
  exit 1
fi
for f in "${IMAGE}" "${SSH_KEY}" ${CLOUD_CONFIG:+"${CLOUD_CONFIG}"}; do
  [ -r "${f}" ] || { echo "Can't read ${f}" >&2; exit 1; }
done
# Only public keys: a private key would end up in the VMs' cloud-init data, and nobody could log in
if grep -v '^ *$' "${SSH_KEY}" | grep -qvE '^(ssh-|ecdsa-|sk-)'; then
  echo "${SSH_KEY} must hold public keys only (one per line, e.g. ~/.ssh/id_ed25519.pub)" >&2
  exit 1
fi

USER_DATA=$(mktemp)
trap 'rm -f "${USER_DATA}"' EXIT

for VM in "$@"; do
  if virsh dominfo "${VM}" >/dev/null 2>&1; then
    echo "${VM}: exists, skipped"
    continue
  fi

  # No manage_etc_hosts: it maps the fqdn to 127.0.0.1, and PgVillage uses the fqdn for certificates and endpoints
  # that other hosts connect to. Without it, the fqdn resolves through the network's DNS to the VM's own address.
  cat >"${USER_DATA}" <<EOF
#cloud-config
hostname: ${VM}
fqdn: ${VM}.${DOMAIN}
users:
  - name: ${VM_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
$(grep -v '^ *$' "${SSH_KEY}" | sed 's/^/      - /')
EOF
  [ -z "${CLOUD_CONFIG}" ] || cat "${CLOUD_CONFIG}" >>"${USER_DATA}"

  echo "${VM}: creating"
  virsh vol-create-as "${POOL}" "${VM}.qcow2" "${DISK}" --format qcow2 \
    --backing-vol "${IMAGE}" --backing-vol-format qcow2 >/dev/null
  # --video vga: without a video card, Rocky 9 (SeaBIOS) resets right after GRUB.
  virt-install --name "${VM}" --memory "${MEMORY}" --vcpus "${VCPUS}" --virt-type kvm --import \
    --disk "vol=${POOL}/${VM}.qcow2,bus=virtio" --network "bridge=${BRIDGE},model=virtio" \
    --graphics none --video vga --noautoconsole --osinfo "${OSINFO}" \
    --cloud-init "user-data=${USER_DATA}"
done
