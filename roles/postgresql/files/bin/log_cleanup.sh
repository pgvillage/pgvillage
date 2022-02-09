#!/bin/bash
set -e

RETAIN=$1
ZIP=$2
LOGDIR=$3

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
