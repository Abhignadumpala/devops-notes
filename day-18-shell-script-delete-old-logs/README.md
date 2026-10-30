# Day 18 - Shell Script: Delete Old Log Files

> **In short:** Apps write logs all the time, so log files keep growing and fill the disk. As daily maintenance, a script deletes **`.log` files older than 14 days** from `/var/log/roboshop`. The script checks its inputs first (was a folder given? does it exist?), finds the old files with `find`, says so if there are none, and otherwise deletes them and shows each one.

**More in this folder:** [Interview questions](interview-questions/README.md)

## Table of Contents

1. [The problem: logs fill the disk](#the-problem-logs-fill-the-disk)
2. [Questions to ask before writing the script](#questions-to-ask-before-writing-the-script)
3. [Algorithm: the 5 steps](#algorithm-the-5-steps)
4. [Make test files with old dates (touch -d)](#make-test-files-with-old-dates-touch--d)
5. [find: search for old .log files](#find-search-for-old-log-files)
6. [The script: cleanup.sh](#the-script-cleanupsh)
7. [Run it and check the result](#run-it-and-check-the-result)
8. [Run it every day](#run-it-every-day)
9. [What I learned](#what-i-learned)
10. [Interview Questions](#interview-questions)

---

## The problem: logs fill the disk

**Definition:** **Log rotation / cleanup** = regularly removing (or archiving) old log files so they don't use up all the disk space.

```
App (cart, shipping, payment ...) ──writes all day──► /var/log/roboshop/*.log
                                                          │
                                         grows every day  ▼
                                                  disk 100% full → app crashes,
                                                  can't write logs, server issues
```

- Logs are written **continuously**, so their size only grows.
- Old logs are rarely needed, so we keep the recent ones and delete the rest.
- This is **daily maintenance**: the script runs once a day.

| Item | Value |
|---|---|
| Location | `/var/log/roboshop` |
| Files to delete | `*.log` only |
| Age | older than **14 days** |

## Questions to ask before writing the script

**Definition:** **Requirements** = the inputs and rules a script needs before you write any code.

| Question | Answer here | Becomes |
|---|---|---|
| Which **location**? | `/var/log/roboshop` | 1st argument `$1` |
| Which **extension**? | `.log` | `find -name "*.log"` |
| How many **days old**? | 14 | 2nd argument `$2` |

So the user runs:

```bash
sh cleanup.sh /var/log/roboshop 14
#             └── $1 = folder ──┘ └ $2 = days
```

Passing the folder and days as **arguments** (instead of hard-coding them) lets the same script clean any folder.

## Algorithm: the 5 steps

**Definition:** **Algorithm** = the plain-language steps, written before the code.

```
1. Did the user pass a source folder?      no  → print usage, exit 1
2. Does that folder exist?                 no  → print error, exit 1
3. Find *.log files older than 14 days
4. No files found?                         yes → print "no files older than 14 days", exit 0
5. Delete each file and show its name to the user
```

Steps 1 and 2 are **input validation**: check the input first, so the script never runs `find`/`rm` on a wrong path.

## Make test files with old dates (touch -d)

**Definition:** `touch -d <date> file` creates a file (or updates it) with that **modified date**, so you can test the script without waiting 14 days.

```bash
sudo mkdir -p /var/log/roboshop
cd /var/log/roboshop
sudo touch -d 20260101 cart.log        # old  + .log  → DELETE
sudo touch -d 20260101 shipping.log    # old  + .log  → DELETE
sudo touch payment.log                 # new  + .log  → keep (not old)
sudo touch shipping.java               # new  + .java → keep (not .log)
sudo touch -d 20260202 user.js         # old  + .js   → keep (not .log)
ls -l
```

| File | Date | `.log`? | Older than 14 days? | Deleted? |
|---|---|---|---|---|
| cart.log | 2026-01-01 | ✅ | ✅ | ✅ |
| shipping.log | 2026-01-01 | ✅ | ✅ | ✅ |
| payment.log | today | ✅ | ❌ | ❌ |
| shipping.java | today | ❌ | ❌ | ❌ |
| user.js | 2026-02-02 | ❌ | ✅ | ❌ |

A file is deleted **only if both** checks are true. `user.js` is old but not a `.log`, so it stays.

## find: search for old .log files

**Definition:** `find` = searches a folder (and its subfolders) for files that match conditions.

```bash
find /var/log/roboshop -type f -name "*.log" -mtime +14
```

| Part | Meaning |
|---|---|
| `/var/log/roboshop` | where to search |
| `-type f` | files only (not folders) |
| `-name "*.log"` | name ends with `.log` (keep the quotes) |
| `-mtime +14` | **modified** more than 14 days ago |

| `-mtime` | Means |
|---|---|
| `+14` | older than 14 days |
| `-14` | newer than 14 days |
| `14` | exactly 14 days |

> ⚠️ `find . "*.log"` (from my rough notes) is wrong: without `-name`, find treats `"*.log"` as another folder to search. Always write `find . -name "*.log"`.

`find ... -delete` can delete directly, but the script uses a loop so it can **show** each file it deletes.

## The script: cleanup.sh

```bash
#!/bin/bash

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

SOURCE_DIR=$1
DAYS=${2:-14}     # 2nd argument, default 14

# 1. Did the user pass a source directory?
if [ $# -lt 1 ]; then
    echo -e "${R}Usage:${N} sh cleanup.sh <source-dir> [days]"
    exit 1
fi

# 2. Does the directory exist?
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${R}ERROR:${N} $SOURCE_DIR does not exist"
    exit 1
fi

# 3. Find .log files older than $DAYS days
FILES=$(find "$SOURCE_DIR" -type f -name "*.log" -mtime +$DAYS)

# 4. Nothing found?
if [ -z "$FILES" ]; then
    echo -e "${Y}No .log files older than $DAYS days in $SOURCE_DIR${N}"
    exit 0
fi

# 5. Delete each file and show it
while IFS= read -r file; do
    echo -e "Deleting: ${G}$file${N}"
    rm -f "$file"
done <<< "$FILES"
```

| Code | Meaning |
|---|---|
| `$#` | number of arguments passed |
| `$1`, `$2` | 1st and 2nd argument |
| `${2:-14}` | use `$2`, or `14` if it's empty |
| `[ ! -d "$DIR" ]` | true if the folder does **not** exist |
| `[ -z "$FILES" ]` | true if the variable is **empty** |
| `while IFS= read -r file` | read the list **one line (one file) at a time** |
| `<<< "$FILES"` | feed the variable into the loop as input |
| `exit 1` / `exit 0` | stop with failure / success |

## Run it and check the result

```bash
sudo sh cleanup.sh                          # step 1 fails
sudo sh cleanup.sh /var/log/nope 14         # step 2 fails
sudo sh cleanup.sh /var/log/roboshop 14     # deletes the old files
sudo sh cleanup.sh /var/log/roboshop 14     # run again: nothing left
ls /var/log/roboshop
```

| Run | Output | Exit code |
|---|---|---|
| no arguments | `Usage: sh cleanup.sh <source-dir> [days]` | 1 |
| folder doesn't exist | `ERROR: /var/log/nope does not exist` | 1 |
| first real run | `Deleting: /var/log/roboshop/shipping.log`<br>`Deleting: /var/log/roboshop/cart.log` | 0 |
| second run | `No .log files older than 14 days in /var/log/roboshop` | 0 |
| `ls` after | `payment.log  shipping.java  user.js` | |

> **Why `sudo`?** `/var/log` belongs to root, so deleting files there needs root.
> **`sh` vs `bash`:** on RHEL / Amazon Linux `sh` is bash, so `sh cleanup.sh` works. On Ubuntu `sh` is `dash`: `echo -e` and `<<<` break, so run `bash cleanup.sh` there.

## Run it every day

**Definition:** **cron** = Linux scheduler that runs a command at a fixed time (here: every day).

```bash
sudo crontab -e
```
```
# min hour day month weekday  command
  0   2    *   *     *        bash /home/ec2-user/cleanup.sh /var/log/roboshop 14 >> /tmp/cleanup.log 2>&1
```
Runs every day at **02:00** and writes the script's output to `/tmp/cleanup.log`.

## What I learned

- Logs grow every day, so deleting old ones is daily maintenance.
- Before coding, answer 3 questions: **which location, which extension, how many days old**.
- Write the steps (algorithm) first: check input → check folder exists → find → nothing found? → delete and show.
- `touch -d <date>` makes test files with old dates.
- `find <dir> -type f -name "*.log" -mtime +14` finds `.log` files older than 14 days.
- A file is deleted only if it's **both** a `.log` and old enough.

## Interview Questions

See [interview-questions/README.md](interview-questions/README.md).
