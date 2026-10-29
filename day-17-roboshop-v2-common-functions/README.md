# Day 17 - RoboShop v2: Shared Code in common.sh

> **In short:** RoboShop v2 is the same 10-server shop as v1, but the code every script repeats (root check, logs, `validate`, colors) lives **once** in `common.sh`. Each script loads it with `source` and keeps only its own steps. `roboshop.sh` runs on my **laptop** to create servers; each `0X-<name>.sh` runs **on its own server** to install that component.

> **Project repo:** [shellscript-roboshop-v2](https://github.com/Abhignadumpala/shellscript-roboshop-v2) · v1: [shellscript-roboshop-v1](https://github.com/Abhignadumpala/shellscript-roboshop-v1) · v1 notes: [Day 16](../day-16-roboshop-shell-scripts/README.md)

**More in this folder**

| Folder | What's inside |
|---|---|
| [hands-on/](hands-on/README.md) | My full run, mysql → frontend → end-to-end order, with screenshots |
| [troubleshooting/](troubleshooting/README.md) | Every error I hit and how I fixed it |
| [interview-questions/](interview-questions/README.md) | Short answers for interview prep |

## Table of Contents

1. [Why v2: common.sh](#step-1-why-v2-commonsh)
2. [How source works](#step-2-how-source-works)
3. [Set up the v2 repo](#step-3-set-up-the-v2-repo)
4. [Push it to GitHub](#step-4-push-it-to-github)
5. [Create the servers (laptop)](#step-5-create-the-servers-laptop)
6. [Install each component (on each server)](#step-6-install-each-component-on-each-server)
7. [Check a database server](#step-7-check-a-database-server)
8. [See who is connected](#step-8-see-who-is-connected)
9. [Test the whole shop](#step-9-test-the-whole-shop)
10. [Stop or terminate](#step-10-stop-or-terminate)
11. [Result](#result)
12. [Problems I hit](#problems-i-hit)
13. [What I learned](#what-i-learned)
14. [Interview Questions](#interview-questions)

---

## Step 1: Why v2: common.sh

**Definition:** *DRY* (Don't Repeat Yourself) = write shared code once and reuse it.

| | v1 | v2 |
|---|---|---|
| Root check, `timestamp`, `validate`, colors, log folder | copied into **every** script | **once** in `common.sh` |
| A fix in shared code | edit up to 10 files | edit **1** file |
| Each script holds | everything | only what's **special** about that component |

**`common.sh`:**
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

**`01-mongodb.sh`** (only the MongoDB part is left):
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

**`02-redis.sh`** (short, only Redis steps):
```bash
#!/bin/bash

source ./common.sh
check_root

dnf module disable redis -y &>> $logs_file
dnf module enable redis:7 -y &>> $logs_file
dnf install redis -y &>> $logs_file
validate $? "installing redis"

# allow other servers to connect (127.0.0.1 → 0.0.0.0)
sed -i -e 's/^bind 127.0.0.1/bind 0.0.0.0/' -e 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf &>> $logs_file
validate $? "Allowing remote connections to redis"

systemctl enable redis &>> $logs_file
systemctl start redis &>> $logs_file
validate $? "enable and start redis"

total_time
```

**`03-mysql.sh`** (short, only MySQL steps):
```bash
#!/bin/bash

source ./common.sh
check_root

dnf module enable mysql:8.4 -y &>> $logs_file
dnf install mysql-server -y &>> $logs_file
validate $? "installing mysql"

systemctl enable mysqld &>> $logs_file
systemctl start mysqld &>> $logs_file
validate $? "start and enable mysql"

mysql_secure_installation --set-root-pass <mysql-root-password> &>> $logs_file
validate $? "setup MySQL root user and password"

total_time
```

## Step 2: How source works

**Definition:** `source file` (or `. file`) runs the file **inside the current script**, so its variables and functions can be used there.

| Command | Runs in | Variables/functions come back? |
|---|---|---|
| `source common.sh` | the same script | ✅ yes |
| `bash common.sh` | a new, separate process | ❌ no |

`./common.sh` means "in the folder I'm in **now**", so always `cd` into the repo before running a script. To make it work from any folder:
```bash
scripts_dir=$(dirname "$(realpath "$0")")
source "$scripts_dir/common.sh"
```

## Step 3: Set up the v2 repo

1. Create the empty repo `shellscript-roboshop-v2` on GitHub and clone it to the laptop.
2. Open v1 and v2 together in VS Code:
   ```bash
   code ~/shellscript-roboshop-v1
   code -a ~/shellscript-roboshop-v2      # -a = add to this window
   ```
3. Copy files from v1 to v2: click the file → **Ctrl+C** → click the v2 folder → **Ctrl+V**.
   (Drag **with Ctrl** = copy, drag without Ctrl = move.)
4. Write `common.sh`, then shorten each script to only its own steps.

**The server only gets what's in the repo**, so every file a script uses must be in v2:

| Script | Needs in v2 |
|---|---|
| all | `common.sh` |
| `01-mongodb.sh` | `mongo.repo` |
| `02-redis.sh` | `common.sh` only (Redis comes from the RHEL repo, no extra file) |
| `03-mysql.sh` | `common.sh` only (MySQL comes from the RHEL repo, no extra file) |
| `04-rabbitmq.sh` | `rabbitmq.repo` |
| `05-catalogue.sh` | `catalogue.service`, `mongo.repo` |
| `06-user.sh` / `07-cart.sh` / `08-shipping.sh` / `09-payment.sh` | `user` / `cart` / `shipping` / `payment.service` |
| `10-frontend.sh` | `roboshop.conf` |
| laptop | `roboshop.sh` |

## Step 4: Push it to GitHub

```bash
git status                     # check every file is listed before pushing
git add .
git commit -m "Add common.sh and v2 scripts"
git push -u origin main        # first push only (-u links main → origin/main)
git push                       # every push after that
```

```
   ① Step 4 (laptop)                ② Step 6 (on each server)
laptop ──git push──► GitHub ──git clone / git pull──► server
(write + fix code)                    (only reads code)
```

1. **First** push the code from the laptop to GitHub (this step).
2. **Then** clone the repo on each server and run the script → [Step 6](#step-6-install-each-component-on-each-server).

- Servers never push: the repo is public, so they need no login or keys.
- After a fix: laptop `git push` → server `git pull` → run the script again.

## Step 5: Create the servers (laptop)

In the laptop terminal, inside the repo, run `roboshop.sh` with the **component name**:

```bash
bash roboshop.sh mongodb      # creates server roboshop-mongodb + DNS record
bash roboshop.sh redis
bash roboshop.sh mysql
bash roboshop.sh rabbitmq
bash roboshop.sh catalogue
bash roboshop.sh user
bash roboshop.sh cart
bash roboshop.sh shipping
bash roboshop.sh payment
bash roboshop.sh frontend     # gets the public IP → abhignadevops.store
```

After `mongodb ID: i-...` it waits 15–60 s for the server to start. That's normal.

The 12 security groups from v1 are reused, so v2 needs **no new SGs**.

## Step 6: Install each component (on each server)

Practice AMI `Redhat-9-DevOps-Practice`: user `ec2-user`, password from [Day 7](../day-07-3tier-nodejs-expense-app/03-frontend.md).

Do this on **each server**: connect → clone the repo → run **that server's** script.
```bash
ssh ec2-user@<public-ip>      # yes (first time) → password (nothing shows while typing)
sudo su -
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v2.git
cd shellscript-roboshop-v2
bash 01-mongodb.sh            # script for this server (table below)
```

Go in this order: databases first, then the apps that use them, frontend last.

| Server | Script |
|---|---|
| roboshop-mongodb | `bash 01-mongodb.sh` |
| roboshop-redis | `bash 02-redis.sh` |
| roboshop-mysql | `bash 03-mysql.sh` |
| roboshop-rabbitmq | `bash 04-rabbitmq.sh` |
| roboshop-catalogue | `bash 05-catalogue.sh` |
| roboshop-user | `bash 06-user.sh` |
| roboshop-cart | `bash 07-cart.sh` |
| roboshop-shipping | `bash 08-shipping.sh` |
| roboshop-payment | `bash 09-payment.sh` |
| roboshop-frontend | `bash 10-frontend.sh` |

Every step prints **SUCCESS** or **FAILED**. On FAILED the script stops; the full error is in `/var/log/roboshop/<script>.log`.

## Step 7: Check a database server

MongoDB, Redis, MySQL and RabbitMQ are **targets**: other servers connect to them. After the script, check 3 things on the server:

| Check | MongoDB | Redis | MySQL | RabbitMQ |
|---|---|---|---|---|
| 1. Running? | `systemctl status mongod` | `systemctl status redis` | `systemctl status mysqld` | `systemctl status rabbitmq-server` |
| 2. Open to the network? | `ss -lntp \| grep 27017` | `ss -lntp \| grep 6379` | `ss -lntp \| grep 3306` | `ss -lntp \| grep 5672` |
| 3. Answers? | `mongosh --eval 'db.runCommand({ping:1})'` | `redis-cli ping` → `PONG` | `mysql -uroot -e 'show databases;'` | `rabbitmqctl list_users` |

In check 2: `0.0.0.0:<port>` = open to other servers ✅, `127.0.0.1:<port>` = only this server ❌.

**Service name ≠ client name:** the *service* is the background process `systemctl` manages; the *client* is the command I use to talk to it.

| App | Service | Client |
|---|---|---|
| MySQL | `mysqld` | `mysql` |
| MongoDB | `mongod` | `mongosh` |
| Redis | `redis` | `redis-cli` |
| RabbitMQ | `rabbitmq-server` | `rabbitmqctl` |

**Two things must both allow a connection:**

| Layer | Question | Where |
|---|---|---|
| `ss -lntp` | is the door open? | on the server |
| Security group | who may walk to the door? | AWS |

Example: Redis listens on `0.0.0.0:6379`, and SG `roboshop-redis` allows only `roboshop-user` and `roboshop-cart` → only those two can reach it.

## Step 8: See who is connected

| Command | Shows |
|---|---|
| `ss -lntp` | **listening** ports (the open doors) |
| `ss -tnp` | used to check **live active connections** |

Example on cart after `07-cart.sh`:
```text
ESTAB  172.31.10.152:41498  172.31.8.36:6379    MainThread   ← cart app → redis (outgoing)
ESTAB  172.31.10.152:22     2.82.252.24:60066   sshd         ← me → cart (incoming)
```

**How to read the direction:** look at the **local** port (left column).

| Local port | Direction |
|---|---|
| well-known (`22`, `8080`) | **incoming**: someone connected to this server |
| random high (`41498`) | **outgoing**: this server connected out |

**Definition:** *ephemeral port* = the random high port a caller picks for one outgoing connection.

Which connections you'll see on each server:

| Server | Stays connected to |
|---|---|
| catalogue | mongodb:27017 |
| user | mongodb:27017, redis:6379 |
| cart | redis:6379 |
| shipping | mysql:3306 |
| payment | rabbitmq:5672 |

HTTP calls (frontend → cart) last only milliseconds, so they rarely show up. To catch them: `journalctl -u cart -f`.

**IP → server name** (Linux only sees IPs):
```bash
# laptop: all servers with name + IPs
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress]' --output table
```

## Step 9: Test the whole shop

1. On frontend, check each app answers through Nginx:
   ```bash
   curl localhost/api/catalogue/health
   curl localhost/api/cart/health
   ```
2. Open `http://abhignadevops.store` in the browser.
3. **Register** a new user (v2 has a new, empty database).
4. Add a product → cart → choose shipping country/city → pay.
5. Open **Order history**: the order is there ✅.

Screenshots of my run: [hands-on/ → End-to-end order](hands-on/README.md#end-to-end-order).

## Step 10: Stop or terminate

| | Stop | Terminate |
|---|---|---|
| Server + installed software | kept | **deleted** |
| Paying for | only the disk (EBS) | nothing |
| Private IP | **same** → DNS still right | gone |
| Public IP | **changes** on start → new SSH IP | gone |

```bash
aws ec2 stop-instances --instance-ids <id>
aws ec2 start-instances --instance-ids <id>
aws ec2 terminate-instances --instance-ids <id>
```

Stop = pause for tomorrow. Terminate = lab finished (SGs and the Route 53 zone stay for the next build).

## Result

| # | Script | Time | Check |
|---|---|---|---|
| 01 | `01-mongodb.sh` | 105 s | 5/5 SUCCESS |
| 02 | `02-redis.sh` | - | `0.0.0.0:6379` |
| 03 | `03-mysql.sh` | 25 s | `mysqld` on 3306 |
| 04 | `04-rabbitmq.sh` | 181 s | `roboshop` user listed |
| 05 | `05-catalogue.sh` | 58 s | products loaded |
| 06 | `06-user.sh` | 26 s | ✅ |
| 07 | `07-cart.sh` | 29 s | `*:8080`, → redis:6379 |
| 08 | `08-shipping.sh` | 33 s | health `UP` |
| 09 | `09-payment.sh` | 94 s | `{"app":"OK","rabbitmq":true}` |
| 10 | `10-frontend.sh` | 94 s | all `/api/*/health` 200 |

**End-to-end ✅ (2026-10-28):** registered → added a robot → shipping Portugal/Lamego (€79.85) → paid → order `a2a4de95` (€379.85) in order history. All 10 servers terminated afterwards. Dispatch not built in v2.

## Problems I hit

Each one is written up with the error, the cause and my fix in [troubleshooting/](troubleshooting/README.md):

| Where | Problem |
|---|---|
| Setup | [`roboshop.sh` not found in v2](troubleshooting/README.md#13-roboshopsh-no-such-file-or-directory-in-v2) · [commit without `-m` cancelled](troubleshooting/README.md#14-git-commit-without--m-commit-cancelled) · [first push: no upstream branch](troubleshooting/README.md#15-git-push-no-upstream-branch) · [trainer's common.sh brings back v1 bugs](troubleshooting/README.md#16-trainers-commonsh-brings-back-4-v1-bugs) |
| Missing files | [`rabbitmq.repo`](troubleshooting/README.md#1-cannot-stat-rabbitmqrepo-validate-stopped-the-script) · [`.service` files](troubleshooting/README.md#8-cannot-stat--catalogueservice-same-mistake-second-time) |
| MySQL | [`mysql.service` not found](troubleshooting/README.md#4-unit-mysqlservice-could-not-be-found) · [`ERROR 1129` host blocked](troubleshooting/README.md#10-mysql-error-1129-host-is-blocked) · [root@localhost access denied](troubleshooting/README.md#11-access-denied-for-rootlocalhost-on-the-mysql-server) |
| Shipping | [`mvn` TLS error `X25519MLKEM768`](troubleshooting/README.md#7-shipping-mvn-fails-x25519mlkem768-keypair-not-available) · [app never opens 8080](troubleshooting/README.md#9-shipping-app-8080-never-opens-same-tls-error-to-mysql) |
| Shop | [order confirmed, history empty](troubleshooting/README.md#12-order-confirmed-but-order-history-empty-check-404) |

## What I learned

### Class summary

- v2 = same RoboShop, but shared code lives **once** in `common.sh`.
- Each script loads it with `source` and keeps only its own steps.
- One fix in `common.sh` fixes all 10 scripts.
- Laptop: `bash roboshop.sh <component>` creates the server.
- Server: `git clone` the repo → `bash 0X-<name>.sh` installs it.
- Every file a script uses must be in the repo the server clones.
- Order: databases first, then the apps, frontend last.

### My learnings

What I noticed myself while doing the lab:

- The trainer's v2 `common.sh` brought back 4 bugs I had already fixed in v1.
- `roboshop.sh` was only in v1, so it wasn't found in the v2 folder.
- `git commit` without `-m` → I closed the editor → the commit was cancelled.
- I forgot to push files twice (`rabbitmq.repo`, the `.service` files) → now I run `git status` before every push.
- My `validate` stopped the script at the first FAILED, so the real cause was the only error on screen.
- `systemctl status mysql` → not found: the service is `mysqld`, `mysql` is only the client.
- `ss -tnp` on redis showed only my own SSH session: apps connect only after they're installed.
- `ss -tnp` on cart showed cart → redis:6379: a random high local port = outgoing connection.
- Shipping `mvn` broke on a new server with the same script: newer RHEL packages caused a Java TLS error.
- Maven's Java and the app's Java are separate, so the same TLS fix was needed in two places.
- The crashing shipping app retried so often that MySQL blocked its IP (`ERROR 1129`).
- `root@localhost` and `root@'%'` are different MySQL users (local root has no password).
- Order confirmed but history empty: I hadn't registered in v2. A `404` meant missing data, not a broken service.
- Following one `requestId` through each service's log showed exactly where the order stopped.

Details of every error → [troubleshooting/](troubleshooting/README.md)

---

## Interview Questions

21 questions with short answers → [interview-questions/](interview-questions/README.md)
