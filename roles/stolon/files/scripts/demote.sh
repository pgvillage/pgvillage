#!/bin/bash
echo 'Switchover to other node if this is the master'
/usr/local/bin/stolonctl failkeeper $(hostname | tr '-' '_')
