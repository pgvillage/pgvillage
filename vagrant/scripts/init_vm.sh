#!/bin/bash
# Runs as root on every box: new host keys, a shared ssh key for the vagrant user, /etc/hosts and the clock.
set -e

rm -rf /etc/ssh/ssh_host_*
/usr/bin/ssh-keygen -A

# One key for all boxes (in vagrant/.ssh on your laptop, not in git), so the Ansible host can log in on all of them
mkdir -p /vagrant/.ssh ~vagrant/.ssh
chown vagrant: ~vagrant/.ssh
chmod 0700 ~vagrant/.ssh
[ -f /vagrant/.ssh/id_rsa ] || ssh-keygen -q -f /vagrant/.ssh/id_rsa -N ''
[ -f ~vagrant/.ssh/id_rsa ] || cp /vagrant/.ssh/id_rsa* ~vagrant/.ssh/
grep -qxF "$(cat /vagrant/.ssh/id_rsa.pub)" ~vagrant/.ssh/authorized_keys ||
  cat /vagrant/.ssh/id_rsa.pub >>~vagrant/.ssh/authorized_keys
chmod 0600 ~vagrant/.ssh/*
chown vagrant: ~vagrant/.ssh/*

# No DNS: seed the hosts
grep -q ansible.local /etc/hosts || echo '172.30.1.10 ansible.local ansible
172.30.1.20 minio.local minio
172.30.1.31 db-1.local db-1
172.30.1.32 db-2.local db-2
172.30.1.33 db-3.local db-3' >>/etc/hosts

# Step the clock after a suspend, instead of slewing (etcd and certificates don't like a clock in the past)
for CHRONY_CONF in /etc/chrony/chrony.conf /etc/chrony.conf; do
  if [ -f "${CHRONY_CONF}" ]; then
    sed -i 's/^makestep.*/makestep 1 -1/' "${CHRONY_CONF}"
    systemctl restart chrony 2>/dev/null || systemctl restart chronyd
    break
  fi
done
