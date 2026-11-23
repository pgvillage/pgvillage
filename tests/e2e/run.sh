#!/bin/bash
# End-to-end test of a PgVillage deploy (pgvillage/pgvillage#177): create the lima VMs (lima/up.sh), deploy with
# functional-all.yml, deploy again (nothing may change), and check the cluster (tests/e2e/verify.yml).
# CI runs it per OS (ci-run-on-pr.yaml); locally it works the same: PGV_OS=el tests/e2e/run.sh
# The output of every step goes to ${E2E_LOGDIR} (default tests/e2e/logs).
#
# If the VMs make this too slow in CI, switch to systemd containers (as the Molecule tests of the roles do), with
# Ubuntu only: that loses the VIP (keepalived) and firewalld, but is much faster.
set -euo pipefail

export PGV_OS=${PGV_OS:-ubuntu}
case "${PGV_OS}" in
  ubuntu) OS_INVENTORY=inventories/os/debian ;;
  *) OS_INVENTORY=inventories/os/${PGV_OS} ;;
esac
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LOGDIR=${E2E_LOGDIR:-${REPO}/tests/e2e/logs}
mkdir -p "${LOGDIR}"

step() {
  echo
  echo "=== $1 ($(date +%T))"
}

# Runs a playbook on the Ansible VM, from the repository mount, with the inventories of docs/try-it/lima.md
playbook() {
  local log=$1
  shift
  limactl shell --workdir=/ pgv-ansible bash -c \
    ". ~/venv/bin/activate && cd ~/git/pgvillage && ansible-playbook -i inventories/standard -i ${OS_INVENTORY} \
     -i inventories/platform/lima $*" 2>&1 | tee "${LOGDIR}/${log}"
}

step "Create the VMs (${PGV_OS})"
"${REPO}/lima/up.sh" 2>&1 | tee "${LOGDIR}/up.log"

step "Deploy"
playbook deploy.log functional-all.yml

step "Deploy again: nothing may change"
playbook deploy-again.log functional-all.yml
if grep -E '^[^ ]+ +: ok=[0-9]+ +changed=[1-9]' "${LOGDIR}/deploy-again.log"; then
  echo "The second deploy changed the hosts above: the deploy is not idempotent" >&2
  exit 1
fi

step "Check the cluster"
playbook verify.log tests/e2e/verify.yml

step "Done"
