#!/bin/bash -l
#===============================================================================
#
#  S E N T R Y _ H T T P . S H
#
#  Control Sentry HTTP/Web
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
      if ! ps aux | grep [g]'unicorn\: master \[Sentry\]' > /dev/null; then
         #  Start environment and fork/send Sentry Web to background
         source $SENTRYDIR/bin/activate
         (sentry --config=/etc/sentry.conf.py start http > $SENTRYDIR/output_http.log 2>&1 &)
      else
         echo "$0 already running..."
      fi
      ;;
  "down")
      if ps aux | grep [g]'unicorn\: master \[Sentry\]' > /dev/null; then
         #  Kill Sentry HTTP/Web
         pkill -f 'gunicorn\: master \[Sentry\]'
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
