#!/bin/bash
set -e

function list_backups() {
	echo "BACKUP:"
	echo "======="
	/usr/local/bin/wal-g-pg backup-list
	echo
	echo "WAL:"
	echo "===="
	/usr/local/bin/wal-g-pg wal-show
}

SCRIPTDIR=$(dirname $0)

# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

list_backups
