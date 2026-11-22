#!/bin/bash
# Collects what helps to debug a failed e2e run (tests/e2e/run.sh) into ${E2E_LOGDIR}: lima's own files of every VM
# (first: they are on the host, so they also work when a VM hangs), the memory and load of the host, and per VM the
# journal, the running processes and the package manager logs. Every command in a VM has a timeout, so a hanging VM
# doesn't hang this script. CI uploads the directory as an artifact.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
LOGDIR=${E2E_LOGDIR:-${REPO}/tests/e2e/logs}
mkdir -p "${LOGDIR}/lima"

{ uptime; echo; free -m; echo; ps -eo pid,etime,pcpu,pmem,rss,args --sort=-rss | head -20; } >"${LOGDIR}/host.txt" 2>&1
limactl list >"${LOGDIR}/lima/list.txt" 2>&1
VMS=$(limactl list --quiet 2>/dev/null)
for vm in ${VMS}; do
  for f in ha.stderr.log serial.log serialv.log; do
    [ -f "${HOME}/.lima/${vm}/${f}" ] && cp "${HOME}/.lima/${vm}/${f}" "${LOGDIR}/lima/${vm}-${f}"
  done
done

in_vm() {
  local vm=$1 out=$2
  shift 2
  timeout 60 limactl shell --workdir=/ "${vm}" sudo bash -c "$*" >"${LOGDIR}/${out}" 2>&1 </dev/null ||
    echo "(failed or timed out: $?)" >>"${LOGDIR}/${out}"
}
for vm in ${VMS}; do
  in_vm "${vm}" "processes-${vm}.txt" 'uptime; free -m; echo; ps -eo pid,ppid,etime,stat,pcpu,rss,args --forest; echo; ss -tnp'
  in_vm "${vm}" "packages-${vm}.log" \
    'tail -n 300 /var/log/apt/term.log /var/log/dpkg.log /var/log/dnf.log /var/log/cloud-init-output.log 2>/dev/null'
  in_vm "${vm}" "journal-${vm}.log" 'journalctl --no-pager -b'
done
exit 0
