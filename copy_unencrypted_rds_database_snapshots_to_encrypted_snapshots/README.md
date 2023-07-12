This script copies unencrypted DBSnapshots to an encrypted DBSnapshot in the same region, with operation and error logging being posted to a Slack webhook.

The following pre-requisites are needed:

* The AWS CLI tool must be installed
* The AWS CLI tool must have permissions to do the following:

    * Read list of RDS database manual snapshots
    * Copy RDS database manual snapshots
    * Delete RDS database manual snapshots

Once the pre-requisites are met, this script performs the following actions:

1. Lists RDS database manual snapshots.
2. Creates a list of unencrypted database snapshots.
3. Individually copy the unencrypted snapshots to a new encrypted snapshot.
4. Once an individual unencrypted snapshot has been copied to an encrypted snapshot, the unencrypted snapshot is deleted.
5. Sends operation and error logging to Slack.