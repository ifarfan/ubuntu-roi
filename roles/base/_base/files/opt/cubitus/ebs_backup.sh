#!/bin/bash -l

#  Load EC2 Variables with '-l' flag above
#  Variables are stored in ~/.profile

#  Determine if EC2-API is installed
if ! which ec2-describe-instances &> /dev/null;
then
   echo "Unable to find ec2-api commands"
   exit 1
fi


#  Set Variables
SERVER=$(hostname)
DATE=$(date +%F' @ '%I%P)
COUNT=0

#  Get Instance ID for this server
INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)

#  Get Volumes attached to this instance -- ignore root disk
VOLUME_LIST=$(ec2-describe-instances $INSTANCE_ID | grep -v '/dev/sda1' | awk '/vol-*/ {print $3}')

# If EBS volumes found, snap them
if [ -n "$VOLUME_LIST" ];
then

    #  Force writes to disk
    echo -e '\nFlushing Disk'
    echo -e '========================='
    sync; sync; sync


    #  Loop thru list of Volumes
    echo -e '\nStarting EBS Snapshots...'
    echo -e '========================='
    for VOLUME in $(echo $VOLUME_LIST);
    do
        let "COUNT++"
        DISK=$(ec2-describe-volumes $VOLUME | awk '/dev/ {print $4}' | sed -e 's/\/dev\///g')
        CMD=$(ec2-create-snapshot $VOLUME -d "$SERVER auto backup $DATE disk$COUNT [$DISK] ($INSTANCE_ID)")
        echo $CMD
    done

fi


#  Cut-over date for backups
DATE_XDAYS=`date +%Y-%m-%d --date '7 days ago'`
DATE_EPOCH=`date --date="$DATE_XDAYS" +%s`

#  List of existing snapshots/datetimes for this server
SNAPSHOT_LIST=$(ec2-describe-snapshots | grep "$INSTANCE_ID" | grep "auto backup" | grep "completed" | awk '{print $2,$5}')

#  If snapshots found, loop thru list
if [ -n "$SNAPSHOT_LIST" ];
then

    echo -e '\nDeleting Old Snapshots...'
    echo -e '================='

    #  Get arrays with Snap IDs and DateTimes
    SNAP_ID_LIST=($(echo "${SNAPSHOT_LIST}" | cut -d" " -f1))
    SNAP_DT_LIST=($(echo "${SNAPSHOT_LIST}" | cut -d" " -f2))

    TOTAL=${#SNAP_ID_LIST[*]}
    for (( i=0; i<=$(( $TOTAL -1 )); i++ ))
    do
        SNAP_ID=$(echo "${SNAP_ID_LIST[$i]}")
        SNAP_DT=$(echo "${SNAP_DT_LIST[$i]}" | awk -F "T" '{printf "%s\n", $1}')
        SNAP_EPOCH=`date --date=$SNAP_DT +%s`

        #  Delete snapshot if older than cut-over date
        if (( $SNAP_EPOCH <= $DATE_EPOCH ));
        then
            echo "Deleting [$SNAP_ID], taken on [$SNAP_DT]"
            CMD=$(ec2-delete-snapshot $SNAP_ID)
            echo $CMD
        fi
    done

fi

exit 0
