#!/bin/bash
# Collects what helps to debug a failed e2e run (tests/e2e/run.sh) into ${E2E_LOGDIR}: the journal of every VM and
# lima's own logs. CI uploads the directory as an artifact.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
LOGDIR=${E2E_LOGDIR:-${REPO}/tests/e2e/logs}
mkdir -p "${LOGDIR}/lima"

limactl list >"${LOGDIR}/lima/list.txt" 2>&1
for vm in $(limactl list --quiet 2>/dev/null); do
  limactl shell --workdir=/ "${vm}" sudo journalctl --no-pager -b >"${LOGDIR}/journal-${vm}.log" 2>&1
  # What is still running (e.g. a hanging package install), and the logs of the package manager and cloud-init
  limactl shell --workdir=/ "${vm}" sudo bash -c 'ps -eo pid,ppid,etime,stat,args --forest; echo; ss -tnp' \
    >"${LOGDIR}/processes-${vm}.txt" 2>&1
  limactl shell --workdir=/ "${vm}" sudo bash -c \
    'tail -n 300 /var/log/apt/term.log /var/log/dpkg.log /var/log/dnf.log /var/log/cloud-init-output.log 2>/dev/null' \
    >"${LOGDIR}/packages-${vm}.log" 2>&1
  for f in ha.stderr.log serial.log serialv.log; do
    [ -f "${HOME}/.lima/${vm}/${f}" ] && cp "${HOME}/.lima/${vm}/${f}" "${LOGDIR}/lima/${vm}-${f}"
  done
done
exit 0
