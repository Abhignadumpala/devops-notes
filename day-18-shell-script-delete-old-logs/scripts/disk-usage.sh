#!/bin/bash

disk_usage=$(df -hT | grep -v Filesystem)
usage_threshold=20
server_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

while IFS= read -r line
do
    usage=$(echo $line | awk '{print $6}' | cut -d "%" -f1)
    partition=$(echo $line | awk '{print $7}')
    if [ "$usage" -ge "$usage_threshold" ]; then
        message+="High Disk Usage on $partition: $usage <br>"
    fi
done <<< "$disk_usage"

#echo -e "$message"

sh mail.sh "DevOps Team" "$server_ip" "High Disk Usage" "$message" "<your-to-mail>" "WARNING: High Disk Usage Alert"
