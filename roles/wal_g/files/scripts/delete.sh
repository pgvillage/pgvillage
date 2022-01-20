#!/bin/bash
set -e

echo
# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

if [ "${WALG_RETENTION_DAYS}" ]; then
  # Wat was de datum 
  BEFORE=$(date --date="${WALG_RETENTION_DAYS} days ago" --iso-8601)"T00:00:00Z"
  echo "Cleaning all backups before ${BEFORE}"
  /usr/local/bin/wal-g delete before FIND_FULL "${BEFORE}" --confirm
elif [ "${WALG_RETENTION_FULL_BACKUPS}" ]; then
  BACKUPS=$(/usr/local/bin/wal-g backup-list | awk '$1!~/_D_/&&$1~/^base/{print $1}')
  NUMBACKUPS=$(echo "${BACKUPS}" | wc -w)
  if [ "${NUMBACKUPS}" -le  "${WALG_RETENTION_FULL_BACKUPS}" ]; then
    echo "Nothing to do. Want to retain ${WALG_RETENTION_FULL_BACKUPS} full backups and there are only ${NUMBACKUPS}."
    exit 0
  fi
  FIRSTTOKEEP=$(echo "${BACKUPS}" | xars -n1 | tail -n "${WALG_RETENTION_FULL}" | head -n1)
  echo "Cleaning all backups before full ${FIRSTTOKEEP}"
  /usr/local/bin/wal-g delete before "${FIRSTTOKEEP}" --confirm
elif [ "${WALG_RETENTION_BACKUPS}" ]; then
  BACKUPS=$(/usr/local/bin/wal-g backup-list | awk '$1~/^base/{print $1}')
  NUMBACKUPS=$(echo "${BACKUPS}" | wc -w)
  if [ "${NUMBACKUPS}" -le  "${WALG_RETENTION_BACKUPS}" ]; then
    echo "Nothing to do. Want to retain ${WALG_RETENTION_BACKUPS} backups and there are only ${NUMBACKUPS}."
    exit 0
  fi
  FIRSTTOKEEP=$(echo "${BACKUPS}" | xars -n1 | tail -n "${WALG_RETENTION_FULL}" | head -n1)
  echo "Cleaning all backups before ${FIRSTTOKEEP}"
  /usr/local/bin/wal-g delete before FIND_FULL "${FIRSTTOKEEP}" --confirm
else
  echo 'Nothing to do. WALG_RETENTION_DAYS, WALG_RETENTION_FULL_BACKUPS, and WALG_RETENTION_BACKUPS are all not set.'
  exit 1
fi


