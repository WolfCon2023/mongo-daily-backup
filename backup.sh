#!/bin/sh
set -e

# Folder where backups will live on the mounted volume
BACKUP_ROOT="/data/backups"

# Timestamp for this run
TIMESTAMP=$(date +"%F_%H-%M-%S")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

echo "Starting Mongo backup at $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# MONGO_URI will come from Railway env vars
if [ -z "$MONGO_URI" ]; then
  echo "ERROR: MONGO_URI environment variable is not set."
  exit 1
fi

# Run mongodump
mongodump --uri="$MONGO_URI" --out="$BACKUP_DIR"

echo "Backup complete."

# Optional: delete backups older than 7 days
echo "Cleaning backups older than 7 days…"
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; || true

echo "Done."
