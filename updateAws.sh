#!/bin/bash
# Script retrieves the current IP Address from a standard German Telecom Router and
# uses this to update an Amazon AWS Route 53 zone
CURL="$(command -v curl) -ks" || CURL="/usr/bin/curl -ks"
TMPFILE=/tmp/`date +%Y%m%d_%H%M%S`.awsdns
AWSBIN=$(command -v aws) || AWSBIN=/usr/local/bin/aws

# Amazon AWS hosted zone ID
ZONEID=<YOUR ZONEID HERE>
# A record for your dyndns name
DYNHOST=<YOUR HOSTNAME HERE>

# Test: Can we use awscli? (i.e is it configured?)
aws ec2 describe-regions --region us-east-1 >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "AWS CLI not available/configured or cannot connect!"
  exit 1
fi

# a public name server to check what the currently registered IP is
DNS=8.8.8.8

# GET CURRENT IP
# IP=`$CURL ifconfig.co`
IP=`$CURL checkip.amazonaws.com`

# FIND CURRENTLY REGISTERED IP
REMOTEIP=`dig +short $DYNHOST @$DNS`

if [ "$REMOTEIP" == "$IP" -o "$REMOTEIP" == "" ]
then
   echo "$IP still current" > /dev/null
else
   echo "we need to update"
   #CREATE AWS UPDATE RECORD
   cat <<UPDATE-JSON > $TMPFILE
   {
     "Comment": "dyndns",
     "Changes": [
       {
         "Action": "UPSERT",
         "ResourceRecordSet": {
           "Name": "$DYNHOST",
           "Type": "A",
           "TTL": 300,
           "ResourceRecords": [
             {
               "Value": "$IP"
             }
           ]
         }
       }
     ]
   }
UPDATE-JSON
   echo "Updating IP to $IP"
   # do the update via AWS cli
   ${AWSBIN} route53 change-resource-record-sets --hosted-zone-id $ZONEID --change-batch file://$TMPFILE
   rm $TMPFILE
fi
