#!/bin/sh

set -e

# Root folder for all backups on the mounted volume
BACKUP_ROOT="/data/backups"

# Timestamped directory for this run
TIMESTAMP=$(date +"%F_%H-%M-%S")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/backup.log"
STATUS_FILE="$BACKUP_DIR/status.txt"

mkdir -p "$BACKUP_DIR"

if [ -z "$MONGO_URI" ]; then
  echo "ERROR: MONGO_URI environment variable is not set."
  exit 1
fi

{
  echo "============================================="
  echo "MongoDB Backup Job"
  echo "Timestamp: $TIMESTAMP"
  echo "Backup directory: $BACKUP_DIR"
  echo "============================================="

  # Default status (will be overridden on success)
  JOB_STATUS="FAILED"

  echo "[INFO] Starting mongodump..."

  # Allow mongodump to fail without exiting the script immediately
  set +e
  mongodump --uri="$MONGO_URI" --out="$BACKUP_DIR"
  DUMP_EXIT_CODE=$?
  set -e

  if [ "$DUMP_EXIT_CODE" -ne 0 ]; then
    echo "[ERROR] mongodump failed with exit code $DUMP_EXIT_CODE"
    JOB_STATUS="FAILED"
  else
    echo "[INFO] mongodump completed successfully."
    JOB_STATUS="SUCCESS"
  fi

  echo "[INFO] Cleaning backups older than 7 days..."
  find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; || true

  echo "[INFO] Backup job finished with status: $JOB_STATUS"

  # Persist status so the parent shell can read it (pipe runs in a subshell)
  echo "$JOB_STATUS" > "$STATUS_FILE"
} | tee "$LOG_FILE"

# Read final status from file (fallback to FAILED if missing)
if [ -f "$STATUS_FILE" ]; then
  JOB_STATUS="$(cat "$STATUS_FILE")"
else
  JOB_STATUS="FAILED"
fi

# If email settings are present, send a notification with the log attached
if [ -n "$ALERT_TO" ] && [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
  SUBJECT_PREFIX="MongoDB Backup"
  SUBJECT_STATUS="$JOB_STATUS"

  if [ "$JOB_STATUS" = "SUCCESS" ]; then
    BODY_MESSAGE="Your scheduled MongoDB backup has completed successfully.\n\nBackup directory: $BACKUP_DIR\nStatus: $JOB_STATUS"
  else
    BODY_MESSAGE="Your scheduled MongoDB backup encountered an error.\n\nBackup directory (may be incomplete): $BACKUP_DIR\nStatus: $JOB_STATUS"
  fi

  EMAIL_SUBJECT="$SUBJECT_PREFIX - $SUBJECT_STATUS - $TIMESTAMP"

  # Default from address to SMTP user if not set
  if [ -z "$ALERT_FROM" ]; then
    ALERT_FROM="$SMTP_USER"
  fi

  echo "[INFO] Sending notification email to $ALERT_TO ..."

  sendemail \
    -f "$ALERT_FROM" \
    -t "$ALERT_TO" \
    -u "$EMAIL_SUBJECT" \
    -m "$BODY_MESSAGE" \
    -s "$SMTP_HOST:$SMTP_PORT" \
    -o tls=yes \
    -xu "$SMTP_USER" \
    -xp "$SMTP_PASS" \
    -a "$LOG_FILE" \
    || echo "[WARN] Failed to send notification email."
else
  echo "[INFO] Email notification not configured; skipping email."
fi

echo "[INFO] Job complete."