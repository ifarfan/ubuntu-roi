#!/bin/bash -l
#  Load S3 Variables with '-l' flag above Variables are stored in ~/.profile

#===============================================================================
#
#  R E C L A I M _ E I P . S H
#
#  On boot/demand, re-attach back EIP granted to this server based
#  off public, fqdn DNS name (i.e., server01.prd.guruse.com).
#
#  NOTE: Since script WILL be called at boot, ALWAYS return 0 to
#  avoid potential endless loop by /etc/rc.local
#
#===============================================================================
#  IF:2013-03-03 -- Created
#===============================================================================


#
#  Get server variables
#
HOST_NAME=$(hostname -f)
HOST_IP_EXT=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
HOST_IP_INT=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOST_DNS_NAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
HOST_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

#  Server has an assigned ".guruse.com" host name
if grep -qs 'guruse\.com' <<< "$HOST_NAME" ; then
	# Find external DNS/IP for LIVE server by querying Google's DNS: 8.8.4.4
	IFS=$'\n' array=($(dig @8.8.4.4 $HOST_NAME -t A +short))

	# Invalid dig output
	if [ ${#array[@]} != 2 ]; then
		echo "ERROR: Invalid dig output = ${array[$@]}" | /usr/bin/logger -t reclaim_ip -s
		exit 0
	fi

	# Extract values off array
	LIVE_DNS_NAME="${array[0]}"
	LIVE_IP_EXT="${array[1]}"

	# External and Internal IPs match
	if [ "$LIVE_IP_EXT" == "$HOST_IP_EXT" ]; then
		# This server is already LIVE -- All Good!
		echo "OK: $HOST_NAME ALREADY associated with public IP $LIVE_IP_EXT" | /usr/bin/logger -t reclaim_ip -s
		exit 0
	else
		# Check if another EC2 instance is currently associated with this EIP
		RESPONSE_TXT=$(ec2-describe-addresses $LIVE_IP_EXT)
		if ! grep -qs 'ADDRESS' <<< "$RESPONSE_TXT" ; then
			# Invalid response from ec2-describe cmd
			echo "ERROR: Invalid response for EIP $LIVE_IP_EXT, $RESPONSE_TXT" | /usr/bin/logger -t reclaim_ip -s
			exit 0
		fi

		# Determine current instance ID holding EIP
		LIVE_INSTANCE_ID=$(echo "$RESPONSE_TXT" | cut -f3)
		if [ "${#LIVE_INSTANCE_ID}" == 0 ]; then
			# EIP is free!! Attach Live External IP to this machine
			ec2-associate-address -i $HOST_INSTANCE_ID $LIVE_IP_EXT
			sleep 10
			if ec2-describe-addresses $LIVE_IP_EXT | grep -qs "$HOST_INSTANCE_ID"; then
			   # EIP has been claimed by this server -- Good Times!
			   echo "OK: $HOST_NAME has been successfully associated with public IP $LIVE_IP_EXT" | /usr/bin/logger -t reclaim_ip -s
			   exit 0
			else
			   # Couldn't associate EIP to this server -- Arrgggh!
			   echo "ERROR: Unable to associate $LIVE_IP_EXT with $HOST_NAME" | /usr/bin/logger -t reclaim_ip -s
			   exit 0
			fi
		else
			if grep -qs 'i\-' <<< "$LIVE_INSTANCE_ID" ; then
			   # Determine Instance holding EIP
			   echo "WARN: $LIVE_IP_EXT associated with another instance, ID $LIVE_INSTANCE_ID" | /usr/bin/logger -t reclaim_ip -s
			   exit 0
			else
			   # Got invalid instance-id from ec2-cmd
			   echo "ERROR: Invalid Instance ID for EIP $LIVE_IP_EXT, $LIVE_INSTANCE_ID" | /usr/bin/logger -t reclaim_ip -s
			   exit 0
			fi
		fi

	fi
fi

# Server hasn't been configured -- Meh!
echo "WARN: $HOST_NAME has not been configured yet" | /usr/bin/logger -t reclaim_ip -s
exit 0