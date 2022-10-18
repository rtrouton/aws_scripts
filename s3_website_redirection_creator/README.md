This script sets up S3 buckets in Amazon Web Services for use with redirecting DNS or URL requests to an alterative HTTP or HTTPS URL.

The following pre-requisites are needed:

* The AWS CLI tool must be installed
* The AWS CLI tool must have access to AWS programmatic user credentials with the permissions to do the following:

    * Create an S3 bucket
    * Set permissions on the newly-created S3 bucket
    * Apply an S3 bucket policy to the newly-created S3 bucket
    * Apply a website configuration to the newly-created S3 bucket

Once the pre-requisites are met, this script performs the following actions:

1. Requests a name for an S3 bucket, which should be the DNS name that you want to set up a redirection for.
2. Requests the AWS region that the S3 bucket should be created in.
3. Requests the HTTP or HTTPS URL of the website that the redirection is being set up for.

Once the user-requested information is provided, this script performs the following actions:

1. Creates an S3 bucket using the name supplied by user input
2. Set permissions on the newly-created S3 bucket so that no public access is permitted.
3. Set the default encryption behavior for the newly-created S3 bucket to be enabled and to use Amazon S3-managed encryption keys.
4. Sets an S3 bucket policy which blocks non-SSL connections to the contents of the newly-created S3 bucket.
5. Set the website configuration for the desired URL redirection for the newly-created bucket.