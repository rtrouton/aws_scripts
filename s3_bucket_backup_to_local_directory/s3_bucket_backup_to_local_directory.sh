#!/bin/bash

# Script backs up the contents of an S3 bucket hosted
# in Amazon Web Services to a local directory.
#
# Pre-requisites:
# Script assumes that the AWS CLI tool has been installed
# and configured with the following:
#
# AWS access key
# AWS secret key
# Correct AWS region for the S3 bucket specified below.

# Specify the name of the S3 bucket

s3_bucket="S3-bucket-name-goes-here"

# Location of the local directory used
# to store the downloaded files.

local_directory="/path/to/backup/directory"

# Set up logging format

log_location="/var/log/dp_sync.log"

ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"

    echo "$DATE" " $1" >> $LOG
}

# Verify that /var/log/dp_sync.log is present and create it
# if /var/log/dp_sync.log is not present.

if [[ ! -f "$log_location" ]]; then
    touch "$log_location"
fi

# Verify that the local backup directory is present
# and create it if is not present.

if [[ ! -d "$local_directory" ]]; then
    mkdir -p "$local_directory"
fi

# Perform a one-way synchronization from the S3 bucket to the local backup directory, so that the
# local backup directory only contains the contents of the specified S3 bucket.
#
# Once the S3 bucket's contents have been synchronized, all files and directories are set to be
# world-readable. All output should be logged to /var/log/dp_sync.log.

ScriptLogging "Starting syncronization"
aws s3 sync --delete s3://"$s3_bucket"/ "$local_directory" >> "$log_location" 2>&1
chmod -R 755 "$local_directory"
ScriptLogging "Syncronization complete"
