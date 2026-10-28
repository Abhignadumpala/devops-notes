# Day 17 - Troubleshooting

[← Back to Day 17 notes](../README.md)

Real problems I hit while building RoboShop v2 (`03-mysql.sh`, `04-rabbitmq.sh`), what each error meant, and how I fixed it.

## Table of Contents

1. [`cannot stat 'rabbitmq.repo'`: validate stopped the script](#1-cannot-stat-rabbitmqrepo-validate-stopped-the-script)
2. [How my validate function stopped the script](#2-how-my-validate-function-stopped-the-script)
3. [Safe to run again: the RabbitMQ user check](#3-safe-to-run-again-the-rabbitmq-user-check)
4. [`Unit mysql.service could not be found`](#4-unit-mysqlservice-could-not-be-found)
5. [`images/` folder not showing in `git status`](#5-images-folder-not-showing-in-git-status)
6. [Removing a file I already pushed](#6-removing-a-file-i-already-pushed)
7. [Quick Checklist](#quick-checklist)

---

## 1. `cannot stat 'rabbitmq.repo'`: validate stopped the script

**Definition:** `cannot stat` = `cp` could not find the source file. *stat* is the system call that reads a file's details; if the file isn't there, it fails.

**What I saw** (on the rabbitmq server, inside `shellscript-roboshop-v2`):
```text
[ root@rabbitmq ~/shellscript-roboshop-v2 ]# bash 04-rabbitmq.sh
2026-10-28 20:19:10 [INFO] ==== Script started Execution =====
cp: cannot stat 'rabbitmq.repo': No such file or directory
adding rabbitmq repo..FAILED
```

**How I found the cause:**

| Step | Command | Result |
|---|---|---|
| 1. Read the error | - | `cp` can't find `rabbitmq.repo` |
| 2. Am I in the right folder? | `pwd` | `/root/shellscript-roboshop-v2` ✅ |
| 3. Is the file there? | `ls` | `01-mongodb.sh 02-redis.sh 03-mysql.sh 04-rabbitmq.sh common.sh mongo.repo roboshop.sh` ❌ no `rabbitmq.repo` |

**Cause:** I wrote `04-rabbitmq.sh` but **never added `rabbitmq.repo` to the repo**. The server only gets what's in GitHub.

**Fix: always at the source (laptop), never only on the server:**

```text
laptop                         GitHub                    rabbitmq server
create rabbitmq.repo  ──push──►  3a92459  ──git pull──►  rabbitmq.repo ✅
                                                          bash 04-rabbitmq.sh
```

```bash
# laptop
git add rabbitmq.repo
git commit -m "Add rabbitmq.repo"
git push

# server
git pull                  # 367f9f0..3a92459  create mode 100644 rabbitmq.repo
bash 04-rabbitmq.sh
```

**Result after the fix:**
```text
2026-10-28 20:21:21 [INFO] ==== Script started Execution =====
adding rabbitmq repo..SUCCESS
installing rabbitmq server..SUCCESS
starting and enabling rabbitmq server..SUCCESS
Creating RabbitMQ user for Roboshop..SUCCESS
Setting permissions for RabbitMQ user for Roboshop..SUCCESS
2026-10-28 20:24:22 [INFO] Script completed in 181 seconds
```

| | Time |
|---|---|
| First failure | 20:19:10 |
| Fixed run started | 20:21:21 |
| Time to find + fix | **~2 minutes** |

Why I didn't just create the file on the server: the next server I build would have the same problem, and `git pull` could later refuse because of a local file. **Fix in Git, then pull.**

## 2. How my validate function stopped the script

**Definition:** `$?` = the exit status of the **last** command. `0` = success, anything else = failure.

**My `validate` in `common.sh`:**
```bash
validate(){
    if [ $1 -ne 0 ]; then                                   # $1 = exit status ($?)
        echo -e "${2}..${R}FAILED${N}" | tee -a $logs_file  # $2 = step name
        exit 1                                              # stop the whole script
    else
        echo -e "${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}
```

**In `04-rabbitmq.sh`:**
```bash
cp rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo
validate $? "adding rabbitmq repo"
```

**What happened step by step:**

| # | What ran | Value |
|---|---|---|
| 1 | `cp rabbitmq.repo ...` | fails, prints `cannot stat` |
| 2 | `$?` | `1` (not 0) |
| 3 | `validate 1 "adding rabbitmq repo"` | `1 -ne 0` is true |
| 4 | prints | `adding rabbitmq repo..FAILED` (also written to `/var/log/roboshop/04-rabbitmq.sh.log`) |
| 5 | `exit 1` | **script stops**: `dnf install`, `systemctl`, `rabbitmqctl` never run |

**Without validate** the script would carry on:

| Step | With validate ✅ | Without validate ❌ |
|---|---|---|
| copy repo | FAILED → stop | error, keeps going |
| `dnf install rabbitmq-server` | not run | fails: `No match for argument` (no repo) |
| `systemctl start rabbitmq-server` | not run | fails: unit not found |
| `rabbitmqctl add_user` | not run | fails: command not found |
| What I see | **1 clear error at the real cause** | 4 errors; the real one is buried at the top |

**Rule:** stop at the **first** failure. The first error is the real cause; everything after it is just a side effect.

## 3. Safe to run again: the RabbitMQ user check

**Definition:** *idempotent* = running a script twice gives the same result as running it once, without new errors.

`rabbitmqctl add_user` fails if the user already exists, so my script checks first:
```bash
rabbitmqctl list_users | grep -qw "roboshop"
if [ $? -ne 0 ]; then
     rabbitmqctl add_user roboshop <rabbitmq-password> &>> $logs_file
     validate $? "Creating RabbitMQ user for Roboshop"
else
    echo -e "$(timestamp) [INFO] RabbitMQ user already exist...${Y}SKIPPING${N}" | tee -a $logs_file
fi
```

| Flag | Meaning |
|---|---|
| `grep -q` | quiet: print nothing, only set `$?` (0 = found) |
| `grep -w` | whole word: `roboshop` doesn't match `roboshop2` |

| Run | User exists? | Output |
|---|---|---|
| 1st (after the fix) | no | `Creating RabbitMQ user for Roboshop..SUCCESS` |
| 2nd, 3rd... | yes | `RabbitMQ user already exist...SKIPPING` |

The two failed runs before the fix stopped at step 1, so they never reached this part.

## 4. `Unit mysql.service could not be found`

**What I saw** (right after `03-mysql.sh` finished with all SUCCESS in **25 seconds**):
```text
[ root@mysql ~/shellscript-roboshop-v2 ]# systemctl status mysql
Unit mysql.service could not be found.
```

**Cause:** wrong name. MySQL was running fine. On RHEL the **service** is `mysqld` (*d* = daemon, a background process). `mysql` is the **client** I log in with.

**Fix:**
```bash
systemctl status mysqld
ss -lntp | grep 3306
```

**Find the real name yourself:**
```bash
systemctl list-units --type=service | grep -i mysql
grep -i systemctl 03-mysql.sh            # the name my script started is the real one
```

| App | Service name | Client / tool | Port |
|---|---|---|---|
| MySQL | `mysqld` | `mysql` | 3306 |
| MongoDB | `mongod` | `mongosh` | 27017 |
| Redis | `redis` | `redis-cli` | 6379 |
| RabbitMQ | `rabbitmq-server` | `rabbitmqctl` | 5672 (15672 UI) |

## 5. `images/` folder not showing in `git status`

**What I saw:**
```text
$ mkdir images
$ git status
nothing to commit, working tree clean
```

**Cause:** Git tracks **files**, not folders. An empty folder has nothing to save.

**Fix:** put a file in it:
```bash
cp ~/Pictures/Screenshots/<file>.png images/03-mysql-running.png
git status        # Untracked files: images/
```
Empty folder I still want in Git → `touch images/.gitkeep` (just a naming habit, any file works).

## 6. Removing a file I already pushed

I pushed a trial image (`images/roboshop.png`) and wanted it gone.

```bash
git rm images/roboshop.png        # delete + stage the deletion in one step
git commit -m "Remove trial image"
git push
```

| | Result |
|---|---|
| GitHub + my laptop | file gone |
| `images/` folder | gone too: it became empty |
| Git history | old commit still has the image (fine for a trial; removing it means rewriting history + force push) |

`git rm` vs `rm`: `rm` only deletes from disk, then I still need `git add`. `git rm` does both.

## Quick Checklist

When a RoboShop script fails:

1. Read the **first** FAILED line. That's the real cause.
2. `cat /var/log/roboshop/<script>.log`: the full error is there.
3. `cannot stat` / `No such file` → `pwd`, `ls`: is the file in the repo?
4. Missing file → add it on the **laptop**, push, `git pull` on the server, run again.
5. `Unit ... could not be found` → wrong service name: `systemctl list-units | grep <name>`.
6. Before pushing: `git status`. Every file the script uses must be committed.
