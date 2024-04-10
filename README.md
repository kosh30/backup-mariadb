# kubernetes-s3-mysql-backup

kubernetes-s3-mysql-backup is a container image based on Debian Bookworm. This container is designed to run in Kubernetes as a cronjob to perform automatic backups of MariaDB databases to Amazon S3.

All changes are captured in the [changelog](CHANGELOG.md), which adheres to [Semantic Versioning](https://semver.org/spec/vadheres2.0.0.html).

## Environment Variables

The below table lists all the Environment Variables that are configurable for kubernetes-s3-mysql-backup.

| Environment Variable  | Purpose                                                                                                                                                           |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AWS_ACCESS_KEY_ID     | **(Required)** AWS IAM Access Key ID.                                                                                                                             |
| AWS_SECRET_ACCESS_KEY | **(Required)** AWS IAM Secret Access Key. Should have very limited IAM permissions (see below for example) and should be configured using a Secret in Kubernetes. |
| AWS_DEFAULT_REGION    | **(Required)** Region of the S3 Bucket (e.g. eu-west-2).                                                                                                          |
| BUCKET_NAME           | **(Required)** The name of the S3 bucket.                                                                                                                         |
| BACKUP_PREFIX         | **(Required)** Path the backup file should be saved to in S3. E.g. `/database/myblog/backups`. **Do not put a trailing / or specify the filename.**               |
| DB_HOST               | **(Required)** Hostname or IP address of the MySQL Host.                                                                                                          |
| DB_USER               | **(Required)** Username to authenticate to the database with.                                                                                                     |
| DB_PASSWORD           | **(Required)** Password to authenticate to the database with. Should be configured using a Secret in Kubernetes.                                                  |


## Configuring the S3 Bucket & AWS IAM User

kubernetes-s3-mysql-backup performs a backup to the same path, with the same filename each time it runs. It therefore assumes that you have Versioning enabled on your S3 Bucket. A typical setup would involve S3 Versioning, with a Lifecycle Policy.

An IAM Users should be created, with API Credentials. An example Policy to attach to the IAM User (for a minimal permissions set) is as follows:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<BUCKET NAME>"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::<BUCKET NAME>/*"
        }
    ]
}
```


## Example Kubernetes Cronjob

An example of how to schedule this container in Kubernetes as a cronjob is below. This would configure a database backup to run each day at 01:00am. The AWS Secret Access Key, and Target Database Password are stored in secrets.

```
apiVersion: v1
kind: Secret
metadata:
  name: AWS_SECRET_ACCESS_KEY
type: Opaque
data:
  aws_secret_access_key: <AWS Secret Access Key>
---
apiVersion: v1
kind: Secret
metadata:
  name: TARGET_DATABASE_PASSWORD
type: Opaque
data:
  database_password: <Your Database Password>
---
apiVersion: v1
kind: Secret
metadata:
  name: NOTIFICATION_WEBHOOK_URL
type: Opaque
data:
  slack_webhook_url: <Your Slack WebHook URL>
---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: my-database-backup
spec:
  schedule: "0 01 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: my-database-backup
            image: gcr.io/maynard-io-public/kubernetes-s3-mysql-backup
            imagePullPolicy: Always
            env:
              - name: AWS_ACCESS_KEY_ID
                value: "<Your Access Key>"
              - name: AWS_SECRET_ACCESS_KEY
                valueFrom:
                   secretKeyRef:
                     name: AWS_SECRET_ACCESS_KEY
                     key: aws_secret_access_key
              - name: AWS_DEFAULT_REGION
                value: "<Your S3 Bucket Region>"
              - name: AWS_BUCKET_NAME
                value: "<Your S3 Bucket Name>"
              - name: AWS_BUCKET_BACKUP_PATH
                value: "<Your S3 Bucket Backup Path>"
              - name: TARGET_DATABASE_HOST
                value: "<Your Target Database Host>"
              - name: TARGET_DATABASE_PORT
                value: "<Your Target Database Port>"
              - name: TARGET_DATABASE_NAMES
                value: "<Your Target Database Name(s)>"
              - name: TARGET_DATABASE_USER
                value: "<Your Target Database Username>"
              - name: TARGET_DATABASE_PASSWORD
                valueFrom:
                   secretKeyRef:
                     name: TARGET_DATABASE_PASSWORD
                     key: database_password
              - name: NOTIFY_ENABLED
                value: "<true/false>"
              - name: NOTIFY_CHANNEL
                value: "#chatops"
              - name: NOTIFICATION_WEBHOOK_URL
                valueFrom:
                   secretKeyRef:
                     name: NOTIFICATION_WEBHOOK_URL
                     key: slack_webhook_url
          restartPolicy: Never
```
