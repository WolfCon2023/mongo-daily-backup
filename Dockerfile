FROM ubuntu:22.04

# Install MongoDB Database Tools and email utilities
RUN apt-get update && \
    apt-get install -y wget gnupg sendemail libnet-ssleay-perl libio-socket-ssl-perl && \
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" \
      | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get install -y mongodb-database-tools && \
    # Install Node.js so we can run a tiny HTTP API
    apt-get install -y nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy backup script
COPY backup.sh /app/backup.sh

# Copy HTTP server for on-demand backup
COPY server.js /app/server.js

# Normalize Windows line endings and make executable
RUN sed -i 's/\r$//' /app/backup.sh && chmod +x /app/backup.sh

# Default behavior (used by the cron job service): run backup.sh and exit
CMD ["/bin/sh", "/app/backup.sh"]