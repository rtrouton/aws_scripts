#!/bin/bash

# This script sets up S3 buckets in Amazon Web Services.
#
# The following pre-requisites are needed:
# 
# * The AWS CLI tool must be installed
# * The AWS CLI tool must have access to AWS programmatic user credentials with the
#   permissions to do the following:
#
#       *  Create an S3 bucket
#       *  Set permissions on the newly-created S3 bucket
#       *  Apply an S3 bucket policy to the newly-created S3 bucket
#
#
# Once the pre-requisites are met, this script performs the following actions:
#
#  A. Requests a name for an S3 bucket, which should be the DNS name that you want to set up a redirection for.
#  B. Requests the AWS region that the S3 bucket should be created in.
#
#  Once the user-requested information is provided, this script performs the following actions:
#
#  1. Creates an S3 bucket using the name supplied by user input
#  2. Set permissions on the newly-created S3 bucket so that no public access is permitted.
#  3. Set the default encryption behavior for the newly-created S3 bucket to be enabled and to use Amazon S3-managed encryption keys.
#  4. Sets an S3 bucket policy which blocks non-SSL connections to the contents of the newly-created S3 bucket.

# Set exit code
exitCode=0

clear
echo "This script sets up S3 buckets in Amazon Web Services."
echo "You will need to enter the following information:"
echo ""
echo "A. The name of the new S3 bucket."
echo "B. The Amazon Web Services region that you want to create the S3 bucket in."
echo ""
read -p "Please enter the name of the new S3 bucket: " s3_bucket_name
read -p "Please enter the AWS region that the new S3 bucket should be created in: " s3_bucket_region

# Convert upper-case letters to lower case letters as needed.

s3_bucket_name=$(echo "$s3_bucket_name"| tr '[:upper:]' '[:lower:]')

redirectionJSON_file=$(mktemp)

echo "$redirectionJSON" > "$redirectionJSON_file"

# Create an S3 bucket policy which blocks non-SSL connections to the contents
# of the S3 bucket.

read -r -d '' bucketpolicyJSON <<- AWS_S3_BUCKET_POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSSLRequestsOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$s3_bucket_name",
        "arn:aws:s3:::$s3_bucket_name/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
AWS_S3_BUCKET_POLICY

bucketpolicyJSON_file=$(mktemp)

echo "$bucketpolicyJSON" > "$bucketpolicyJSON_file"

# Create the S3 bucket.

if [[ ${s3_bucket_region} = "us-east-1" ]]; then
    aws s3api create-bucket --bucket ${s3_bucket_name} --region ${s3_bucket_region} 2>&1 > /dev/null
else
    aws s3api create-bucket --bucket ${s3_bucket_name} --region ${s3_bucket_region} --create-bucket-configuration LocationConstraint=${s3_bucket_region} 2>&1 > /dev/null
fi 

# Set permissions on the newly-created S3 bucket so that no public access is permitted.

aws s3api put-public-access-block --bucket ${s3_bucket_name} --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>&1 > /dev/null

# Set the default encryption behavior for the newly-created S3 bucket to be enabled and to use Amazon S3-managed encryption keys.

aws s3api put-bucket-encryption  --bucket ${s3_bucket_name} --server-side-encryption-configuration  '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' 2>&1 > /dev/null

# Sets an S3 bucket policy which blocks non-SSL connections to the contents of the newly-created S3 bucket.

aws s3api put-bucket-policy --bucket ${s3_bucket_name} --policy file://$bucketpolicyJSON_file 2>&1 > /dev/null

echo "New S3 bucket has been created:"
echo ""
echo "S3 bucket name: ${s3_bucket_name}"
echo "S3 bucket location: ${s3_bucket_region}"

exit "$exitCode"