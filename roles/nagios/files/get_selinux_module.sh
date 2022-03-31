#!/bin/bash
cd $(mktemp -d)
echo "Running from $PWD"
sealert -l "*" | sed -n '/^# ausearch/{s/^# //;p}' | sort -u > get_audits.sh
bash ./get_audits.sh
cat *.te > mymodule.te
