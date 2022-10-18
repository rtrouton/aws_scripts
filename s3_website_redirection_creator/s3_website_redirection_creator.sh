#!/bin/bash

# This script sets up S3 buckets in Amazon Web Services for use with redirecting
# DNS or URL requests to an alterative HTTP or HTTPS URL.
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
#       *  Apply a website configuration to the newly-created S3 bucket
#
#
# Once the pre-requisites are met, this script performs the following actions:
#
#  A. Requests a name for an S3 bucket, which should be the DNS name that you want to set up a redirection for.
#  B. Requests the AWS region that the S3 bucket should be created in.
#  C. Requests the HTTP or HTTPS URL of the website that the redirection is being set up for.
#
#  Once the user-requested information is provided, this script performs the following actions:
#
#  1. Creates an S3 bucket using the name supplied by user input
#  2. Set permissions on the newly-created S3 bucket so that no public access is permitted.
#  3. Set the default encryption behavior for the newly-created S3 bucket to be enabled and to use Amazon S3-managed encryption keys.
#  4. Sets an S3 bucket policy which blocks non-SSL connections to the contents of the newly-created S3 bucket.
#  5. Set the website configuration for the desired URL redirection for the newly-created bucket.

# Set exit code
exitCode=0

clear
echo "This script sets up S3 buckets in Amazon Web Services for website redirection."
echo "You will need to enter the following information:"
echo ""
echo "A. The name of the new S3 bucket, which should be the DNS name that you want to set up a redirection for."
echo "B. The Amazon Web Services region that you want to create the S3 bucket in."
echo "C. The address of the website address you want to redirect to."
echo ""
read -p "Please enter the name of the new S3 bucket: " s3_bucket_name
read -p "Please enter the AWS region that the new S3 bucket should be created in: " s3_bucket_region
read -p "Please enter the website address you want to redirect to : " website_url

# Figure out if an HTTP or HTTPS URL is being used.

http_protocol=${website_url%://*}

# Get the website URL and split it as necessary for use with the redirection rules.

site=${website_url#*//}

if [[ "$site" == *\/* ]]; then
   site=${site%%/*}
   site_path=${website_url#*//}
   site_path=${site_path#*/}
else
   site=${site%%/*}
   site_path=""
fi

# Verify that the URL begins with either 'http' or 'https'. If it doesn't, the script
# will display an error message and exit.

if [[ ${http_protocol} != "http" ]] && [[ ${http_protocol} != "https" ]] && [[ ${http_protocol} != "HTTP" ]] && [[ ${http_protocol} != "HTTPS" ]]; then
    echo "ERROR - ${website_url} URL begins with $http_protocol, which means it is not a valid HTTP or HTTPS URL. Script will now exit."
    exitCode=1
    exit "$exitCode"
fi

# The redirection rule Protocol entries need to be lower-case, so 
# set HTTP and HTTPS entries to lower-case if needed. 

if [[ ${http_protocol} == "HTTP" ]]; then
    http_protocol="http"
elif [[ ${http_protocol} == "HTTPS" ]]; then
    http_protocol="https"
fi

# Create an S3 website configuration for the desired URL redirection.

if [[ -n ${site_path} ]]; then

read -r -d '' redirectionJSON <<- AWS_S3_REDIRECTION_POLICY
{
    "IndexDocument": {
        "Suffix": "index.html"
    },
    "ErrorDocument": {
        "Key": "error.html"
    },
    "RoutingRules": [
        {
            "Redirect": {
                "HostName": "$site",
                "HttpRedirectCode": "301",
                "Protocol": "$http_protocol",
                "ReplaceKeyPrefixWith": "$site_path"
            }
        }
    ]
}
AWS_S3_REDIRECTION_POLICY

else

read -r -d '' redirectionJSON <<- AWS_S3_REDIRECTION_POLICY
{
    "IndexDocument": {
        "Suffix": "index.html"
    },
    "ErrorDocument": {
        "Key": "error.html"
    },
    "RoutingRules": [
        {
            "Redirect": {
                "HostName": "$site",
                "HttpRedirectCode": "301",
                "Protocol": "$http_protocol"
            }
        }
    ]
}
AWS_S3_REDIRECTION_POLICY
fi

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

# Set the website configuration for the desired URL redirection for the newly-created bucket.

aws s3api put-bucket-website --bucket ${s3_bucket_name} --website-configuration file://$redirectionJSON_file 2>&1 > /dev/null

echo "New S3 bucket is available from the address below:"
echo ""
echo "S3 bucket name: ${s3_bucket_name}"
echo "S3 bucket location: ${s3_bucket_region}"
echo "S3 bucket website URL: http://${s3_bucket_name}.s3-website-${s3_bucket_region}.amazonaws.com"
echo ""
echo "Going to http://${s3_bucket_name}.s3-website-${s3_bucket_region}.amazonaws.com in a web browser should automatically redirect the browser to the address below: "
echo ""
echo "${website_url}"

exit "$exitCode"