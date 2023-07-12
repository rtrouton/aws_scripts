#!/bin/bash

# Copy unencrypted DBSnapshots to an encrypted DBSnapshot in the same region

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
aws_source_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")

# Set the destination AWS region

aws_dest_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")

# Set the encryption key to use.
# By default, we are using AWS's
# encryption key.
 
aws_kms_key_id="alias/aws/rds"

databaselist=$(mktemp)

touch "$databaselist"
touch "$error_log"
touch "$operations_log"

aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[*].[DBSnapshotArn,Encrypted]' --region "${aws_source_region}" --output text > "$databaselist"

 #Show list of encrypted snapshots
echo "Encrypted snapshots" 
awk '{IGNORECASE=1}{if ($2 == "True") print}' "$databaselist"

#Show list of unencrypted snapshots

echo "Unencrypted snapshots" 
awk '{IGNORECASE=1}{if ($2 == "False") print}' "$databaselist" 

# Add snapshots to array

IFS=$'\n' read -d '' -r -a rds_list_lines < "$databaselist"

#Loop through array

for i in "${rds_list_lines[@]}"; do  

# Check for unencrypted RDS database snapshots. If any are found, 
# individually copy the unencrypted snapshots to a new encrypted
# snapshot.

if [[ "${i}" == *"False"* ]]; then 
     
    echo "Copying unencrypted snapshots from ${aws_source_region} to encrypted snapshots in ${aws_dest_region}" 
         
    # Remove all spaces tabs and the word "False" from the source database snapshot
    
    source_snapshot_ident="$(echo "${i}" | sed -e 's/[[:blank:]]//' -e 's/False//g')"
    
    # Remove ":snapshot:rds:" from the source database's identifier string and change the remaining
    # colon characters to hyphens.
    
    source_snapshot_name="$(echo "$source_snapshot_ident" | sed -e 's/.*:snapshot:rds:.//' -e 's/:/-/g')"

    # Use the output of the $source_snapshot_name variable as part of naming the target snapshot.
    # The target snapshot name also includes that the snapshot is encrypted as well as the date
    # that the snapshot was created.

    target_snapshot_ident="$(echo "$source_snapshot_name"-encrypted-snapshot-$(date +"%Y%m%d%H%M")-$(echo $RANDOM))" 

    echo "$(date) - Creating ${target_snapshot_ident} encrypted database snapshot from ${source_snapshot_ident} unencrypted database snapshot." >> "$operations_log"
    aws rds copy-db-snapshot --region "${aws_source_region}" --source-db-snapshot-identifier "${source_snapshot_ident}" --target-db-snapshot-identifier "${target_snapshot_ident}" --source-region "${aws_source_region}" --kms-key-id "${aws_kms_key_id}"
    aws rds wait db-snapshot-completed  --region "${aws_source_region}" --db-snapshot-identifier "${target_snapshot_ident}"
    if [[ $? -eq 0 ]]; then
        echo "$(date) - Created ${target_snapshot_ident} encrypted database snapshot." >> "$operations_log"
        echo "$(date) - Deleting ${source_snapshot_ident} unencrypted database snapshot." >> "$operations_log"
        source_snapshot_name_identifier="$(echo "$source_snapshot_ident" | sed -e "s/.*arn:aws:rds:$aws_source_region:$account_id:snapshot://")"
        aws rds delete-db-snapshot --region "${aws_source_region}" --db-snapshot-identifier "${source_snapshot_name_identifier}" 
         if [[ $? -eq 0 ]]; then
            echo "$(date) - Deleted ${source_snapshot_ident} unencrypted database snapshot" >> "$operations_log"
         else
            echo "ERROR! Failed to delete ${source_snapshot_ident}!" >> "$error_log"
            error=1
         fi
    else
        echo "$(date) - ERROR! Failed to create encrypted copy of ${source_snapshot_ident}!" >> "$error_log"
        error=1
    fi

fi

done

if [[ -s "$operations_log" ]]; then
   echo "Sending $operations_log to Slack"
   SendToSlack "$operations_log" ${slack_webhook}
   echo "Sent $operations_log to $slack_webhook. Ending run."
else
   echo "Operations log was empty. Nothing to send to Slack."
fi

if [[ -s "$error_log" ]]; then
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

exit "$error"