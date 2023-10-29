#!/bin/bash

# Read configuration from backup_config.conf file
source backup-aio.conf

# Destination directory (the location where you want to store the backup)
DESTINATION_DIR="$DESTINATION_USER@$DESTINATION_IP:$DESTINATION_FOLDER"

# Rsync options: -a (archive mode), -v (verbose)
RSYNC_OPTIONS="-av --delete"

# Array to collect backup results
backup_results=()

# Function to display status message in green
function display_success {
    echo -e "\e[32m[ $(date +'%Y-%m-%d %H:%M:%S') ] $1\e[0m"
}

# Function to display error message in red
function display_error {
    echo -e "\e[31m[ $(date +'%Y-%m-%d %H:%M:%S') ] $1\e[0m"
}

# Function to send notification to healthchecks.io
function send_healthcheck_notification {
    curl -fsS -m 10 --retry 5 "$HEALTHCHECKS_IO_URL" > /dev/null
}

# Function to send Telegram notification
function send_telegram_notification {
    local message="$1"
    curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_API_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID&text=$message&parse_mode=Markdown" > /dev/null
}

convert_bytes() {
    local bytes="$1"
    local result=""

    if ((bytes < 1024)); then
        result="${bytes} bytes"
    elif ((bytes < 1048576)); then
        result="$(bc -l <<< "scale=2; $bytes / 1024") KB"
    elif ((bytes < 1073741824)); then
        result="$(bc -l <<< "scale=2; $bytes / 1048576") MB"
    else
        result="$(bc -l <<< "scale=2; $bytes / 1073741824") GB"
    fi

    echo "$result"
}

# Get start time
START_TIME=$(date +"%s")

# Loop through each source directory and perform backup
for SOURCE_DIR in "${SOURCE_DIRS[@]}"
do
    display_success "Backing up: $SOURCE_DIR"

    # Run rsync command to synchronize data
    result=""
    rsync_output=$(rsync $RSYNC_OPTIONS "$SOURCE_DIR" "$DESTINATION_DIR" 2>&1)

    if [ $? -eq 0 ]; then
        display_success "Backup completed: $SOURCE_DIR"
        
        sentBytes=$(echo "$rsync_output" | grep -oP 'sent \K[0-9]+')
        totalBytes=$(echo "$rsync_output" | grep -oP 'total size is \K[0-9]+')
        result="*Backup completed*: $SOURCE_DIR%0A"
        result+="Amount sent: $(convert_bytes $sentBytes)%0A"
        result+="Total Size: $(convert_bytes $totalBytes)%0A"
    else
        display_error "Backup failed: $SOURCE_DIR"
        result="*Backup failed*: $SOURCE_DIR"
        send_healthcheck_notification
        send_telegram_notification "Backup failed for $SOURCE_DIR"
        exit 1
    fi

    backup_results+=("$result")
done

display_success "All backups completed successfully!"

# Get end time
END_TIME=$(date +"%s")

# Calculate time taken
ELAPSED_TIME=$((END_TIME - START_TIME))

# Format time taken
ELAPSED_TIME_FORMATTED=$(date -d@$ELAPSED_TIME -u +%H:%M:%S)

# Prepare summary message
summary_message="*Backup summary:*%0A%0A"

for backup_result in "${backup_results[@]}"; do
    summary_message+="• $backup_result%0A"
done

summary_message+="_Time taken:_ $ELAPSED_TIME_FORMATTED"

# Send summary notification
send_telegram_notification "$summary_message"
