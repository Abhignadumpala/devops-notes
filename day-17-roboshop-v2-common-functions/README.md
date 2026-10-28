# Day 17 - RoboShop v2: Shared Code in common.sh

> **In short:** Same RoboShop project, version 2. In v1 every script repeated the same code (root check, logs, `validate`, colors). In v2 that code lives **once** in `common.sh`, and each script loads it with `source`, so the scripts are short and a fix is made in **one** file. `roboshop.sh` still runs on my **laptop**; each `0X-<name>.sh` runs **on its own server** after `git clone`.

> **Project repo:** [shellscript-roboshop-v2](https://github.com/Abhignadumpala/shellscript-roboshop-v2) · v1: [shellscript-roboshop-v1](https://github.com/Abhignadumpala/shellscript-roboshop-v1) · v1 notes: [Day 16](../day-16-roboshop-shell-scripts/README.md)

**Progress**

| # | Script | Server | Status |
|---|--------|--------|--------|
| 01 | `01-mongodb.sh` | roboshop-mongodb | ✅ first v2 run, 5/5 SUCCESS, **105 s**, `mongodb.abhignadevops.store → 172.31.6.250` |
| 02 | `02-redis.sh` | roboshop-redis | ✅ `0.0.0.0:6379` listening, `redis.abhignadevops.store → 172.31.8.36` |
| 03 | `03-mysql.sh` | roboshop-mysql | ✅ all SUCCESS, **25 s**, `mysqld` on `3306`, `mysql.abhignadevops.store → 172.31.1.79` |
| 04 | `04-rabbitmq.sh` | roboshop-rabbitmq | ✅ all SUCCESS, **181 s** (after fixing a missing `rabbitmq.repo`), `rabbitmq.abhignadevops.store → 172.31.10.202` |
| 05–10 | catalogue … frontend | | ⏳ |

Day 1 ended with mongodb, redis and mysql **stopped** (not terminated). Day 2 (2026-10-28): started them again, ran `03-mysql.sh`, created rabbitmq with `bash roboshop.sh rabbitmq` and ran `04-rabbitmq.sh`.

**More in this folder**

| Folder | What's inside |
|---|---|
| [troubleshooting/](troubleshooting/README.md) | Real errors: `cannot stat rabbitmq.repo` + how `validate` stopped the script, `mysql.service` not found, `images/` not in `git status`, `git rm` |
| [interview-questions/](interview-questions/README.md) | Short answers for interview prep |

## Table of Contents

1. [v1 vs v2: why common.sh](#v1-vs-v2-why-commonsh)
2. [How source works](#how-source-works)
3. [Every file a script uses must be in the v2 repo](#every-file-a-script-uses-must-be-in-the-v2-repo)
4. [Setting up v2 in VS Code](#setting-up-v2-in-vs-code)
5. [roboshop.sh: component name, not script name](#roboshopsh-component-name-not-script-name)
6. [Git: first push, and servers only pull](#git-first-push-and-servers-only-pull)
7. [SSH login (password)](#ssh-login-password)
8. [Checks on a target server](#checks-on-a-target-server)
   - [Service name vs app name](#service-name-vs-app-name)
9. [Stop vs terminate](#stop-vs-terminate)
10. [Images in a repo and README](#images-in-a-repo-and-readme)
11. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
12. [Troubleshooting](#troubleshooting)
13. [What I learned](#what-i-learned)
14. [Interview Questions](#interview-questions)

---

## v1 vs v2: why common.sh

| | v1 | v2 |
|---|---|---|
| Root check, `timestamp`, `validate`, colors, log folder | copied into **every** script | **once** in `common.sh` |
| A fix in shared code | edit up to 10 files | edit **1** file |
| Each script holds | everything | only what's **special** about that component |

**My `common.sh` (so far):**
```bash
#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
scripts_dir=$(dirname "$(realpath "$0")")
domain_name="abhignadevops.store"
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"

check_root(){ ... }          # stop if not root
timestamp(){ date "+%F %T"; }
mkdir -p $logs_folder
validate(){ ... }            # $1 = exit status, $2 = step name → SUCCESS / FAILED + exit 1
total_time(){ ... }          # "Script completed in $SECONDS seconds"
```

**My `01-mongodb.sh` in v2** (only the MongoDB part is left):
```bash
#!/bin/bash

source ./common.sh
check_root

cp mongo.repo /etc/yum.repos.d/mongo.repo
validate $? "Adding mongo repo"

dnf install mongodb-org -y &>> $logs_file
validate $? "Install MongoDB"
...
total_time
```

**Watch out:** the trainer's v2 `common.sh` brings back 4 bugs I already fixed in v1:

| Trainer's v2 | Problem (Day 16 troubleshooting #) | My v1 fix |
|---|---|---|
| `sed -i` on `$scripts_dir/$app_name.service` | edits the repo file → later `git pull` refuses (#33) | `cp` first, `sed` the copy |
| `echo $JAVA_HOME` + `validate $?` | always SUCCESS: `echo` never fails (#24) | `[ -n "$JAVA_HOME" ]` before `validate` |
| `source ./common.sh` | breaks when run from another folder (#11) | `source "$scripts_dir/common.sh"` |
| `logs_file=".../${0}.log"` | wrong path when run with a full path | `$(basename $0)` |

## How source works

`source file` (or `. file`) runs the file **inside the current script**, so its variables and functions become available. `bash file` would run it in a **separate** process and nothing would come back.

`./` means **the folder I'm in when I run the command**, not the script's folder:

| How I run it | `source ./common.sh` |
|---|---|
| `cd shellscript-roboshop-v2` → `bash 01-mongodb.sh` | ✅ found |
| `bash shellscript-roboshop-v2/01-mongodb.sh` from `~` | ❌ `./common.sh: No such file or directory` |

Works from any folder:
```bash
scripts_dir=$(dirname "$(realpath "$0")")
source "$scripts_dir/common.sh"
cp "$scripts_dir/mongo.repo" /etc/yum.repos.d/mongo.repo
```

## Every file a script uses must be in the v2 repo

The server only gets what's in the repo I clone. It never sees v1.

| Script | Needs in v2 |
|---|---|
| all | `common.sh` |
| `01-mongodb.sh` | `mongo.repo` |
| `04-rabbitmq.sh` | `rabbitmq.repo` |
| `05-catalogue.sh` | `catalogue.service`, `mongo.repo` |
| `06-user.sh` / `07-cart.sh` / `08-shipping.sh` / `09-payment.sh` | `user` / `cart` / `shipping` / `payment.service` |
| `10-frontend.sh` | `roboshop.conf` |
| laptop | `roboshop.sh` (only needed in the folder I run it from) |

## Setting up v2 in VS Code

**Two repos in one window:**
```bash
code ~/shellscript-roboshop-v1
code -a ~/shellscript-roboshop-v2      # -a = add to this window
```
(The trainer opened one parent folder `repos/` holding both. Same result; I kept my repos where they are.)

**Copy a file from v1 to v2:** click it → **Ctrl+C** → click the v2 folder → **Ctrl+V**. Ctrl+click / Shift+click for several.
**Drag + hold Ctrl** = copy. Drag **without** Ctrl = **move** (undo with Ctrl+Z).
**Side by side:** right-click a file → **Open to the Side**.

## roboshop.sh: component name, not script name

```bash
bash roboshop.sh mongodb          # ✅ laptop: creates server roboshop-mongodb + DNS
bash roboshop.sh 01-mongodb.sh    # ❌ looks for SG "roboshop-01-mongodb.sh" → groupId empty
bash 01-mongodb.sh                # ✅ ON the mongodb server: installs MongoDB
```

| Name I type | SG used | DNS record |
|---|---|---|
| `mongodb` | `roboshop-mongodb` ✅ | `mongodb.abhignadevops.store` |
| `01-mongodb.sh` | `roboshop-01-mongodb.sh` ❌ | `01-mongodb.sh.abhignadevops.store` |

After `mongodb ID: i-...` the script looks stuck: it's `aws ec2 wait instance-running` (15–60 s).

**Security groups:** all 12 from v1 still exist in the default VPC with their rules, so v2 needed **no new SGs**. Rules use **other SGs as the source**, so they work for new servers with new IPs.

## Git: first push, and servers only pull

```bash
git add common.sh 01-mongodb.sh mongo.repo
git commit -m "Add common.sh, 01-mongodb.sh and mongo.repo"
git push -u origin main      # first push only: -u remembers main → origin/main
git push                     # every push after that
```

- `git commit` **without `-m`** opens an editor; closing it without saving **cancels** the commit (vim: `i`, type, `Esc`, `:wq`).
- Without `-u` once: `fatal: The current branch main has no upstream branch`.

```
laptop ──git push──► GitHub ──git clone / git pull──► server
(write + fix code)              (only reads code)
```

- The practice AMI already has **git** (`git --version`). A plain RHEL AMI needs `dnf install git -y`.
- Servers never push: the repo is public, so no login or keys are needed there.
- After a fix: laptop `git push` → server `git pull` → run again.

## SSH login (password)

Practice AMI `Redhat-9-DevOps-Practice`: no key pair, user `ec2-user`, password from [Day 7](../day-07-3tier-nodejs-expense-app/03-frontend.md).
```bash
ssh ec2-user@<public-ip>      # yes (first time) → password (nothing shows while typing)
sudo su -
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v2.git
cd shellscript-roboshop-v2
bash 01-mongodb.sh
```
`Permission denied (publickey)` → `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ec2-user@<ip>`.
SSH only works from my home IP in `roboshop-common`. Timeout → `curl checkip.amazonaws.com` and compare.

## Checks on a target server

MongoDB and Redis are **targets** (others connect to them). On a target I check the service and how it listens:

| # | Check | MongoDB | Redis | MySQL | RabbitMQ |
|---|---|---|---|---|---|
| 1 | Running? | `systemctl status mongod` | `systemctl status redis` | `systemctl status mysqld` | `systemctl status rabbitmq-server` |
| 2 | Listening for other servers? | `ss -lntp \| grep 27017` → `0.0.0.0:27017` | `ss -lntp \| grep 6379` → `0.0.0.0:6379` | `ss -lntp \| grep 3306` | `ss -lntp \| grep 5672` |
| 3 | Answers locally? | `mongosh --eval 'db.runCommand({ping:1})'` | `redis-cli ping` → `PONG` | `mysql -u root -p` → `show databases;` | `rabbitmqctl list_users` → `roboshop` listed |
| 4 | Errors? | `journalctl -u mongod` | `journalctl -u redis` | `journalctl -u mysqld` | `journalctl -u rabbitmq-server` |

**Two layers decide who can reach it:**

| Layer | Question | Where |
|---|---|---|
| `ss -lntp` | is the door open? `0.0.0.0` = to the network, `127.0.0.1` = only this server | on the server |
| Security group | who may walk to the door? | AWS (the server doesn't know) |

Redis: `0.0.0.0:6379` + SG `roboshop-redis` allows only `roboshop-user` and `roboshop-cart` → only user and cart can reach it.

**`ss -lntp` vs `ss -tnp`:**

| Command | Shows |
|---|---|
| `ss -lntp` | **listening** ports (the open door) |
| `ss -tnp` | **established** connections: who is connected now (Peer Address = caller's IP) |

My `ss -tnp` on redis: `172.31.8.36:22 ← 2.82.252.24:54140 sshd` = **my own SSH session**. No `:6379` line yet: user and cart don't exist. They show up only once the **app is installed and running** (the app connects, not the empty server).

**IP → server name** (Linux only sees IPs; names live in AWS tags and DNS):
```bash
# laptop: all servers with names
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress]' --output table

# on a server: compare with DNS
dig +short user.abhignadevops.store
```
`nslookup <private-ip>` only gives `ip-172-31-x-x.ec2.internal`, not the RoboShop name.

### Service name vs app name

**Definition:** the *service* (daemon) is the background process `systemctl` manages; the *client* is the command I use to talk to it. Their names often differ.

| App | Service (`systemctl`) | Client |
|---|---|---|
| MySQL | `mysqld` | `mysql` |
| MongoDB | `mongod` | `mongosh` |
| Redis | `redis` | `redis-cli` |
| RabbitMQ | `rabbitmq-server` | `rabbitmqctl` |

`systemctl status mysql` → `Unit mysql.service could not be found` (MySQL was fine, the name was wrong). Find the real name: `systemctl list-units --type=service | grep -i <app>`.

## Stop vs terminate

| | Stop | Terminate |
|---|---|---|
| Server + installed software | kept | **deleted** |
| Paying for | only the disk (EBS) | nothing |
| Private IP | **same** → DNS records still right | gone |
| Public IP | **changes** on start → new SSH IP | gone |

```bash
aws ec2 stop-instances --instance-ids <id> ...
aws ec2 start-instances --instance-ids <id> ...
```

## Images in a repo and README

**Definition:** an image in GitHub is just a file in the repo; the README shows it with a Markdown link relative to the README.

```bash
# from the repo root: copy + rename in one step
cp ~/Pictures/Screenshots/<file>.png images/03-mysql-running.png
git add images/
git commit -m "Add MySQL screenshot"
git push
```

```markdown
![MySQL running](images/03-mysql-running.png)
```

| Rule | Why |
|---|---|
| Git tracks **files**, not folders | empty `images/` never shows in `git status` (use `.gitkeep` to keep one) |
| Path is relative to the **README** | wrong path → broken image icon |
| Names: no spaces, lowercase, start with the script number | `03-mysql-error-refused.png`; GitHub is case-sensitive |
| Remove a pushed file: `git rm <file>` + commit + push | still in history; fine for a trial file |

## Common problems and how to solve them

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | `bash: roboshop.sh: No such file or directory` in v2 | file only in v1; bash looks in the current folder | copy it to v2 (or `cd` to v1), push it |
| 2 | Ran `bash roboshop.sh 01-mongodb.sh` | script name instead of component name | `bash roboshop.sh mongodb` |
| 3 | `git log`: no commits after `git commit` | no `-m`; editor closed without saving → commit cancelled | `git commit -m "..."` |
| 4 | `mongo.repo` not in v2 | copied only the scripts | copy every file the script uses; `git status` before push |
| 5 | Moved both repos into `~/repos`, then wanted them back | trying the trainer's layout | `mv ~/repos/* ~/`; Git doesn't care where the folder is (`.git` moves with it) |
| 6 | `cp: cannot stat 'rabbitmq.repo'` → `adding rabbitmq repo..FAILED` | `rabbitmq.repo` never pushed to v2 | add it on the laptop, push, `git pull` on the server, run again ([details](troubleshooting/README.md#1-cannot-stat-rabbitmqrepo-validate-stopped-the-script)) |
| 7 | `Unit mysql.service could not be found` | service is `mysqld`, not `mysql` | `systemctl status mysqld` |
| 8 | New `images/` folder not in `git status` | Git ignores empty folders | add a file (or `.gitkeep`) |
| 9 | Trial image already pushed | - | `git rm images/<file>` + commit + push |

## Troubleshooting

Step-by-step write-ups of the errors above, including how my `validate` function stopped the script at the first failure → [troubleshooting/](troubleshooting/README.md)

## What I learned

- **v2 = DRY:** shared code once in `common.sh`, each script keeps only its own steps; one fix in one file.
- **`source`** loads a file's variables and functions into the current script; `./` = the folder I'm in, so `$scripts_dir` is safer.
- Every file a script uses (`.repo`, `.service`, `common.sh`) **must be in the repo the server clones**.
- `roboshop.sh <component>` on the **laptop** creates the server; `bash 0X-<name>.sh` **on the server** installs it.
- **First push:** `git push -u origin main`; after that `git push`. Servers only `clone` / `pull`.
- **Target checks:** `systemctl status` + `ss -lntp` (`0.0.0.0` = open to the network). `ss -tnp` shows who is connected; names come from AWS tags or DNS.
- **Two layers:** the server listening (`ss`) **and** the security group allowing the caller.
- **Stop** keeps everything (private IP too); public IP changes on start.
- **`validate` + `exit 1`** stops the script at the **first** failure, so the real cause is the only error on screen (`cannot stat rabbitmq.repo`), not 4 follow-on errors.
- **Fix at the source:** missing file → add on the laptop, push, `git pull` on the server. Found and fixed in ~2 minutes.
- **Idempotent:** `rabbitmqctl list_users | grep -qw roboshop` before `add_user`, so a rerun prints SKIPPING instead of failing.
- **Service ≠ client:** `mysqld` is the service, `mysql` the client. `systemctl list-units | grep <app>` finds the real name.
- **Git tracks files, not folders**; images go in `images/` and show in a README with `![alt](images/file.png)`.

---

## Interview Questions

15 questions with short answers → [interview-questions/](interview-questions/README.md)
