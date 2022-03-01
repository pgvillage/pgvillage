#!/bin/bash
set -e

# Dont ignore 'hidden files and folders (starting with '.').
shopt -s dotglob nullglob

CURSRC=${STKEEPER_PGDATA_DIR:-/data/postgres/data/stolon/postgres}/pg_wal
if [ ! -e "$CURSRC" ]; then
  echo "$CURSRC does not exist yet"
  exit 0
fi
DEST=${STKEEPER_PGWAL_DIR:-/data/postgres/wal/stolon}
CURDEST=$(readlink -f "${CURSRC}")
if [ "$CURDEST" = "$DEST" ]; then
  echo "$CURDEST already is $DEST"
else
  echo "Removing old $DEST if it exists"
  rm -rf "$DEST"/*

  echo "Moving $CURSRC to $DEST"
  mv "$CURSRC"/* "$DEST/"

  echo "Symlinking $DEST to $CURSRC"
  rmdir "$CURSRC"
  ln -s "$DEST" "$CURSRC"

  echo Done
fi
