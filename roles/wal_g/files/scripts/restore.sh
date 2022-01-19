#!/bin/bash
set -ex

recovery_conf() {
  echo "recovery_target_action = promote";
  # Postgres biedt voor Point in time Recovery de mogelijkheid om een target xid, targettime of target name te gebruiken.
  # Dit script behandelt $2 als input en bepaat welke van de drie het is.
  # Deze functie zorgt dat de juiste info in postgresql.conf wordt opgenomen zodat recovery goed plaats vind.
  # Eventueel zorgt Patroni dat de config weer wordt opgeruimd als de instance na PITR weer live is.
  if [ "$RESTORETARGETTIME" ]; then
    echo "recovery_target_time = '$RESTORETARGETTIME'"
  elif [ "$RESTORETARGETXID" ]; then
    echo "recovery_target_xid = '$RESTORETARGETXID'"
  elif [ "$RESTORETARGETNAME" ]; then
    echo "recovery_target_name = '$RESTORETARGETNAME'"
  fi
}


earliest_backup() {
  # Dit commando geeft het eerste veld op de laatste terug. Dat is de naam van de laatste backup.
  /usr/local/bin/wal-g backup-list | sed -n '2{s/ .*//;p}'
}

latest_backup_before() {
  # Dit commando vergelijkt alle backups met RestoreDat en geeft de laatste backup voor die datum terug.
  /usr/local/bin/wal-g backup-list | awk -v RestoreDate="$1" '{if (FNR>1 && $2<=RestoreDate) {print $1}}' | tail -n1
}

latest_backup() {
  # Dit commando geeft het eerste veld op de laatste terug. Dat is de naam van de laatste backup.
  /usr/local/bin/wal-g backup-list | sed -n '${s/ .*//;p}'
}

# WAL-g config laden
eval $(sed '/#/d;s/^/export /' /etc/default/wal-g)

# PGRESTORE wordt ingesteld op:
# - parameter 1, of
# - zichzelf als hij al ingesteld was, of
# - PGDATA
PGRESTORE=${1:-${PGRESTORE:-$PGDATA}}
mkdir -p "${PGRESTORE}"

if [ -e "$PGRESTORE/PG_VERSION" ]; then
  echo "File $PGRESTORE/PG_VERSION exists. This is not an empty Datadirectory. Make sure this is OK, clean the folder, and then rerun this script."
  exit 1
fi

# Gebruik parameter $2 als input, of gebruik de env var RESTORETARGETINPUT als $2 niet gezet is.
RESTORETARGETINPUT="${2:-$RESTORETARGETINPUT}"

# Postgres biedt voor Point in time Recovery de mogelijkheid om een target xid, targettime of target name te gebruiken.
# Dit script behandelt $2 als input en bepaat welke van de drie het is.
# Deze functie zorgt dat de juiste info in postgresql.conf wordt opgenomen zodat recovery goed plaats vind.
# Eventueel zorgt Patroni dat de config weer wordt opgeruimd als de instance na PITR weer live is.
if [ -z "$RESTORETARGETINPUT" ]; then
  # Geen target meegegeven. Gebruik gewoon de laatste backup als target
  RESTORETARGET=$(latest_backup)
elif [[ "$RESTORETARGETINPUT" =~ ^[0-9]+$ ]]; then
  # target is een xid. 
  echo "$RESTORETARGETINPUT seems like an XID."
  echo "We cannot detect which backup to restore, so we restore the earliest and leave it up to recovery."
  echo "Alternatively you can restore a specific backup and manually set recovery_target_xid in postgresql.conf"
  RESTORETARGET=$(earliest_backup)
  RESTORETARGETXID=${RESTORETARGETINPUT}
else
  # Probeer als date te parsen. Als het niet, dan maar direct gebruiken als target.
  RESTORETARGETTIME=$(date -d "$RESTORETARGETINPUT" --rfc-3339 seconds) || RESTORETARGETTIME= && RESTORETARGET="${2}"
  if [ "$RESTORETARGETTIME" ]; then
    # Waarschijnlijk was $2 meegegeven (of RESTORETARGETTIME was gezet). Zoek de laatste backup voor die restore date.
    RESTORETARGET=$(latest_backup_before "$RESTORETARGETTIME")
  else
    echo "$RESTORETARGETINPUT does not seem like a date or XID. Expecting it is an recovery_target_name"
    echo "We cannot detect which backup to restore, so we restore the earliest and leave it up to recovery."
    echo "Alternatively you can restore a specific backup and manually set recovery_target_name in postgresql.conf"
    RESTORETARGET=$(earliest_backup)
    RESTORETARGETNAME=${RESTORETARGETINPUT}
  fi
fi

echo "Fetching backup from $RESTORETARGET"
/usr/local/bin/wal-g backup-fetch "$PGRESTORE" "$RESTORETARGET"
chmod 0700 "$PGRESTORE"

if [ "$PGRESTORE" != "$PGDATA" ]; then
  echo -e "port=5433\narchive_command = '/bin/true'" >> "$PGRESTORE/postgresql.conf"
fi

PGVERSION=$(cat "$PGDATA/PG_VERSION")
if [ "0$PGVERSION" -ge 12  ]; then
  touch "$PGRESTORE/recovery.signal"
  recovery_conf >> "$PGRESTORE/postgresql.conf"
else
  recovery_conf >> "$PGRESTORE/recovery.conf"
fi

"$PGBIN/pg_ctl" start -D "$PGRESTORE"
