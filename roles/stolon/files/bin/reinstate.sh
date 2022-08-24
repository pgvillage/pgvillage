#!/bin/bash
echo 'This is a brute force lets start over script'

echo 'Stopping local stolon-keeper.service'
systemctl stop stolon-keeper.service

echo 'Sourcing stolonctl parameters (from /etc/sysconfig/stolon-stkeeper)'
# Note that this command also sources $STKEEPER_DATA_DIR, renamed as $STOLONCTL_DATA_DIR
eval $(sed -e '/#/d;s/^STKEEPER/export STOLONCTL/' /etc/sysconfig/stolon-stkeeper )
echo 'Removing local keeper from etcd'
/usr/local/bin/stolonctl removekeeper $(hostname | tr '-' '_')

echo 'brute force remove local datadir'
rm -rf "$STOLONCTL_DATA_DIR"/{postgres/*,dbstate,keeperstate,lock}
rm -rf "$STOLONCTL_WAL_DIR"/*

echo 'Starting local stolon-keeper.service'
systemctl start stolon-keeper.service
