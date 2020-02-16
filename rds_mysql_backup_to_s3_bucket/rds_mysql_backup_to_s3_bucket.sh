#!/bin/bash

# Enter name of the RDS database being backed up

database_name=database_name_goes_here

# Enter name of the S3 bucket

S3_bucket=S3_bucket_name_goes_here

# Enter the MySQL connection name

mysql_connection_name=mysql_connection_name_goes_here

# These variables don't need to be edited

log_name="jamfprobackup-database-backup-$(date +'%Y%m%d%H%M%S').log"
log_location="/var/log/$log_name"
database_mysqldump="jamfprobackup-database-backup-$(date +'%Y%m%d%H%M%S').sql.gz"

# Get applicable AWS region from EC2 instance that the script is running on.

aws_region=$(/bin/curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed "s/.$//g")

ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"

    /usr/bin/echo "$DATE" " $1" >> $LOG
}


# Creates a database backup using the mysqldump tool and stores the backup in the /tmp directory

ScriptLogging "Creating backup of database to $database_mysqldump"
/usr/bin/mysqldump --login-path="$mysql_connection_name" --max-allowed-packet=1024M --single-transaction --routines --triggers --databases "$database_name" | /usr/bin/gzip -9 > /tmp/"$database_mysqldump"

# The "backupstatus" variable checks the mysqldump command's exit status
backupstatus=`echo ${PIPESTATUS[0]}`

# If the mysqldump command completed successfully and if the database backup exists,
# the script continues. Otherwise, the script exits with an error.

if [[ "$backupstatus" -eq 0 ]] && [[ -f /tmp/"$database_mysqldump" ]]; then
    ScriptLogging "Backup created successfully."
else
    # Upload backup failure log to S3 bucket. 

    ScriptLogging "Backup not successfully created. Removing any files created and exiting with error."
    /usr/bin/aws s3 cp "$log_location" s3://"$S3_bucket"/"$log_name" --region "$aws_region"
    if [[ -f /tmp/"$database_mysqldump" ]]; then
       /usr/bin/rm /tmp/"$database_mysqldump"
    fi
    exit 1
fi

# Copies database backup.

ScriptLogging "Uploading database backup to the following S3 bucket: $S3_bucket"
/usr/bin/aws s3 cp /tmp/"$database_mysqldump" s3://"$S3_bucket"/"$database_mysqldump" --region "$aws_region"


ScriptLogging "Removing the backup file $database_mysqldump from /tmp"
/usr/bin/rm /tmp/"$database_mysqldump"

ScriptLogging "Backup process completed."

# Uploading backup log to S3 bucket.

ScriptLogging "Uploading database backup log to the following S3 bucket: $S3_bucket"
/usr/bin/aws s3 cp "$log_location" s3://"$S3_bucket"/"$log_name" --region "$aws_region"