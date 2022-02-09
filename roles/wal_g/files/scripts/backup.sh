#!/bin/bash
set -e

SCRIPTDIR=$(dirname $0)

# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

# log output to a logfile in the logdir
WALG_LOG_FOLDER=${WALG_LOG_FOLDER:-/var/log/wal-g}
exec >> "$WALG_LOG_FOLDER/$(date +%Y%m%d)_$(basename $0 .sh).log"

# if there are existing backups younger then WALG_BACKUP_SKIP_WINDOW, then we can skip backup.
SKIP_AFTER=$(date -d "0${WALG_BACKUP_SKIP_WINDOW} hour ago" --iso-8601=seconds)
BACKUPS_SINCE=$(/usr/local/bin/wal-g backup-list | awk -v skipAfter="$SKIP_AFTER" '{if (FNR>1 && skipAfter<=$2) {print}}' | wc -l)
if [ "${BACKUPS_SINCE}" -gt 0 ]; then
  echo "There is already ${BACKUPS_SINCE} backups since ${SKIP_AFTER} (WALG_BACKUP_SKIP_WINDOW of ${WALG_BACKUP_SKIP_WINDOW})."
  echo "So I am skipping backup on this node."
  exit
fi

"$SCRIPTDIR/maintenance.sh"

echo
echo "Pushing backup"
/usr/local/bin/wal-g backup-push "${PGDATA}"

"$SCRIPTDIR/maintenance.sh"
