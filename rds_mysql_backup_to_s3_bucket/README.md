This script backs up the contents of a specified database hosted in Amazon Web Services' RDS service to an S3 bucket.

**Pre-requisites:**

The script assumes the following:

1. The AWS CLI tool, `gzip` and `mysqldump` have been installed.
2. A [MySQL connection](https://dev.mysql.com/doc/refman/5.6/en/mysql-config-editor.html) has been created to provide authentication to the database.

The script performs the following actions:

1. Connects to a specified MySQL database running in RDS
2. Creates a backup of the database using `mysqldump`.
3. Verifies if the database backup completed successfully.
4. Logs backup success or failure to a log file.
5. Uploads database backup and log file to specified S3 bucket.