#!/bin/bash

# $1 = Virtual Service IP (VIP)
# $2 = Virtual Service Port (VPT)
# $3 = Real Server IP (RIP)
# $4 = Real Server Port (RPT)
# $5 = Check Source IP

export PATH=/usr/local/sbin:/sbin:/bin:/usr/sbin:/usr/bin

curl http://localhost:8080/v1/standbys 2>/dev/null | grep -q "$3"
