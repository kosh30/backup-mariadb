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

An example of how to schedule this container in Kubernetes as a cronjob is below. This would configure a database backup to run hourly. The AWS Secret Access Key, and Target Database Password are stored in secrets.

```
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup-hourly
  labels:
    app.kubernetes.io/name: maria-db-operations
spec:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      backoffLimit: 3
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: mariabd-dumper
              image: 'ghcr.io/kosh30/backup-mariadb:1.0.0'
              imagePullPolicy: IfNotPresent
              env:
                - name: DB_USER
                  valueFrom:
                    secretKeyRef:
                      name: db-cluster-secret
                      key: DB_USER
                - name: DB_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: db-cluster-secret
                      key: DB_PASSWORD
                - name: DB_HOST
                  valueFrom:
                    configMapKeyRef:
                      key: db_address
                      name: db-cluster-config
                - name: DB_PORT
                  valueFrom:
                    configMapKeyRef:
                      key: db_port
                      name: db-cluster-config
                - name: BUCKET_NAME
                  valueFrom:
                    configMapKeyRef:
                      key: AWS_BACKUP_BUCKET_NAME
                      name: aws-backup-bucket
                - name: BACKUP_PREFIX
                  value: "mariadb"
                - name: AWS_REGION
                  valueFrom:
                    configMapKeyRef:
                      key: AWS_BACKUP_BUCKET_REGION
                      name: aws-backup-bucket
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      key: AWS_ACCESS_KEY_ID
                      name: aws-backup-user
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      key: AWS_SECRET_ACCESS_KEY
                      name: aws-backup-user
  schedule: "5 * * * *"

```
