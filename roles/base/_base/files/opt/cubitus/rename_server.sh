#!/bin/bash

#-----------------------------------------------------------------------
#
#  R E N A M E _ S E R V E R . S H
#
#  On boot/demand, rename server and update config files to reflect
#  new .guruse.com name.
#
#  NOTE: Since script MAY be called at boot, ALWAYS return 0 to
#  avoid potential endless loop by /etc/rc.local
#
#-----------------------------------------------------------------------
#  IF:2013-03-19 -- Created
#  IF:2013-10-24 -- Updated
#-----------------------------------------------------------------------


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

# Split Old Server Name into its pieces
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
if ! [[ "$NEW_ENV" == "dev" || "$NEW_ENV" == "stg" || "$NEW_ENV" == "sls" || "$NEW_ENV" == "prd" ]]; then
	echo "ERROR: Invalid environment value (only allowed = dev stg sls prd) = $NEW_ENV" | /usr/bin/logger -t rename_server -s
	exit 0
fi

# Check that short host name is valid
if ! [[ ${#NEW_SRV} -gt 3 ]]; then
	echo "ERROR: Invalid host name (min 4 chars) = $NEW_SRV" | /usr/bin/logger -t rename_server -s
	exit 0
fi



#----------------------------
#
#  Validate Old Server Name
#
#----------------------------

#  Determine current server name
OLD_HOST=$(hostname -f | tr -d ' \n\t\r')
if ! grep -qs '\.guruse\.com' <<< "$OLD_HOST" ; then
	OLD_HOST=$(cat /etc/mailname | tr -d ' \n\t\r')
fi

# Not a valid server name
if ! grep -qs '\.guruse\.com' <<< "$OLD_HOST" ; then
	echo "ERROR: $OLD_HOST is an invalid server name" | /usr/bin/logger -t rename_server -s
	exit 0
fi

# Split Old Server Name into its pieces
IFS=$'\.' old_server=($(echo "$OLD_HOST"))
if [ ${#old_server[@]} != 4 ]; then
	echo "ERROR: Invalid dns server name = $OLD_HOST" | /usr/bin/logger -t rename_server -s
	exit 0
fi

#  Old Server Variables
OLD_SRV="${old_server[0]}"
OLD_ENV="${old_server[1]}"
OLD_HOST_UPPER=$(echo "$OLD_HOST" | tr '[:lower:]' '[:upper:]')




#----------------------------
#
#  Start Server Reset
#
#----------------------------


#  Reset hostname
cd /etc/
touch hostname
echo -n "$NEW_HOST" > /etc/hostname

#  Reset general files
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/hosts
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/mailname
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/postfix/canonical
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/postfix/main.cf
postmap /etc/postfix/canonical
service postfix restart

#  Reset monit files
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/monit/monitrc
sed -i "s/monit\-$OLD_SRV\.$OLD_ENV/monit\-$NEW_SRV\.$NEW_ENV/g" /etc/monit/monitrc

#  Reset collectd files
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/collectd/collectd.conf
sed -i "s/$OLD_HOST_UPPER/$NEW_HOST_UPPER/g" /etc/collectd/collectd.conf
sed -i "s/\.$OLD_ENV\./\.$NEW_ENV\./g" /etc/collectd/collectd.conf

#  Reset Apache files
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/apache2/*
sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/apache2/sites-available/*

#  Reset other config files
sed -i "s/\.$OLD_ENV\./\.$NEW_ENV\./g" /etc/nagios/nrpe.cfg
sed -i "s/\.$OLD_ENV\./\.$NEW_ENV\./g" /etc/rsyslog.conf
sed -i "s/\.$OLD_ENV\./\.$NEW_ENV\./g" /apps/statsd/config.js
sed -i "s/search $OLD_ENV\./search $NEW_ENV\./g" /etc/rc.local
sed -i "s/search $OLD_ENV\./search $NEW_ENV\./g" /etc/resolvconf/resolv.conf.d/base

#  Reset crontab
crontab -l | sed -e "s/$OLD_HOST_UPPER/$NEW_HOST_UPPER/g" | crontab -

#  Reset SSH keys
case $NEW_ENV in
	prd )
		echo "Resetting Prod SSH Keys..."
		sed -i '/\ Stg_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Stg_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /home/ubuntu/.ssh/authorized_keys
		;;
	stg )
		echo "Resetting Staging SSH Keys..."
		sed -i '/\ Prd_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Prd_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /home/ubuntu/.ssh/authorized_keys
		;;
	sls )
		echo "Resetting Sales SSH Keys..."
		sed -i '/\ Prd_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Stg_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Prd_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Stg_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Dev_GRS/d' /home/ubuntu/.ssh/authorized_keys
		;;
	*)
		echo "Resetting Dev SSH Keys..."
		sed -i '/\ Prd_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Stg_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /root/.ssh/authorized_keys
		sed -i '/\ Prd_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Stg_GRS/d' /home/ubuntu/.ssh/authorized_keys
		sed -i '/\ Sls_GRS/d' /home/ubuntu/.ssh/authorized_keys
		;;
esac

#  Remove "no root login" text from authorized_keys
sed -i 's/.*sleep\ 10\"\ //' /root/.ssh/authorized_keys
sed -i 's/.*sleep\ 10\"\ //' /home/ubuntu/.ssh/authorized_keys

#  Reset guruse status files
echo -n "$NEW_ENV" > /etc/guruse/server_environment
echo -n "$NEW_HOST" > /etc/guruse/server_name

#  Syslog entry
echo "OK: $OLD_HOST has been renamed $NEW_HOST" | /usr/bin/logger -t rename_server -s

#  Rebooting
if [[ "$REBOOT" == "y" ]]; then
	echo "OK: Rebooting $NEW_HOST ..." | /usr/bin/logger -t rename_server -s
	/sbin/shutdown -r now
	exit 0
fi

exit 0
