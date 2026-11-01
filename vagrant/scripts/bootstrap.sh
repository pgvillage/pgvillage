#!/bin/bash
# Runs as the vagrant user on the Ansible host: installs Ansible and the roles, and ssh to localhost.
# The repository is mounted on ~/git/pgvillage (see the Vagrantfile).
set -e

PGV_OS=${PGV_OS:-ubuntu}
PYTHON=python3

echo Install python3
if which apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git python3-pip python3-venv libffi-dev
elif which dnf >/dev/null 2>&1; then
  # EL9's python3 is 3.9, which only gets ansible-core 2.15
  sudo dnf install -y git python3.12 python3.12-pip libffi-devel
  PYTHON=python3.12
elif which zypper >/dev/null 2>&1; then
  sudo zypper install -y git python3-pip libffi-devel
fi

# On Apple silicon, VirtualBox reports SVE2 to some kernels (EL9), but the CPU can't run it. The OpenSSL in the
# cryptography wheel then crashes Ansible with "Illegal instruction". Don't let OpenSSL use the CPU's crypto extensions.
if [ "$(uname -m)" = aarch64 ]; then
  export OPENSSL_armcap=0
  grep -q OPENSSL_armcap ~/.bashrc || echo 'export OPENSSL_armcap=0' >>~/.bashrc
  # Keep it for become (sudo) tasks on localhost, e.g. the dnf module (it crashes too without it)
  echo 'Defaults env_keep += "OPENSSL_armcap"' | sudo tee /etc/sudoers.d/openssl_armcap >/dev/null
  sudo chmod 0440 /etc/sudoers.d/openssl_armcap
fi

echo Install ansible
[ -e ~/venv ] || "${PYTHON}" -m venv ~/venv
# shellcheck source=/dev/null
. ~/venv/bin/activate
grep -q venv/bin/activate ~/.bashrc || echo '. ~/venv/bin/activate' >>~/.bashrc
pip3 install --upgrade pip ansible netaddr
ansible-galaxy role install --role-file ~/git/pgvillage/requirements.yml
ansible-galaxy collection install --requirements-file ~/git/pgvillage/requirements.yml

# The OS inventory to deploy with: ansible-playbook -i inventories/standard -i inventories/${PGV_OS} ...
grep -q PGV_OS ~/.bashrc || echo "export PGV_OS=${PGV_OS}" >>~/.bashrc

echo Setup ssh localhost
ssh-keygen -H -F localhost >/dev/null || ssh-keyscan -H localhost >>~/.ssh/known_hosts
