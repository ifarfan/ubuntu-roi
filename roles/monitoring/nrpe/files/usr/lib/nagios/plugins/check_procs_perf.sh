#!/bin/bash

RET=`/usr/lib/nagios/plugins/check_procs "$@"`
STATUS=$?

getopts c:w: name "$@"
eval $name=$OPTARG
getopts c:w: name "$@"
eval $name=$OPTARG

VAL=`echo $RET | sed 's/^.*: \([0-9]*\) process.*$/\1/'`
echo "$RET|processes=$VAL;$w;$c;0;"
exit $STATUS
