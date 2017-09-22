#!/bin/bash

#===============================================================================
#
#  C H E C K _ O P E N _ F I L E S . S H
#
#  Find open files by user, pid or both
#
#===============================================================================
#  IF: 2014-07-22 -- Created
#  IF: 2014-07-28 -- Updated counts
#===============================================================================

PROGNAME=$(/usr/bin/basename $0)

print_usage() {
    echo "Usage: $PROGNAME [-u <username> | -f <pidfile> -w -c]"
    echo "Example:"
    echo "$PROGNAME -u tomcat -w 85 -c 95"
    echo "$PROGNAME -f /var/run/ntpd.pid -w 3 -c 5"
    echo "$PROGNAME -u www-data -f /var/run/apache2.pid -w 15 -c 20"
}

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

while getopts ":u:f:w:c:" o; do
    case "${o}" in
        u)
            USERNAME=${OPTARG}
            USER_EXISTS=$(/usr/bin/id $USERNAME &> /dev/null)$?
            if [ $USER_EXISTS -ne 0 ]; then
                print_usage
                echo -e "\nUNKNOWN: User $USERNAME does not exist!"
                exit $STATE_UNKNOWN
            fi
            ;;
        f)
            PIDFILE=${OPTARG}
            if [ ! -f $PIDFILE ]; then
                print_usage
                echo -e "\nUNKNOWN: File $PIDFILE does not exist!"
                exit $STATE_UNKNOWN
            fi
            ;;
        w)
            WARN=${OPTARG}
            if [[ ! $WARN =~ ^[0-9]+$ ]]; then
                print_usage
                echo -e "\nUNKNOWN: Invalid -w value: $WARN"
                exit $STATE_UNKNOWN
            fi
            ;;
        c)
            CRIT=${OPTARG}
            if [[ ! $CRIT =~ ^[0-9]+$ ]]; then
                print_usage
                echo -e "\nUNKNOWN: Invalid -c value: $CRIT"
                exit $STATE_UNKNOWN
            fi
            ;;
        \?)
            print_usage
            exit $STATE_UNKNOWN
            ;;
        :)
            print_usage
            echo -e "\nUNKNOWN: -$OPTARG requires an argument."
            exit $STATE_UNKNOWN
            ;;
        *)
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
done
shift $((OPTIND-1))

# #  Validate values
# if [ -z "${USERNAME}" ] || [ -z "${PIDFILE}" ] || [ -z "${WARN}" ] || [ -z "${CRIT}" ]; then
#     print_usage
#     exit $STATE_UNKNOWN
# fi

echo "u = ${USERNAME}"
echo "f = ${PIDFILE}"
echo "w = ${WARN}"
echo "c = ${CRIT}"

echo "MASTER_PID = ${MASTER_PID}"
echo "MASTER_FILES = ${MASTER_FILES}"
echo "SLAVES_FILES = ${SLAVES_FILES}"

# Username and pidfile provided
if [ ! -z "${USERNAME}" ] && [ ! -z "${PIDFILE}" ]; then
    echo -e "\n username + pidfile"

    # Find PIDs
    MASTER_PID=$(/bin/cat $PIDFILE)
    SLAVES_PID=$(/usr/bin/pgrep -P $MASTER_PID | tr '\012' , | sed 's/,$//')
    ALL_PIDS=$(echo "$SLAVES_PID$MASTER_PID")
    # Find Open Files
    MASTER_FILES=$(/usr/bin/lsof -p $MASTER_PID | wc -l)
    SLAVES_FILES=$(/usr/bin/lsof -u $USERNAME -p $SLAVES_PID | wc -l)
    ALL_FILES=$(/usr/bin/lsof -u $USERNAME -p $ALL_PIDS | wc -l)
    MSG="(USER: $USERNAME, PIDs: $ALL_PIDS)"
fi

# Only pidfile provided
if [  -z "${USERNAME}" ] && [ ! -z "${PIDFILE}" ]; then
    echo -e "\n pidfile only"

    # Find PIDs
    MASTER_PID=$(/bin/cat $PIDFILE)
    SLAVES_PID=$(/usr/bin/pgrep -P $MASTER_PID | tr '\012' , | sed 's/,$//')
    ALL_PIDS=$(echo "$SLAVES_PID$MASTER_PID")
    # Find Open Files
    MASTER_FILES=$(/usr/bin/lsof -p $MASTER_PID | wc -l)
    SLAVES_FILES=$(/usr/bin/lsof -p $SLAVES_PID | wc -l)
    ALL_FILES=$(/usr/bin/lsof -p $ALL_PIDS | wc -l)
    MSG="(PIDs: $ALL_PIDS)"
fi

# Only username provided
if [ ! -z "${USERNAME}" ] && [ -z "${PIDFILE}" ]; then
    echo -e "\n username only"

    ALL_FILES=$(/usr/bin/lsof -u $USERNAME | wc -l)
    MSG="(USER: $USERNAME)"
fi


# Determine open files
if [ $ALL_FILES -lt $WARN ]; then
    printf "OK: $ALL_FILES files open $MSG|open_files=$ALL_FILES;$WARN;$CRIT;0;\n"
    exit $STATE_OK
else
    if [ $ALL_FILES -ge $WARN ] && [ $ALL_FILES -le $CRIT ]; then
        printf "WARNING: $ALL_FILES files open $MSG|open_files=$ALL_FILES;$WARN;$CRIT;0;\n"
        exit $STATE_WARNING
    elif [ $ALL_FILES -ge $CRIT ]; then
        printf "CRITICAL: $ALL_FILES files open $MSG|open_files=$ALL_FILES;$WARN;$CRIT;0;\n"
        exit $STATE_CRITICAL
    fi
fi
