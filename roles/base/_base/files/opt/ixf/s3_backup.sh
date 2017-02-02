#!/bin/bash
#===============================================================================
#
#  S 3 _ B A C K U P . S H
#
#  Backup to S3 key config files and folders
#
#===============================================================================

#  Variables
SYS_TAG="s3_backup"
SERVER=$(hostname -s)
DAY=$(date +%A)
ENVIRONMENT=$(cat /etc/ixf/server_environment)
SERVER_LIST=/etc/ixf/backup.lst
FOLDERS=$(cat "$SERVER_LIST" | grep "$SERVER:" | cut -d":" -f4)
LOG_FILE="/var/log/s3_backup.log"
S3CMD="/usr/bin/s3cmd"

#  Get list of folders into array
arrayname=($(echo "$FOLDERS"))

#  Loop and backup each folder
if [ ${#arrayname[@]} -gt 0 ]; then
	for m in "${arrayname[@]}"
	do
		#  Determine that folder exists
		if [ -d ${m} ]; then
			#  Copy to S3 folder and log to file
			$S3CMD sync ${m}/ s3://ixf-sys/backups/$ENVIRONMENT/$SERVER/$DAY${m}/ 2>&1 >> $LOG_FILE
		else
			echo "ERROR: Invalid directory = ${m}" | /usr/bin/logger -t $SYS_TAG -s
		fi
	done
else
	echo "ERROR: Invalid directories = $FOLDERS" | /usr/bin/logger -t $SYS_TAG -s
fi

#  Backup crontab
cd /tmp
/usr/bin/crontab -l >> crontab.txt
$S3CMD sync crontab.txt s3://ixf-sys/backups/$ENVIRONMENT/$SERVER/$DAY/crontab.txt >> $LOG_FILE 2>&1
rm -rf crontab.txt

#  Create dir log of days when executed
mkdir -p ~/.s3_history
touch ~/.s3_history/`date +%F__%A_%p__%I.%M.%p`
$S3CMD sync ~/.s3_history/ s3://ixf-sys/backups/$ENVIRONMENT/$SERVER/.s3_history/ >> $LOG_FILE 2>&1

exit
