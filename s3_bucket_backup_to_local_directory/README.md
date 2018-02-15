This script backs up the contents of a specified S3 bucket hosted in Amazon Web Services to a local directory.

**Pre-requisites:**

The script assumes that the AWS CLI tool has been installed and configured with the following:

* AWS access key
* AWS secret key
* Correct AWS region for the S3 bucket

The script performs the following actions:

1. If necessary, creates a log file named dp_sync.log and stores it in /var/log/
2. If necessary, creates the local directory to store the files downloaded from the cloud distribution point.
3. Performs a one-way synchronization of the cloud distribution point with the local directory.
4. Sets all downloaded files to be world-readable
5. Logs all actions to /var/log/dp_sync.log 