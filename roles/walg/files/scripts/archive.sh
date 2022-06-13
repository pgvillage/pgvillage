#!/bin/bash

# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

/usr/local/bin/wal-g-pg wal-push "$1"
