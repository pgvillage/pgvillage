#!/bin/bash

set -ex

function unpartitioned() {
  for d in /dev/sd?; do
    ls $d? >/dev/null 2>&1 || echo $d
  done
}

function get_uuid() {
  blkid "${1}" -o export | awk 'BEGIN{FS="="}$1~/^UUID$/{print $2}'
}

function partition_and_mount() {
  DISK=${1}
  MP=${2}
  UUID=$(get_uuid "${DISK}1")
  mkdir -p "${MP}"
  echo "UUID=${UUID} ${MP} ext4 defaults 0 0" >> /etc/fstab
  mount -a
}

PGDATAMOUNTPOINT=${PGDATAMOUNTPOINT:-/var/lib/pgsql/15/data}
PGWALMOUNTPOINT=${PGWALMOUNTPOINT:-/var/lib/pgsql/15/wal}


cd $(mktemp -d)
pwd

touch sizes.lst

unpartitioned | while read d; do
  echo Partitioning $d
  parted -s "$d" mklabel gpt
  parted -s "$d" -- mkpart postgres 1 -1
  mkfs.ext4 "${d}1"
  SIZE=$(parted "$d" unit B print | sed -n '/^Disk \/dev\/sd.:/{s/[^0-9]//g;p}')
  echo "$SIZE $d" >> sizes.lst
done

sort -n sizes.lst | awk '{print $2}' > sizesorteddisks.lst

case "$(wc -l sizes.lst | awk '{print $1}')" in
	0)
		echo "Nothing to do"
		exit 0
		;;
	1)
		PGDATADISK=$(tail -n1 sizesorteddisks.lst)
		partition_and_mount "${PGDATADISK}" "${PGDATAMOUNTPOINT}"
		;;
	2)
		PGDATADISK=$(tail -n1 sizesorteddisks.lst)
		partition_and_mount "${PGDATADISK}" "${PGDATAMOUNTPOINT}"
		PGWALDISK=$(head -n1 sizesorteddisks.lst)
		partition_and_mount "${PGWALDISK}" "${PGWALMOUNTPOINT}"
		;;
	*)
		echo "more disks then I expected"
		exit 1
esac
echo Done
