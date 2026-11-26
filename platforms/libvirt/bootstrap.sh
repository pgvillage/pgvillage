#!/bin/bash
# Prepares the management VM: clones PgVillage and installs Ansible (in ~/venv) with the roles and collections of
# requirements.yml. Run it on the management VM as the user that deploys (not root); rerunning it is safe.
# create-demo.sh runs it with cloud-init on the first boot (output: /var/log/cloud-init-output.log).
#
#   bootstrap.sh [<repository url> [<branch>]]
#
# The repository goes to ~/git/pgvillage (an existing clone is left alone).
set -euo pipefail

REPO_URL=${1:-https://github.com/pgvillage/pgvillage.git}
BRANCH=${2:-main}
REPO_DIR=~/git/pgvillage
PYTHON=python3

echo "Install git and python"
if command -v dnf >/dev/null; then
  # EL9's python3 is 3.9, which only gets ansible-core 2.15
  sudo dnf install -y git python3.12 python3.12-pip libffi-devel
  PYTHON=python3.12
elif command -v apt-get >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y git python3-pip python3-venv libffi-dev
elif command -v zypper >/dev/null; then
  sudo zypper install -y git python3-pip libffi-devel
fi

echo "Clone ${REPO_URL} (${BRANCH}) to ${REPO_DIR}"
[ -d "${REPO_DIR}" ] || git clone -b "${BRANCH}" "${REPO_URL}" "${REPO_DIR}"

echo "Install ansible"
[ -e ~/venv ] || "${PYTHON}" -m venv ~/venv
# shellcheck source=/dev/null
. ~/venv/bin/activate
grep -q venv/bin/activate ~/.bashrc || echo '. ~/venv/bin/activate' >>~/.bashrc
pip3 install --upgrade pip ansible netaddr
ansible-galaxy role install --role-file "${REPO_DIR}/requirements.yml"
ansible-galaxy collection install --requirements-file "${REPO_DIR}/requirements.yml"
