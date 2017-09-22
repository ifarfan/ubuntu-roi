#!/bin/bash -l
#===============================================================================
#
#  S E N T R Y _ U D P . S H
#
#  Control Sentry UDP
#
#===============================================================================

if [ $# -lt 1 ]; then
    echo "Usage : $0 up | down"
    exit 1
fi

##  Path to sentry
SENTRYDIR="/opt/sentry"

case "$1" in
  "up")
      if ! ps aux | grep [s]'entry.conf.py start udp' > /dev/null; then
         #  Start environment and fork/send Sentry UDP to background
         source $SENTRYDIR/bin/activate
         (sentry --config=/etc/sentry.conf.py start udp > $SENTRYDIR/output_udp.log 2>&1 &)
      else
         echo "$0 already running..."
      fi
      ;;
  "down")
      if ps aux | grep [s]'entry.conf.py start udp' > /dev/null; then
         #  Kill Sentry UDP
         pkill -f 'sentry.conf.py start udp'
      else
         echo "$0 NOT running..."
      fi
      ;;
  *)
      echo "$0 Unknown parameter: $1"
      exit 1
      ;;
esac
exit 0
