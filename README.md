# Mongo Daily Backup Job (Railway)

This repo contains a small Dockerized job that runs `mongodump` on a schedule in Railway,
stores backups on a mounted volume, and emails a log file attachment after each run.

## Files

- `backup.sh`  — Shell script that:
    - Creates a timestamped backup directory under `/data/backups`
    - Runs `mongodump --uri="$MONGO_URI"`
    - Cleans backups older than 7 days
    - Writes output to `backup.log`
    - Sends an email (with `backup.log` attached) using SMTP settings

- `Dockerfile` — Builds a minimal Ubuntu image with:
    - MongoDB Database Tools (for `mongodump`)
    - `sendemail` and SSL libs for SMTP
    - Runs `backup.sh` as the container's command

## Required Environment Variables (Railway Service)

- `MONGO_URI`   — Full MongoDB connection URI
- `SMTP_HOST`   — SMTP host (e.g., `smtp.ionos.com`)
- `SMTP_PORT`   — SMTP port (e.g., `587`)
- `SMTP_SECURE` — `tls` or `ssl` (for STARTTLS use `tls`)
- `SMTP_USER`   — SMTP username (e.g., `contactwcg@wolfconsultingnc.com`)
- `SMTP_PASS`   — SMTP password or app password

Optional:

- `ALERT_FROM`  — From address (defaults to `SMTP_USER` if not set)
- `ALERT_TO`    — Recipient address (e.g., `contactwcg@wolfconsultingnc.com`)

## Railway Setup

1. Create a new service from this repo.
2. Attach a Volume and mount it at `/data/backups`.
3. Set the environment variables listed above.
4. Create a Cron Trigger with your desired schedule (e.g. `0 5 * * *` for midnight EST).
5. Check logs after the first run and verify:
    - Backup directory is created under `/data/backups`
    - Email arrives with `backup.log` attached

## Restoring from a Backup

On any machine with `mongorestore` installed:

```bash
mongorestore --uri="YOUR_MONGO_URI" /path/to/backup-folder
```

For example:

```bash
mongorestore --uri="mongodb+srv://user:pass@cluster/db" ./2025-02-05_00-00-01
```
