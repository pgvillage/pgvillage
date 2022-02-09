#!/bin/bash
set -e

RETAIN=${WALG_LOG_RETENTION_DAYS:-14}
ZIP=${WALG_LOG_ZIP_DAYS:-2}
LOGDIR=${WALG_LOG_FOLDER:-/var/log/wal-g}

# log output to a logfile in the logdir
exec >> "$WALG_LOG_FOLDER/$(date +%Y%m%d)_$(basename $0 .sh).log"

echo "Deleting all files in '$LOGDIR' older than $RETAIN days."
find "$LOGDIR" -mtime "+$RETAIN" -delete

echo "Zipping all non-gzip files in '$LOGDIR' older than $ZIP days."
find "$LOGDIR" -mtime "+$ZIP" | while read f; do
  [[ "$f" =~ .*\.gz ]] && continue
  echo "gzip $f"
  gzip $f
done
