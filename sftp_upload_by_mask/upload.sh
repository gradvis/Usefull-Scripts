#!/bin/bash

# Load configuration variables
source /path/to/script_config.cfg

# Check if the mapping configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found. Exiting." | tee -a "$LOGFILE"
    exit 1
else
    echo "Configuration file loaded: $CONFIG_FILE" | tee -a "$LOGFILE"
fi

# Function to read the mapping configuration file
declare -A config_map
read_config() {
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        config_map["$key"]="$value"
    done < "$CONFIG_FILE"
}

# Read the mapping configuration file
read_config

# Connect to the remote server
echo "Mounting remote directory $REMOTE_SERVER" | tee -a "$LOGFILE"
sshfs "$REMOTE_USER@$REMOTE_SERVER:/" "$MOUNT_DIR" -o IdentityFile="$PRIVATE_KEY_PATH"
if [ $? -eq 0 ]; then
    echo "Remote directory mounted successfully." | tee -a "$LOGFILE"
else
    echo "Failed to mount remote directory. Exiting." | tee -a "$LOGFILE"
    exit 1
fi

# Delete all files in the remote directories
echo "Deleting all files in remote directories" | tee -a "$LOGFILE"
find "$MOUNT_DIR" -type f -print0 | xargs -0 rm -f
if [ $? -eq 0 ]; then
    echo "All files deleted successfully." | tee -a "$LOGFILE"
else
    echo "Error deleting files." | tee -a "$LOGFILE"
    exit 1
fi

# Function to check and create a directory on the remote server
ensure_remote_directory() {
    local remote_path="$MOUNT_DIR/$1"
    if [ ! -d "$remote_path" ]; then
        echo "Directory $remote_path does not exist. Creating directory." | tee -a "$LOGFILE"
        mkdir -p "$remote_path"
        if [ $? -eq 0 ]; then
            echo "Directory $remote_path created successfully." | tee -a "$LOGFILE"
        else
            echo "Failed to create directory $remote_path." | tee -a "$LOGFILE"
            exit 1
        fi
    fi
}

# Function to copy files and log the results
transfer_files() {
    local mask="$1"
    local remote_dir="$2"
    find "$SOURCE_DIR" -type f -name "$mask" -print0 | while IFS= read -r -d $'\0' file; do
        local subdir=$(basename "$(dirname "$file")")
        local target_prefix=${config_map["$subdir"]}
        if [ -z "$target_prefix" ]; then
            echo "No configuration for directory $subdir. Skipping." | tee -a "$LOGFILE"
            continue
        fi
        local remote_path="$MOUNT_DIR/$target_prefix/$remote_dir/$(basename "$file")"
        ensure_remote_directory "$target_prefix/$remote_dir"
        echo "Transferring file $file to $remote_path" | tee -a "$LOGFILE"
        if cp "$file" "$remote_path"; then
            echo "Success: file $file copied to $remote_path" | tee -a "$LOGFILE"
        else
            echo "Error: failed to copy file $file to $remote_path" | tee -a "$LOGFILE"
        fi
    done
}

# Start logging
echo "Starting file transfer: $(date)" | tee -a "$LOGFILE"

# Transfer files based on masks
transfer_files "*_file_mask1_*" "$REMOTE_DIR_1"
transfer_files "*_file_mask2_*" "$REMOTE_DIR_2"
transfer_files "*_file_mask3_*" "$REMOTE_DIR_3"

echo "File transfer completed: $(date)" | tee -a "$LOGFILE"

# Disconnect from the remote server
echo "Unmounting remote directory $REMOTE_SERVER" | tee -a "$LOGFILE"
fusermount -u "$MOUNT_DIR"
