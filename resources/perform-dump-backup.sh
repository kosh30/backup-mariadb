#!/usr/bin/env bash
BACKUP_DIR=./
DATE=$(date +%Y-%m-%d-%H-%M)

if [ -x "$(command -v mariadb)" ]; then
    db_cmd=$(command -v mariadb)
    dmp_cmd=$(command -v mariadb-dump)
else
    db_cmd=$(command -v mysql)
    dmp_cmd=$(command -v mysqldump)
fi


# Use the mysql command to fetch all database names
dblist=$($db_cmd -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}"  -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys|innodb|mysql)")

for db in $dblist; do
    echo "Backing up database: $db"
    mkdir -p "${BACKUP_DIR}/${db}/${DATE}"
    $dmp_cmd -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" -a -B --replace --skip-add-drop-table --no-data  "$db" > "${BACKUP_DIR}/${db}/${DATE}/structure.sql"
    $dmp_cmd -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" -a -B --replace --insert-ignore --no-create-info  "$db" > "${BACKUP_DIR}/${db}/${DATE}/data.sql"
    tar -czf "${BACKUP_DIR}/${db}.tar.gz" "${BACKUP_DIR}/${db}/${DATE}"
    sha256sum "${BACKUP_DIR}/${db}.tar.gz" > "${BACKUP_DIR}/${db}/${DATE}.tar.gz.sha256"
    # shellcheck disable=SC2115
    rm -rf "${BACKUP_DIR}/${db}/${DATE}"
done
s5cmd sync . "s3://${BUCKET_NAME}/${BACKUP_PREFIX}/"
rm ./* -rf
