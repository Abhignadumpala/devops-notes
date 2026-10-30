#!/bin/bash

# read a file line by line and print each line
while IFS= read -r line
do
    echo $line
done < 02-conversation.sh
