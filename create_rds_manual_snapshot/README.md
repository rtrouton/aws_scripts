This script uses an RDS Name tag value to identify databases with a matching Name tag value and creates manual database snapshots, with operation and error logging being posted to a Slack webhook.

The following pre-requisites are needed:

* The AWS CLI tool must be installed
* The AWS CLI tool must have permissions to do the following:

    * Read list of RDS databases
    * Read resource group tags
    * Create RDS database manual snapshots

Once the pre-requisites are met, this script performs the following actions:

1. Lists RDS databases with a specified Name tag.
2. Creates RDS database manual snapshots of all databases with that Name tag.
3. Sends operation and error logging to Slack.