#!/bin/bash
set -e

function log_cleanup() {
  echo "Deleting all files in '$WALG_LOG_FOLDER' older than $WALG_LOG_RETENTION_DAYS days."
  find "$WALG_LOG_FOLDER" -mtime "+$WALG_LOG_RETENTION_DAYS" -delete
  
  echo "Zipping all non-gzip files in '$WALG_LOG_FOLDER' older than $WALG_LOG_ZIP_DAYS days."
  find "$WALG_LOG_FOLDER" -mtime "+$WALG_LOG_ZIP_DAYS" | while read f; do
    [[ "$f" =~ .*\.gz ]] && continue
    echo "gzip $f"
    gzip $f
  done
}

# WAL-g config laden
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

# log output to a logfile in the logdir
WALG_LOG_FOLDER=${WALG_LOG_FOLDER:-/var/log/wal-g}
WALG_LOGFILE="$WALG_LOG_FOLDER/$(date +%Y%m%d)_$(basename $0 .sh).log"
TMPLOGFILE=$(mktemp)

log_cleanup 2>&1 | tee -a "$WALG_LOGFILE" > "$TMPLOGFILE"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  cat "$TMPLOGFILE"
  exit 1
fi
