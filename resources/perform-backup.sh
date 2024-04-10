#!/usr/bin/env bash
BACKUP_DIR=./
DATE=$(date +%Y-%m-%d-%H%M)
if [ -z "$BACKUP_TYPE" ]; then
    BACKUP_TYPE=full
fi

if [ $BACKUP_TYPE = "full" ]; then
    TARGET_NAME_PREFIX=full
else
    TARGET_NAME_PREFIX=incremental
fi

cd "${BACKUP_DIR}" || exit

TARGET_NAME_FULL=${TARGET_NAME_PREFIX}.full
TARGET_NAME_INCREMENTAL=${TARGET_NAME_PREFIX}_${DATE}.inc

echo "Starting backup..."
echo $TARGET_NAME_FULL

full_backup() {
  START=$(date +%s)
  echo "Start full backup at ${START}"
    if [ -d ./${TARGET_NAME_FULL} ]; then
      rm -rf ./${TARGET_NAME_FULL}
    fi
    mkdir -p ./${TARGET_NAME_FULL}
    mariadb-backup --backup \
        --target-dir=./${TARGET_NAME_FULL}/data/ \
        --host="${DB_HOST}" \
        --port=3306 \
        --user="${DB_USER}" \
        --password="${DB_PASSWORD}" \
        2>&1 | tee -a ./${TARGET_NAME_FULL}/${TARGET_NAME_PREFIX}.log

    tar -cpzf ./${TARGET_NAME_FULL}.tar.gz ${TARGET_NAME_FULL}
    s5cmd cp ./${TARGET_NAME_FULL}.tar.gz "s3://${BUCKET_NAME}/${BACKUP_PREFIX}/${TARGET_NAME_FULL}.tar.gz"
    rm -rf ${TARGET_NAME_FULL}.tar.gz
    END=$(date +%s)
    echo "End full backup at ${END}"
}

full_backup
