#!/bin/bash
set -e

APPS=(stolon wal-g walg etcd postgres minio pgroute66 keepalived haproxy pgquartz)

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
  RPMS=$(rpm -qa | grep "${APP}" | xargs)
  [ -z "${RPMS}" ] && return
  IFS=' ' read -r -a RPMS_ARRAY <<< "${RPMS}"
  echo "Erasing ${RPMS_ARRAY[@]}"
  echo "dnf erase -y ${RPMS_ARRAY[@]}"
  dnf erase -y "${RPMS_ARRAY[@]}"
}

function remove_users() { 
  USER=$1
  if [ -d /home/$USER ]; then
    killall -KILL -u $USER
    #delete at jobs, enter
    find /var/spool/at/ -name "[^.]*" -type f -user $USER -delete
    # Remove cron jobs, enter:
    crontab -r -u $USER
    # Delete print jobs, enter:
    lprm $USER
    # You can find file owned by a user called vivek and change its ownership as follows:
    find / -user $USER -exec chown root:root {} \;
    #Finally, delete user account called $USER, enter:
    userdel -r $USER
  fi
} 

function clean_data() {
  APP=$1
  ESCAPED_FOLDERS=$(df | awk '$6~/\//{print $6}' | xargs | sed 's/ /|/')
  find / -name "*${APP}*" | while read f; do
    [ -e "${f}" ] || continue
    [[ "${f}" =~ ^/(boot|dev|proc|run|sys|opt/puppetlabs|data/postgres/backup) ]] && continue
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
  remove_users "${APP}"
done
