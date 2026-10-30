#!/bin/bash

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
source_dir=$1
days=${2:-14} # if user is not passing days, we will take 14 days as default

usage(){
    echo -e "${R}USAGE:: $0 [SOURCE_DIR] [days(Optional, default to 14 days)]${N}"
    exit 1
}

# 1. user passed source dir or not
if [ -z "$source_dir" ]; then
    echo "ERROR:: Missing parameters"
    usage
fi

# 2. source dir exists or not
if [ ! -d "$source_dir" ]; then
    echo -e "${R}ERROR:: $source_dir does not exist${N}"
    exit 1                                  # FIX 1: stop here
fi

# 3. find the files
echo "Scanning files older than $days in $source_dir"
files_to_delete=$(find "$source_dir" -name "*.log" -type f -mtime +$days)

# 4. no files found
if [ -z "$files_to_delete" ]; then
    echo "No log files found older than $days"
    exit 0
fi

# 5. delete files and show to user
while IFS= read -r line
do
    echo "File is going to be deleted: $line"
    rm -f "$line"                           # FIX 2: quotes
    echo "File deleted: $line"
done <<< "$files_to_delete"

# < -> for file inputs
# <<< -> variable as input
