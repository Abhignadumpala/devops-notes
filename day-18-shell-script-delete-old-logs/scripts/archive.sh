#!/bin/bash

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
source_dir=$1
dest_dir=$2
days=${3:-14} # if user is not passing days, we will take 14 days as default

usage(){
    echo -e "${R}USAGE:: $0 [SOURCE_DIR] [DEST_DIR] [days(Optional, default to 14 days)]${N}"
    exit 1
}

# 1. user gave source_dir and dest_dir or not
if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
    echo "Either source or destination directory are missing"
    usage
fi

# 2. both directories exist or not
if [ ! -d "$source_dir" ]; then
    echo "Source Directory: $source_dir does not exist"
    exit 1
fi

if [ ! -d "$dest_dir" ]; then
    echo "Destination Directory: $dest_dir does not exist"
    exit 1
fi

# 3. find the files
echo "Scanning files older than $days days in $source_dir"
files_to_archive=$(find "$source_dir" -name "*.log" -type f -mtime +$days)    # FIX: quotes

if [ -z "$files_to_archive" ]; then
    echo "No log files found older than $days days"
    exit 0
fi

# 4. compress them and place in dest_dir
timestamp=$(date +%Y-%m-%d-%H-%M-%S)

file_name="$dest_dir/logs-$timestamp.tar.gz"

tar -czf $file_name $files_to_archive

# 5. if error, don't delete the files
# 6. if successfully archived, delete in source_dir
if [ $? -ne 0 ]; then
    echo "Logs archival is failed"
    exit 1
else
    echo "Logs are archived: $file_name"
    while IFS= read -r line
    do
        echo "File is going to be deleted: $line"
        rm -f "$line"                                                         # FIX: quotes
        echo "File deleted: $line"
    done <<< "$files_to_archive"
fi
