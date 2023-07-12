#!/bin/bash

TagKey="Name"
TagValue="tag_value_goes_here"
aws_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")
error_log=$(mktemp)
operations_log=$(mktemp)
RDSDatabaseARNIdentifier=$(aws --region "$aws_region" resourcegroupstaggingapi get-resources --resource-type-filters rds:db --query "ResourceTagMappingList[?Tags[? Key == '$TagKey' && Value == '$TagValue']].ResourceARN" --output=text)
RDSDatabaseDBIdentifier=$(aws rds --region "$aws_region" describe-db-instances --db-instance-identifier "$RDSDatabaseARNIdentifier" --query "*[].{DBInstanceIdentifier:DBInstanceIdentifier}" --output text)


# Set initial status for exit
error=0 

slack_webhook="https://slack.webhook.url/goes/here"

SendToSlack(){

# Original script from here:
# http://blog.getpostman.com/2015/12/23/stream-any-log-file-to-slack-using-curl/

cat "$1" | while read LINE; do
  (echo "$LINE" | grep -e "$3") && curl -X POST --silent --data-urlencode "payload={\"text\": \"$(echo $LINE | sed "s/\"/'/g")\"}" "$2";
done

}

# Create logfiles to send to Slack

touch "$error_log"
touch "$operations_log"

echo "$(date) - Creating manual database snapshot of ${RDSDatabaseDBIdentifier}" >> "$operations_log"
RDSDatabaseSnapshot=$( aws rds create-db-snapshot --region "$aws_region" --db-snapshot-identifier $RDSDatabaseDBIdentifier-manual-$(date +"%Y%m%d%H%M")-$(echo $RANDOM) --db-instance-identifier $RDSDatabaseDBIdentifier --query 'DBSnapshot.[DBSnapshotIdentifier]' --output text )
aws rds wait db-snapshot-completed  --region "$aws_region" --db-snapshot-identifier "$RDSDatabaseSnapshot"
if [[ $? -eq 0 ]]; then
    echo "$(date) - Successfully created ${RDSDatabaseSnapshot} database snapshot from $RDSDatabaseDBIdentifier." >> "$operations_log"
else
    echo "$(date) - ERROR! Failed to create snapshot of ${RDSDatabaseDBIdentifier}!" >> "$error_log"
    error=1
fi


if [[ -r "$operations_log" ]]; then
   echo "Sending $operations_log to Slack"
   SendToSlack "$operations_log" ${slack_webhook}
   echo "Sent $operations_log to $slack_webhook. Ending run."
else
   echo "Operations log was empty. Nothing to send to Slack."
fi

if [[ -r "$error_log" ]]; then
   echo "Sending $error_log to Slack"
   SendToSlack "$error_log" ${slack_webhook}
   echo "Sent $error_log to $slack_webhook. Ending run."
else
   echo "Error log was empty. Nothing to send to Slack."
fi

if [[ -f "$databaselist" ]]; then
    rm "$databaselist"
fi

if [[ -f "$error_log" ]]; then
    rm "$error_log"
fi

if [[ -f "$operations_log" ]]; then
    rm "$operations_log"
fi

exit $error