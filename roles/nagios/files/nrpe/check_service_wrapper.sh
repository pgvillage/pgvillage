#!/usr/bin/env bash

# Author: Daniel
path=`dirname $0`
ret=0
error='ERROR: '
code='OK: '

while getopts "s:" opt; do
        case ${opt} in
                s ) # process option s
                        args=$OPTARG
                ;;
                h ) echo "Usage: cmd [-h] [-s serviceA,serviceB...]"
                ;;
        esac
done

for service in `echo $args|sed 's/,/ /g'` ; do
        $path/check_service.sh -s $service > /dev/null 2>&1
        res=$?
        if [ "$res" -eq 0 ] ; then
                code="$code $service OK;"
        else
                error="$error $service NOK;"
                ret=2
        fi
done

if [ $ret -ne 0 ] ; then
        code=$error
fi

echo $code
exit $ret
