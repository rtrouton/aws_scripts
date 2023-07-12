#!/bin/bash

# Deleting manually-created encrypted RDS database snapshots older than a pre-determined amount of time

# Deletion time interval in days. By default this is set to 30 days.
RDSSnapshotAge="30"

SnapshotDate=$(date --date="-$RDSSnapshotAge days" +%Y-%m-%d)

slack_webhook="https://slack.webhook.url/goes/here"

SendToSlack(){

# Original script from here:
# http://blog.getpostman.com/2015/12/23/stream-any-log-file-to-slack-using-curl/

cat "$1" | while read LINE; do
  (echo "$LINE" | grep -e "$3") && curl -X POST --silent --data-urlencode "payload={\"text\": \"$(echo $LINE | sed "s/\"/'/g")\"}" "$2";
done

}

error_log=$(mktemp)
operations_log=$(mktemp)

# Define AWS account
account_id=$(aws sts get-caller-identity --query 'Account' --output text)

# Set initial status for exit
error=0 

# Set the source AWS region
aws_source_region="eu-west-1"
#aws_source_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")

# Set the destination AWS region

aws_dest_region="eu-west-1"
#aws_dest_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")

# Set the encryption key to use.
# By default, we are using AWS's
# encryption key.
 
aws_kms_key_id="alias/aws/rds"

databaselist=$(mktemp)

touch "$databaselist"
touch "$error_log"
touch "$operations_log"

aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[?SnapshotCreateTime<=`'$SnapshotDate'`][DBSnapshotIdentifier,Encrypted]' --region "${aws_source_region}" --output text > "$databaselist"

echo "Encrypted snapshots" 
awk '{IGNORECASE=1}{if ($2 == "True") print}' "$databaselist" #Show list of encrypted snapshots 
echo "Unencrypted snapshots" 
awk '{IGNORECASE=1}{if ($2 == "False") print}' "$databaselist" #Show list of unencrypted snapshots

IFS=$'\n' read -d '' -r -a rds_list_lines < "$databaselist" #Move txt file content into an array

for i in "${rds_list_lines[@]}"; do #Loop through array   

if [[ "${i}" == *"True"* ]]; then # Check for encrypted rds snapshots
    
    # Remove all spaces tabs and the word "True" from the source database snapshot
    
    source_snapshot_ident="$(echo "${i}" | sed -e 's/[[:blank:]]//' -e 's/True//g')"

    echo "$(date) - Deleting ${source_snapshot_ident} encrypted database snapshot created before $SnapshotDate" >> "$operations_log"
    aws rds delete-db-snapshot --db-snapshot-identifier "${source_snapshot_ident}"
    if [[ $? -eq 0 ]]; then
            echo "$(date) - Deleted ${source_snapshot_ident} encrypted database snapshot" >> "$operations_log"
         else
            echo "$(date) - ERROR! Failed to delete ${source_snapshot_ident}!"
            error=1
    fi
    else
        echo "$(date) - ERROR! No snapshots found!" >> "$error_log"
        error=1
fi

done

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