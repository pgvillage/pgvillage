#!/bin/bash
set -e

APPS=(stolon wal-g walg etcd postgres minio)

function find_services()
{
  SVC=$1
  find /{etc,usr/lib}/systemd/system/ -name "*${SVC}*" | while read f; do basename "${f}"; done | sort -u
}

function remove_services()
{
  SVC=$1
  find /{etc,usr/lib}/systemd/system/ -name "*${SVC}*" | while read f; do
    echo "Removing ${f}"
  done
}

function stop_services() {
  APP=$1
  find_services "${APP}" | while read SVC ; do
    echo "Stopping and disabling ${SVC}"
    systemctl stop "${SVC}"
    systemctl disable "${SVC}"
  done
}

function remove_rpms() {
  APP=$1
  RPMS=$(rpm -qa | grep "${APP}") || echo "No RPMS for ${APP}"
  [ -z "${RPMS}" ] && return
  IFS=' ' read -r -a RPMS_ARRAY <<< "${RPMS}"
  echo "Erasing ${RPMS}"
  echo "dnf erase -y ${RPMS_ARRAY[@]}"
  dnf erase -y "${RPMS_ARRAY[@]}"
}

function clean_data() {
  APP=$1
  ESCAPED_FOLDERS=$(df | awk '$6~/\//{print $6}' | xargs | sed 's/ /|/')
  find / -name "*${APP}*" | while read f; do
    [ -e "${f}" ] || continue
    [[ "${f}" =~ ^/(boot|dev|proc|run|sys|opt/puppetlabs) ]] && continue
    echo "${ESCAPED_FOLDERS}" | grep -q "$f" && continue
    echo "Removing ${f}"
    rm -rf "${f}"
  done
}

for APP in "${APPS[@]}"; do
  stop_services "${APP}"
  remove_services "${APP}"
  remove_rpms "${APP}"
  clean_data "${APP}"
done
