# Day 18 - Shell Script: Log Cleanup, Backup & Crontab

> **In short:** Apps write logs all the time, so log files keep growing and fill the disk. As daily maintenance, a script deletes **`.log` files older than 14 days** from `/var/log/roboshop`. The script checks its inputs first (was a folder given? does it exist?), finds the old files with `find`, says so if there are none, and otherwise deletes them and shows each one. A safer **backup** script first compresses the old logs into a `.tar.gz` in another folder and deletes them **only if** the archive worked. **crontab** runs these scripts automatically at low-traffic times, but cron has a **minimal PATH**, so use full paths.

**More in this folder:** [Interview questions](interview-questions/README.md)

## Table of Contents

1. [The problem: logs fill the disk](#the-problem-logs-fill-the-disk)
2. [Questions to ask before writing the script](#questions-to-ask-before-writing-the-script)
3. [Algorithm: the 5 steps](#algorithm-the-5-steps)
4. [Make test files with old dates (touch -d)](#make-test-files-with-old-dates-touch--d)
5. [find: search for old .log files](#find-search-for-old-log-files)
6. [The script: cleanup.sh](#the-script-cleanupsh)
7. [2 bugs I found in the class script](#2-bugs-i-found-in-the-class-script)
8. [Run it and check the result](#run-it-and-check-the-result)
9. [Schedule it with crontab](#schedule-it-with-crontab)
   - [The 5 time fields](#the-5-time-fields)
   - [crontab commands](#crontab-commands)
   - [Add the cleanup job](#add-the-cleanup-job)
   - [Cron's PATH is different from my terminal](#crons-path-is-different-from-my-terminal)
10. [Backup script: compress old logs, then delete](#backup-script-compress-old-logs-then-delete)
    - [Algorithm: the 6 steps](#algorithm-the-6-steps)
    - [&& vs ||](#-vs-)
    - [Timestamp in the archive name](#timestamp-in-the-archive-name)
    - [The script: backup.sh](#the-script-backupsh)
    - [Run it and check](#run-it-and-check)
11. [What I learned](#what-i-learned)
12. [Interview Questions](#interview-questions)

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
1. Did the user pass a source folder?      no  → print usage, exit 1   ([ -z "$source_dir" ])
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

This is the class script, with **2 small fixes** marked `# FIX` (see [2 bugs I found](#2-bugs-i-found-in-the-class-script)).

```bash
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
```

| Code | Meaning |
|---|---|
| `$1`, `$2` | 1st and 2nd argument |
| `${2:-14}` | use `$2`; if the user didn't pass it, use `14` (default) |
| `usage(){ ... }` | function that prints how to run the script, then `exit 1` |
| `$0` | the script's own name (e.g. `cleanup.sh`) |
| `[ -z "$source_dir" ]` | true if the variable is **empty** (no argument passed) |
| `[ ! -d "$source_dir" ]` | true if the folder does **not** exist |
| `while IFS= read -r line` | read the list **one line (one file) at a time** |
| `IFS=` | keep spaces at the start/end of the line |
| `-r` | keep `\` as a normal character |
| `exit 1` / `exit 0` | stop with failure / success |

**`<` vs `<<<`: what goes into the loop**

| Symbol | Input comes from | Example |
|---|---|---|
| `<` | a **file** | `done < files.txt` |
| `<<<` | a **variable** (here-string) | `done <<< "$files_to_delete"` |

## 2 bugs I found in the class script

**Definition:** **Word splitting** = bash splits an **unquoted** variable at spaces into separate words.

| # | Class code | Problem | What happened in my test | Fix |
|---|---|---|---|---|
| 1 | no `exit` after `does not exist` | script keeps going | printed the error, then `find: '/nope': No such file or directory`, `No log files found`, **exit 0** (looks like success) | add `exit 1` |
| 2 | `rm -f $line` (no quotes) | file names with spaces split | for `my app.log`, bash ran `rm -f roboshop/my app.log` → **deleted a different file `my`**, and `my app.log` stayed | `rm -f "$line"` |

> Rule: **always quote variables** (`"$var"`), especially in `rm`.

## Run it and check the result

```bash
sudo sh cleanup.sh                          # step 1 fails
sudo sh cleanup.sh /var/log/nope            # step 2 fails
sudo sh cleanup.sh /var/log/roboshop        # days not given → 14, deletes old files
sudo sh cleanup.sh /var/log/roboshop 14     # run again: nothing left
ls /var/log/roboshop
```

| Run | Output | Exit code |
|---|---|---|
| no arguments | `ERROR:: Missing parameters`<br>`USAGE:: cleanup.sh [SOURCE_DIR] [days(Optional, default to 14 days)]` | 1 |
| folder doesn't exist | `ERROR:: /var/log/nope does not exist` | 1 |
| first real run | `Scanning files older than 14 in /var/log/roboshop`<br>`File is going to be deleted: /var/log/roboshop/shipping.log`<br>`File deleted: /var/log/roboshop/shipping.log`<br>`File is going to be deleted: /var/log/roboshop/cart.log`<br>`File deleted: /var/log/roboshop/cart.log` | 0 |
| second run | `No log files found older than 14` | 0 |
| `ls` after | `payment.log  shipping.java  user.js` | |

> **Why `sudo`?** `/var/log` belongs to root, so deleting files there needs root.
> **`sh` vs `bash`:** on RHEL / Amazon Linux `sh` is bash, so `sh cleanup.sh` works. On Ubuntu `sh` is `dash`: `echo -e` and `<<<` break, so run `bash cleanup.sh` there.

## Schedule it with crontab

**Definition:** **crontab** = used to **schedule scripts** in Linux. The cron service runs each entry automatically at the time you set.

In real projects nobody runs the cleanup by hand every day. A **cron job** runs it automatically, usually at **low-traffic times** (e.g. 2 AM), so it doesn't slow the app down for users.

### The 5 time fields

```
 ┌───────── minute        (0-59)
 │ ┌─────── hour          (0-23)
 │ │ ┌───── day of month  (1-31)
 │ │ │ ┌─── month         (1-12)
 │ │ │ │ ┌─ day of week   (0-7, 0 and 7 = Sunday)
 │ │ │ │ │
 * * * * *   command
```

`*` = every value.

| Expression | Runs |
|---|---|
| `* * * * *` | every minute (good for testing) |
| `*/5 * * * *` | every 5 minutes |
| `0 2 * * *` | every day at 02:00 |
| `0 2 * * 0` | every Sunday at 02:00 |
| `0 0 1 * *` | 1st of every month at 00:00 |

### crontab commands

| Command | Does |
|---|---|
| `crontab -e` | edit my cron jobs (opens an editor) |
| `crontab -l` | list my cron jobs |
| `crontab -r` | ⚠️ **removes all** my cron jobs |
| `sudo crontab -e` | edit **root's** cron jobs (needed for `/var/log`) |

### Add the cleanup job

```bash
sudo crontab -e
```
```
0 2 * * * /bin/bash /home/ec2-user/cleanup.sh /var/log/roboshop 14 >> /tmp/cleanup.log 2>&1
```

| Part | Meaning |
|---|---|
| `0 2 * * *` | every day at 02:00 |
| `/bin/bash /home/ec2-user/cleanup.sh` | **full paths**: cron doesn't start in my folder and has a small PATH |
| `>> /tmp/cleanup.log 2>&1` | save output and errors; cron has no screen, so without this I can't see what happened |

Check it ran: `cat /tmp/cleanup.log`. On RHEL, cron's own log is `/var/log/cron`.

### Cron's PATH is different from my terminal

**Definition:** **`$PATH`** = the list of folders Linux searches to find a command (`aws`, `tar`, ...).

| Where | PATH |
|---|---|
| My terminal (`echo $PATH`) | `/home/ec2-user/.local/bin:/home/ec2-user/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin` |
| Cron | `/usr/bin:/bin` ← **minimal** |

So a command in `/usr/local/bin` (for example `aws`) works in the terminal but **not** in cron.

**Class example:**

| Server | Cron PATH has `/usr/local/bin`? | Result |
|---|---|---|
| Development | ✅ yes (someone set it) | script worked |
| Production | ❌ no | script **failed**: command not found |

Same script, different result, because the cron PATH was different. I tested it on my laptop with cron's PATH:

```bash
env -i PATH=/usr/bin:/bin bash -c 'aws --version'
# bash: line 1: aws: command not found      (exit 127)
env -i PATH=/usr/bin:/bin bash -c '/usr/local/bin/aws --version'
# aws-cli/2.x ...                            (works)
```

**Fixes (use one):**

| Fix | How |
|---|---|
| Full paths in the script | `/usr/local/bin/aws` instead of `aws` (find it with `which aws`) |
| Set PATH at the top of the crontab | `PATH=/usr/local/bin:/usr/bin:/bin` as the first line of `crontab -e` |
| Set PATH at the top of the script | `export PATH=/usr/local/bin:/usr/bin:/bin` |

> Lesson: "it works in the terminal" doesn't mean it works in cron. Test with cron's PATH, and set PATH the **same on dev and prod**.

## Backup script: compress old logs, then delete

**Definition:** **Archive / backup** = pack old files into one compressed file (`.tar.gz`) and keep it somewhere safe **before** deleting the originals.

Deleting old logs loses them forever. A safer job: **compress** them into a backup folder first, and delete them **only if** the archive was created.

```bash
sh backup.sh <source_dir> <dest_dir> [days]
sh backup.sh /var/log/roboshop /home/ec2-user/backup 14
```

### Algorithm: the 6 steps

```
1. Did the user give source_dir AND dest_dir?    no  → usage, exit 1
2. Do both directories exist?                    no  → error, exit 1
3. Find *.log files older than 14 days           none → "no files", exit 0
4. Compress them into dest_dir (.tar.gz)
5. Archive created OK?                           yes → delete the files in source_dir
6.                                               no  → DON'T delete, error, exit 1
```

Step 6 is the key: if the backup failed and we still deleted, the logs would be **gone with no copy**.

### && vs ||

**Definition:** `&&` (AND) is true only if **both** sides are true; `||` (OR) is true if **at least one** side is true.

| Left | Right | `&&` | `\|\|` |
|---|---|---|---|
| true | true | ✅ true | ✅ true |
| true | false | ❌ false | ✅ true |
| false | true | ❌ false | ✅ true |
| false | false | ❌ false | ❌ false |

**Which one for step 1?** The script needs **both** folders, so show the error if **either one** is missing → use `||`:

```bash
if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then    # ✅ catches one OR both missing
```

> ⚠️ My rough notes had `[ -z "$source_dir" ] && [ -z "$dest_dir" ]`. That is only true when **both** are missing. I tested `sh backup.sh /a` (no dest): `&&` → **not caught**, the script keeps going; `||` → caught.

### Timestamp in the archive name

**Definition:** `date +FORMAT` prints the current date/time in the format you choose.

```bash
date +%Y-%m-%d-%H-%M-%S        # 2026-10-30-18-56-55
```

| Code | Means |
|---|---|
| `%Y` `%m` `%d` | year, month, day |
| `%H` `%M` `%S` | hour, minute, second |

The name becomes `app-logs-2026-10-30-18-56-55.tar.gz`. Each run gets a **unique** name, so it never overwrites an older backup.

> ⚠️ Don't use `:` in the name (`logs-2026-10-23-02:40:53.tar.gz` from my rough notes). tar thinks `name:path` is a **remote host**. I tested it: `tar (child): Cannot connect to logs-2026-10-23-02: resolve failed`. Use `-` (as the `date` format above does).

### The script: backup.sh

```bash
#!/bin/bash

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
source_dir=$1
dest_dir=$2
days=${3:-14} # if user is not passing days, we will take 14 days as default

usage(){
    echo -e "${R}USAGE:: $0 <SOURCE_DIR> <DEST_DIR> [days(Optional, default to 14 days)]${N}"
    exit 1
}

# 1. user gave source_dir and dest_dir or not
if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
    echo -e "${R}ERROR:: Missing parameters${N}"
    usage
fi

# 2. both directories exist or not
if [ ! -d "$source_dir" ]; then
    echo -e "${R}ERROR:: $source_dir does not exist${N}"
    exit 1
fi

if [ ! -d "$dest_dir" ]; then
    echo -e "${R}ERROR:: $dest_dir does not exist${N}"
    exit 1
fi

# 3. find the files
echo "Scanning files older than $days days in $source_dir"
files=$(find "$source_dir" -name "*.log" -type f -mtime +$days)

if [ -z "$files" ]; then
    echo -e "${Y}No log files found older than $days days${N}"
    exit 0
fi

# 4. compress them and place in dest_dir
timestamp=$(date +%Y-%m-%d-%H-%M-%S)
zip_file="$dest_dir/app-logs-$timestamp.tar.gz"
echo "Compressing into $zip_file"
echo "$files" | tar -czf "$zip_file" -T -

# 5. if successfully placed, delete in source_dir
# 6. if error, don't delete the files
if [ $? -eq 0 ] && [ -f "$zip_file" ]; then
    echo -e "${G}Archive created: $zip_file${N}"
    while IFS= read -r file
    do
        echo "Deleting: $file"
        rm -f "$file"
    done <<< "$files"
else
    echo -e "${R}ERROR:: Archive failed, files are NOT deleted${N}"
    exit 1
fi
```

| Code | Meaning |
|---|---|
| `tar -czf <file>` | **c**reate an archive, g**z**ip-compress it, write it to **f**ile |
| `echo "$files" \| tar ... -T -` | tar reads the list of files from the pipe (`-T -`), one per line, so names with spaces are safe |
| `$?` | exit code of the last command (tar): `0` = success |
| `[ -f "$zip_file" ]` | the archive file really exists |
| `tar -tzf <file>` | lists what's inside an archive (to check it) |

### Run it and check

I tested it on my laptop with the same test files (`cart.log`, `shipping.log` old, `payment.log` new):

| Run | Output | Exit | Files in source after |
|---|---|---|---|
| `backup.sh src` (no dest) | `ERROR:: Missing parameters` + `USAGE:: ...` | 1 | all 3 |
| `backup.sh src nope` | `ERROR:: nope does not exist` | 1 | all 3 |
| dest not writable (`chmod 555 dest`) | `tar ... Cannot open: Permission denied`<br>`ERROR:: Archive failed, files are NOT deleted` | 1 | all 3 ✅ (nothing lost) |
| `backup.sh src dest` | `Archive created: dest/app-logs-2026-10-30-18-56-55.tar.gz`<br>`Deleting: src/shipping.log`<br>`Deleting: src/cart.log` | 0 | `payment.log` |
| run again | `No log files found older than 14 days` | 0 | `payment.log` |

`tar -tzf dest/app-logs-*.tar.gz` → `src/shipping.log`, `src/cart.log`: the backup has both files.

Schedule it the same way:

```
0 2 * * * /bin/bash /home/ec2-user/backup.sh /var/log/roboshop /home/ec2-user/backup 14 >> /tmp/backup.log 2>&1
```

## What I learned

- Logs grow every day, so deleting old ones is daily maintenance.
- Before coding, answer 3 questions: **which location, which extension, how many days old**.
- Write the steps (algorithm) first: check input → check folder exists → find → nothing found? → delete and show.
- `touch -d <date>` makes test files with old dates.
- `find <dir> -type f -name "*.log" -mtime +14` finds `.log` files older than 14 days.
- A file is deleted only if it's **both** a `.log` and old enough.
- `${2:-14}` gives a default value when the user skips an argument.
- `<` feeds a file into a loop, `<<<` feeds a variable.
- Always quote variables in `rm`: `rm -f $line` with a space in the name deleted the wrong file.
- **crontab** schedules scripts; real cleanup jobs run from cron at low-traffic times, not by hand.
- Cron's PATH is minimal (`/usr/bin:/bin`): a script that works in the terminal (and on dev) can fail in cron (on prod). Use full paths or set PATH.
- Backup = compress first, delete **only if** the archive succeeded; if it fails, keep the files.
- `&&` = both must be true, `||` = one is enough. "Both folders are required" → error if `-z src || -z dest`.
- `date +%Y-%m-%d-%H-%M-%S` makes a unique archive name; no `:` in tar file names.

## Interview Questions

See [interview-questions/README.md](interview-questions/README.md).
