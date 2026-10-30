#!/bin/bash
# Runs as the vagrant user on the Ansible host: installs Ansible and the roles, and ssh to localhost.
# The repository is mounted on ~/git/pgvillage (see the Vagrantfile).
set -e

PGV_OS=${PGV_OS:-ubuntu}

echo Install python3
if which apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git python3-pip python3-venv libffi-dev
elif which dnf >/dev/null 2>&1; then
  sudo dnf install -y git python3-pip libffi-devel
elif which zypper >/dev/null 2>&1; then
  sudo zypper install -y git python3-pip libffi-devel
fi

echo Install ansible
[ -e ~/venv ] || python3 -m venv ~/venv
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
