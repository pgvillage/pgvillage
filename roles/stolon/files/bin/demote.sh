#!/bin/bash
echo 'Sourcing stolonctl parameters (from /etc/sysconfig/stolon-stsentinel)'
eval $(sed -e '/#/d;s/^STSENTINEL/export STOLONCTL/' /etc/sysconfig/stolon-stsentinel )

echo 'Switchover to other node if this is the master'
/usr/local/bin/stolonctl failkeeper $(hostname | tr '-' '_')
