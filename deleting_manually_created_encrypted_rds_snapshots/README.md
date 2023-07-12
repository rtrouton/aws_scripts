This script deletes encrypted DBSnapshots which are older than a specified number of days, with operation and error logging being posted to a Slack webhook.

The following pre-requisites are needed:

* The AWS CLI tool must be installed
* The AWS CLI tool must have permissions to do the following:

    * Read list of RDS database manual snapshots
    * Delete RDS database manual snapshots

Once the pre-requisites are met, this script performs the following actions:

1. Lists RDS database manual snapshots.
2. Creates a list of encrypted database snapshots.
3. Determines if any encrypted snapshots are older than the specified number of days.
4. Deletes any encrypted snapshots which are older than the specified number of days.
5. Sends operation and error logging to Slack.