#!/bin/bash
set -e

SCRIPTDIR=$(dirname $0)

# WAL-g config laden (bevat ook PG config)
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

# log output to a logfile in the logdir
WALG_LOG_FOLDER=${WALG_LOG_FOLDER:-/var/log/wal-g}
exec >> "$WALG_LOG_FOLDER/$(date +%Y%m%d)_$(basename $0 .sh).log"

PGROLE=$(psql -tc "select case when pg_is_in_recovery() then 'standby' else 'primary' end;" | xargs)
echo "Postgres role is ${PGROLE}"
if [ "$PGROLE" = 'primary' ]; then
  echo "Running on a primary. Sleep 10 seconds to give standbys the upper hand."
  sleep 10
fi

/usr/local/bin/etcdctl lock wal-g "$SCRIPTDIR/backup.sh"
