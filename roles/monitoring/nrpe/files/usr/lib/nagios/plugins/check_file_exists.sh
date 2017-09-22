#! /bin/bash
#
# Author : Diego Martin Gardella [dgardella@gmail.com]
# Desc : Plugin to verify if a file exists
#
#

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

. $PROGPATH/utils.sh

if [ "$1" = "" ]; then
    echo -e "Use : $PROGNAME <file_name> -- Ex : $PROGNAME /etc/hosts \n "
    exit $STATE_UNKNOWN
fi

if [ -f $1 ]; then
    echo "OK - File $1 exists|file=1"
    exit $STATE_OK
else
    echo "CRITICAL - File $1 Does NOT exist|file=0"
    exit $STATE_CRITICAL
fi
