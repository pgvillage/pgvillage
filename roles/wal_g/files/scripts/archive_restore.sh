#!/bin/bash

# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

/usr/local/bin/wal-g wal-fetch "$1" "$2"
