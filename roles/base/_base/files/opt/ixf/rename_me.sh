#!/bin/bash

#-----------------------------------------------------------------------
#
#  R E N A M E _ M E . S H
#
#  On boot/demand, rename server and update config files to reflect
#  new .guruse.com name.
#
#  NOTE: Since script MAY be called at boot, ALWAYS return 0 to
#  avoid potential endless loop by /etc/rc.local
#
#-----------------------------------------------------------------------
#  IF:2013-11-18 -- Created
#  IF:2014-01-26 -- Updated
#-----------------------------------------------------------------------


#----------------------------
#
#  Allowed Environments
#
#----------------------------
ENVS=('dev' 'deva' 'devb' 'stg' 'stga' 'stgb' 'sls' 'slsa' 'slsb' 'stg' 'stga' 'stgb' 'prd' 'prda' 'prdb')


#----------------------------
#
#  Validate Parameters
#
#----------------------------

#  Get new server name via a parameter
if [ $# != 2 ]; then
	echo -e "Usage: $0 host.env.guruse.com reboot=Y|N"
	exit 0
fi

#  Determine reboot or not
REBOOT=$(echo $2 | tr '[:upper:]' '[:lower:]')
#  Verify that environment is an approved value
if ! [[ "$REBOOT" == "y" || "$REBOOT" == "n" ]]; then
	echo "ERROR: Invalid reboot value (only allowed = y Y n N) = $REBOOT" | /usr/bin/logger -t rename_server -s
	exit 0
fi


#----------------------------
#
#  Validate New Server Name
#
#----------------------------

#  Determine new server name
NEW_HOST=$(echo $1 | tr '[:upper:]' '[:lower:]')
NEW_HOST=$(echo $NEW_HOST | tr -d ' \n\t\r')
if ! grep -qs '\.guruse\.com' <<< "$NEW_HOST" ; then
	echo "ERROR: $NEW_HOST is not a valid guruse.com server name" | /usr/bin/logger -t rename_server -s
	exit 0
fi

# Split Server Name into its pieces
IFS=$'\.' new_server=($(echo "$NEW_HOST"))
if [ ${#new_server[@]} != 4 ]; then
	echo "ERROR: Invalid dns server name = $NEW_HOST" | /usr/bin/logger -t rename_server -s
	exit 0
fi

#  New Server Variables
NEW_SRV="${new_server[0]}"
NEW_ENV="${new_server[1]}"
NEW_HOST_UPPER=$(echo "$NEW_HOST" | tr '[:lower:]' '[:upper:]')

#  Verify that environment is an approved value
if ! [[ " ${ENVS[@]} " =~ " ${NEW_ENV} " ]]; then
	env_list=""
	for i in "${ENVS[@]}"; do env_list="$env_list '$i'"; done
	echo "ERROR: Invalid environment value (only allowed = $env_list) = $NEW_ENV" | /usr/bin/logger -t rename_server -s
	exit 0
fi

# Check that short host name is valid
if ! [[ ${#NEW_SRV} -gt 3 ]]; then
	echo "ERROR: Invalid host name (min 4 chars) = $NEW_SRV" | /usr/bin/logger -t rename_server -s
	exit 0
fi


#----------------------------
#
#  Start Server Reset
#
#----------------------------

#  Reset hostname
cd /etc/
touch hostname
echo -n "$NEW_HOST" > /etc/hostname

#  Remove "no root login" restriction from authorized_keys
sed -i 's/.*sleep\ 10\"\ //' /root/.ssh/authorized_keys
sed -i 's/.*sleep\ 10\"\ //' /home/ubuntu/.ssh/authorized_keys

#  Syslog entry
echo "OK: Server has been renamed $NEW_HOST" | /usr/bin/logger -t rename_server -s

#  Rebooting
if [[ "$REBOOT" == "y" ]]; then
	echo "OK: Rebooting $NEW_HOST ..." | /usr/bin/logger -t rename_server -s
	/sbin/shutdown -r now
	exit 0
fi

exit 0
