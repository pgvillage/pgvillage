#!/bin/bash

/opt/wal-g/scripts/delete.sh

# WAL-g config laden
eval $(sed '/#/d;s/^/export /' /etc/default/wal-g)

echo -e "\nPushing backup"
/usr/local/bin/wal-g backup-push $PGDATA

/opt/wal-g/scripts/delete.sh
