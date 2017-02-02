#!/bin/bash

#-----------------------------------------------------------------------
#
#  A M I _ B A C K U P . S H
#
#  Create AMI backups of this server and auto-delete older images
#
#-----------------------------------------------------------------------
#  IF:2013-12-01 -- Created
#  IF:2013-12-23 -- Updated
#-----------------------------------------------------------------------


#  Get server variables
SYS_TAG="aim_backup"
HOSTNAME=$(hostname -f)
INSTANCE_ID=$(/usr/bin/curl -s http://169.254.169.254/latest/meta-data/instance-id)
DATE=$(date "+%F")
IMAGE_NAME="$HOSTNAME backup ($DATE)"
IMAGE_DESC="$HOSTNAME automated backup $DATE ($INSTANCE_ID)"
AWS="/usr/local/bin/aws"


#  Determine # of days to keep backups
SERVER_LIST=/etc/guruse/backup.lst
SERVER=$(hostname -s)
DAYS=$(cat "$SERVER_LIST" | grep "$SERVER:" | cut -d":" -f2)

if [ $DAYS -gt 0 ]; then

	#------------------------------------
	#
	#  Create AMI
	#
	#------------------------------------
	AMI_ID=$($AWS ec2 create-image \
					--instance-id $INSTANCE_ID \
					--name "$IMAGE_NAME" \
					--description "$IMAGE_DESC" \
					--no-reboot \
					--no-dry-run \
					--output text)

	#  Record results
	EXIT=$(echo $?)
	if [ $EXIT == 0 ]; then
		#  Record AMI creation
		echo "SUCCESS: Image [$AMI_ID] created" | /usr/bin/logger -t $SYS_TAG -s

		#  Add user-generated tag for easy recognition
		$AWS ec2 create-tags \
				--resources $AMI_ID \
				--tags Key=Name,Value="$IMAGE_NAME" \
				--no-dry-run \
				--output text
	else
		echo "ERROR: Unable to backup [$INSTANCE_ID], error code [$EXIT]" | /usr/bin/logger -t $SYS_TAG -s
	fi


	#------------------------------------
	#
	#  Remove Old AMIs
	#
	#------------------------------------

	#  List of existing AMI ID/Description for this server
	AMI_LIST=$($AWS ec2 describe-images \
					--owners self \
					--output text | \
						grep "IMAGES" | \
						grep "$INSTANCE_ID" | \
						grep "automated backup" | \
						awk -F "\t" '{print $5,$3}')

	#  If AMIs found, loop thru list
	if [ -n "$AMI_LIST" ]; then
		#  Cut-over date for backups
		DATE_XDAYS=$(date +%F --date "$DAYS days ago")
		DATE_EPOCH=$(date --date="$DATE_XDAYS" +%s)

		#  Get arrays with AMI IDs and DateTimes
		AIM_ID_LIST=($(echo "${AMI_LIST}" | cut -d" " -f1))
		AIM_DT_LIST=($(echo "${AMI_LIST}" | cut -d" " -f5))

		TOTAL=${#AIM_ID_LIST[*]}
		for (( i=0; i<=$(( $TOTAL -1 )); i++ ))
		do
			AIM_ID=$(echo "${AIM_ID_LIST[$i]}")
			AIM_DT=$(echo "${AIM_DT_LIST[$i]}")
			AIM_EPOCH=$(date --date=$AIM_DT +%s)

			#  Delete AIM if older than cut-over date
			if (( $AIM_EPOCH <= $DATE_EPOCH )); then
				$AWS ec2 deregister-image \
						--image-id $AIM_ID \
						--no-dry-run \
						--output text

				#  Record results
				EXIT=$(echo $?)
				if [ $EXIT == 0 ]; then
					echo "SUCCESS: Deleting [$AIM_ID], taken on [$AIM_DT]" | /usr/bin/logger -t $SYS_TAG -s
				else
					echo "ERROR: Unable to deregister [$AIM_ID], error code [$EXIT]" | /usr/bin/logger -t $SYS_TAG -s
				fi
			fi
		done
	fi

fi

exit
