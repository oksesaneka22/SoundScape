#!/bin/bash

# Configuration variables
S3_BUCKET="s3://backeups-site123/postgres-backup/"  # Your S3 bucket path
PG_PORT="5432"  # PostgreSQL port (default)
PG_USER="postgres"  # PostgreSQL user for restore
PG_PASSWORD="123456"  # PostgreSQL user password
PG_DB="SoundScapeDb"  # The PostgreSQL database to restore to
K8S_NAMESPACE="todo-app"  # Kubernetes namespace where PostgreSQL service is running
K8S_PG_SERVICE="postgres"  # PostgreSQL service name in the Kubernetes cluster

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "aws-cli not found, installing..."
    apk add --no-cache aws-cli
fi

# Ensure PostgreSQL client (pg_restore) is installed
if ! command -v pg_restore &> /dev/null
then
    echo "pg_restore not found, installing..."
    apk add --no-cache postgresql-client
fi

# Export PostgreSQL password to avoid prompts
export PGPASSWORD=$PG_PASSWORD

# Ask user for the backup file to restore
echo "Available backups in the S3 bucket: "
aws s3 ls ${S3_BUCKET}  # List files in the S3 bucket

echo "Enter the backup file name you want to restore (e.g., postgres_backup_2025-03-16_17-00-10.sql.gz): "
read BACKUP_FILE

# Validate if the file exists in the S3 bucket
aws s3 ls ${S3_BUCKET}${BACKUP_FILE} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Backup file ${BACKUP_FILE} not found in S3 bucket!"
    exit 1
fi

# Download the selected backup file from S3
echo "Downloading backup from S3..."
aws s3 cp ${S3_BUCKET}${BACKUP_FILE} /tmp/${BACKUP_FILE}

# Check if the backup file was downloaded successfully
if [ $? -ne 0 ]; then
    echo "Error downloading the backup file from S3!"
    exit 1
fi

# Automatically fetch the pod name for the PostgreSQL service
PG_POD=$(kubectl get pods -n ${K8S_NAMESPACE} -l app=${K8S_PG_SERVICE} -o jsonpath='{.items[0].metadata.name}')
if [ -z "$PG_POD" ]; then
    echo "Error: Could not find the PostgreSQL pod in the Kubernetes cluster!"
    exit 1
fi

# Option 1: Use port-forwarding to access PostgreSQL pod
echo "Setting up port-forwarding to PostgreSQL pod ${PG_POD} in Kubernetes..."
kubectl port-forward -n ${K8S_NAMESPACE} pod/${PG_POD} ${PG_PORT}:${PG_PORT} &

# Give some time for port-forwarding to establish
sleep 5

# Restore the backup to PostgreSQL
echo "Restoring backup to PostgreSQL database ${PG_DB}..."
pg_restore -h localhost -p ${PG_PORT} -U ${PG_USER} -d ${PG_DB} --clean --if-exists -v /tmp/${BACKUP_FILE}
# Check if restore was successful
if [ $? -eq 0 ]; then
    echo "Backup restoration completed successfully!"
else
    echo "Error during restoration!"
    exit 1
fi

# Clean up: remove the downloaded backup file
rm /tmp/${BACKUP_FILE}

# Stop port-forwarding by killing the background process
kill %1

echo "Done!"

