#!/bin/bash
set -e
eval $(sed '/#/d;s/^/export /' /etc/default/stolon)
/usr/local/bin/stolonctl status || stolonctl init -y
