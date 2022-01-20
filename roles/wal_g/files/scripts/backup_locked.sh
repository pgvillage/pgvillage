#!/bin/bash
set -e

# WAL-g config laden (bevat ook PG config)
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

PGROLE=$(psql -tc "select case when pg_is_in_recovery() then 'standby' else 'primary' end;" | xargs)
echo "Postgres role is ${PGROLE}"
if [ "$PGROLE" = 'primary' ]; then
  echo "Running on a primary. Sleep 10 seconds to give standbys the upper hand."
  sleep 10
fi

/usr/local/bin/etcdctl lock wal-g /opt/wal-g/scripts/backup.sh
