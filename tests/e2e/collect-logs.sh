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
  for f in ha.stderr.log serial.log serialv.log; do
    [ -f "${HOME}/.lima/${vm}/${f}" ] && cp "${HOME}/.lima/${vm}/${f}" "${LOGDIR}/lima/${vm}-${f}"
  done
done
exit 0
