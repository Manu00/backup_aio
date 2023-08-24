#!/bin/bash

# Read configuration from backup_config.conf file
source backup-aio.conf

# Destination directory (the location where you want to store the backup)
DESTINATION_DIR="$DESTINATION_USER@$DESTINATION_IP:$DESTINATION_FOLDER"

# Rsync options: -a (archive mode), -v (verbose), -h (human-readable)
RSYNC_OPTIONS="-avh --delete"

# Function to display status message in green
function display_success {
    echo -e "\e[32m[ $(date +'%Y-%m-%d %H:%M:%S') ] $1\e[0m"
}

# Function to display error message in red
function display_error {
    echo -e "\e[31m[ $(date +'%Y-%m-%d %H:%M:%S') ] $1\e[0m"
}

# Function to send notification to healthchecks.io
function send_notification {
    curl -fsS -m 10 --retry 5 "$HEALTHCHECKS_IO_URL" > /dev/null
}

# Loop through each source directory and perform backup
for SOURCE_DIR in "${SOURCE_DIRS[@]}"
do
  display_success "Backing up: $SOURCE_DIR"

  # Run rsync command to synchronize data
  rsync $RSYNC_OPTIONS "$SOURCE_DIR" "$DESTINATION_DIR"

  if [ $? -eq 0 ]; then
      display_success "Backup completed: $SOURCE_DIR"
  else
      display_error "Backup failed: $SOURCE_DIR"
      send_notification
      exit 1
  fi
done

display_success "All backups completed successfully!"

