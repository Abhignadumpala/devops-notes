# 06-user.sh: User Server

[← Day 16 notes](README.md) · [Common part of every script](00-common-part.md)

## What this server does

**User** is a Node.js app for **sign-up and login**. It stores users in **MongoDB** and login sessions in **Redis**.

| Fact | Value |
|------|-------|
| Server | `roboshop-user` (RHEL 9, t3.micro) |
| Software | Node.js 24 + the user app |
| Port | 8080 |
| Called by | frontend, payment |
| Calls | redis (`REDIS_URL`), mongodb (`MONGO_URL`) |
| SG inbound | 8080 from `roboshop-frontend`, `roboshop-payment` |
| Must allow user | redis 6379 ✅, mongodb 27017 ✅ |
| Config file I add | `/etc/systemd/system/user.service` |
| Files used | `06-user.sh`, `user.service` |
| Run time | **109 s** (Node.js install alone: 104 s) |

---

## Steps the script does

1. Save the script's folder (`scripts_dir`), check I'm root
2. Install Node.js 24
3. Create the `roboshop` system user (skip if it exists)
4. Fresh `/app`, download and unzip the code
5. `npm install` the libraries
6. Copy `user.service`, put in my domain
7. Start, then **restart** user

Same as catalogue, **without** the MongoDB client and the data load (user doesn't need any starting data).

---

## The code, block by block

### 1. The common part

```bash
user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
domain_name="abhignadevops.store"
scripts_dir=$(dirname "$(realpath "$0")")
...
if [ $user_id -ne 0 ]; then ... exit 1; fi
mkdir -p $logs_folder
timestamp(){ ... }
validate(){ ... }
```

**What it does:** settings, root check, log folder, `timestamp` + `validate`. Same as every script: [00-common-part.md](00-common-part.md).

`scripts_dir` = the folder this script lives in, as a full path:

```
$0              06-user.sh                                (what I typed)
realpath "$0"   /root/shellscript-roboshop-v1/06-user.sh  (full path)
dirname ...     /root/shellscript-roboshop-v1             → scripts_dir
```

**Why:** block 4 does `cd /app`. After that, a plain `user.service` would be searched in `/app`. It isn't checking anything, it **remembers** where my repo files are. It must be set **before** `cd /app`.

### 2. Install Node.js 24

```bash
dnf module disable nodejs -y &>> $logs_file
dnf module enable nodejs:24 -y &>> $logs_file
dnf install nodejs -y &>> $logs_file
validate $? "Installing and enabling nodejs 24"
```

**What it does:** turns off RHEL's default Node.js version, picks 24, installs it.
**Why:** user is a Node.js app. This is the slowest step (104 of 109 s on my run).

### 3. Create the app user (only if missing)

```bash
id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
     useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
     validate $? "Creating system user"
else
    echo -e "$(timestamp) [INFO] System user roboshop already exist...${Y}SKIPPING${N}"
fi
```

**What it does:** `id roboshop` fails if the user doesn't exist → create it. Exists → SKIPPING.
**Why:** the app runs as a normal user, not root. The check makes a 2nd run safe (**idempotent**).

> `roboshop` here is the **Linux user** that runs the app. It has nothing to do with the **user service** (the app). Don't rename it when copying this script for cart.

### 4. Fresh app folder + download + unzip

```bash
rm -rf /app
validate $? "Removing old code"

mkdir -p /app
validate $? "Creating app directory"

curl -L -o /tmp/user.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/user-v4.zip &>> $logs_file
validate $? "Downloading user"

cd /app
unzip /tmp/user.zip &>> $logs_file
validate $? "Unzipping user"
```

**What it does:** deletes the old `/app`, creates it again, downloads the code and unzips it into `/app`.
**Why `rm -rf /app`:** on a re-run, `unzip` would ask "replace?" and wait forever (the question is hidden in the log).

### 5. Install the app's libraries

```bash
npm install &>> $logs_file
validate $? "Installing dependencies"
```

**What it does:** reads `package.json` in `/app` and downloads the libraries into `node_modules/` (here: the MongoDB and Redis drivers).

### 6. Install the service file with my domain

```bash
cp $scripts_dir/user.service /etc/systemd/system/user.service
validate $? "Copying user service"

sed -i "s/DOMAIN_NAME/$domain_name/g" /etc/systemd/system/user.service
validate $? "Updating domain name in user service"
```

**What it does:**
1. Copies `user.service` from my repo folder to systemd's folder.
2. In that **copy**, replaces **every** `DOMAIN_NAME` with `abhignadevops.store`.

```
before:  REDIS_URL="redis://redis.DOMAIN_NAME:6379"
         MONGO_URL="mongodb://mongodb.DOMAIN_NAME:27017/users"
after:   REDIS_URL="redis://redis.abhignadevops.store:6379"
         MONGO_URL="mongodb://mongodb.abhignadevops.store:27017/users"
```

**Why `/g`:** this file has **2** `DOMAIN_NAME`s. `sed` without `/g` changes only the first match **on each line**. They're on different lines here, so it would still work, but `/g` is the safe habit.

**Why copy first, then `sed`:**

| Order | Repo file after the run | Rerun | `git pull` on the server later |
|-------|-------------------------|-------|-------------------------------|
| `sed` repo file → `cp` | changed (`DOMAIN_NAME` gone) | ✅ works | ❌ *"Your local changes would be overwritten"* |
| `cp` → `sed` the copy (mine) | untouched | ✅ works | ✅ works |

Both run fine many times. Copy-first also keeps `git pull` working when I fix a script and pull it onto the same server.

### 7. Start, then restart

```bash
systemctl daemon-reload &>> $logs_file
systemctl enable user &>> $logs_file
systemctl start user &>> $logs_file
validate $? "Starting and enabling user"

systemctl restart user
validate $? "Restarting user"
```

| Command | Meaning |
|---------|---------|
| `daemon-reload` | systemd reads the new `user.service` |
| `enable` | start on every boot |
| `start` | start it now (does nothing if it's already running) |
| `restart` | stop + start: always loads the latest code and service file, also on a re-run |

### 8. Finish

```bash
echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file
```

**What it does:** prints how long the script took (`$SECONDS` = built-in bash counter).

---

## user.service, line by line

```ini
[Unit]
Description=User Service
After=network-online.target

[Service]
User=roboshop
Environment=REDIS_URL="redis://redis.DOMAIN_NAME:6379"
Environment=MONGO_URL="mongodb://mongodb.DOMAIN_NAME:27017/users"
ExecStart=/bin/node /app/server.js
SyslogIdentifier=user
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

| Line | Meaning |
|------|---------|
| `User=roboshop` | run as the app user, not root |
| `REDIS_URL="redis://redis.DOMAIN_NAME:6379"` | **outgoing**: where Redis is (sessions) |
| `MONGO_URL="mongodb://mongodb.DOMAIN_NAME:27017/users"` | **outgoing**: where MongoDB is + the `users` database |
| `ExecStart=/bin/node /app/server.js` | start the app |
| `SyslogIdentifier=user` | name shown in `journalctl` |
| `Restart=on-failure` + `RestartSec=5` | crashed? systemd restarts it after 5 s |

**DNS names, not IPs:** the original doc says `<REDIS-SERVER-IPADDRESS>`. I use `redis.DOMAIN_NAME`, so a re-created Redis server only needs its Route 53 record updated (`roboshop.sh` does that).

<details>
<summary><b>Full script in one piece</b> (click to open)</summary>

```bash
#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
domain_name="abhignadevops.store"
scripts_dir=$(dirname "$(realpath "$0")")
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

timestamp(){
    date +"%F %T"
}

validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}
echo "$(timestamp) [INFO] ==== Script started execution ======" | tee -a $logs_file

dnf module disable nodejs -y &>> $logs_file
dnf module enable nodejs:24 -y &>> $logs_file
dnf install nodejs -y &>> $logs_file
validate $? "Installing and enabling nodejs 24"

id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
     useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
     validate $? "Creating system user"
else
    echo -e "$(timestamp) [INFO] System user roboshop already exist...${Y}SKIPPING${N}"
fi

rm -rf /app
validate $? "Removing old code"

mkdir -p /app
validate $? "Creating app directory"

curl -L -o /tmp/user.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/user-v4.zip &>> $logs_file
validate $? "Downloading user"

cd /app
unzip /tmp/user.zip &>> $logs_file
validate $? "Unzipping user"

npm install &>> $logs_file
validate $? "Installing dependencies"

cp $scripts_dir/user.service /etc/systemd/system/user.service
validate $? "Copying user service"

sed -i "s/DOMAIN_NAME/$domain_name/g" /etc/systemd/system/user.service
validate $? "Updating domain name in user service"

systemctl daemon-reload &>> $logs_file
systemctl enable user &>> $logs_file
systemctl start user &>> $logs_file
validate $? "Starting and enabling user"

systemctl restart user
validate $? "Restarting user"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file
```

</details>

---

## How I ran it

```bash
# laptop
bash roboshop.sh user          # EC2 roboshop-user + user.abhignadevops.store → 172.31.6.164 (TTL 1)

# user server
ssh ec2-user@<user-public-ip>
sudo -i
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v1.git
cd shellscript-roboshop-v1
bash 06-user.sh
```

## Run + result

```
2026-10-26 00:09:25 [INFO] ==== Script started execution ======
2026-10-26 00:11:09 [INFO] Installing and enabling nodejs 24..SUCCESS
2026-10-26 00:11:09 [INFO] Creating system user..SUCCESS
2026-10-26 00:11:09 [INFO] Removing old code..SUCCESS
2026-10-26 00:11:09 [INFO] Creating app directory..SUCCESS
2026-10-26 00:11:09 [INFO] Downloading user..SUCCESS
2026-10-26 00:11:09 [INFO] Unzipping user..SUCCESS
2026-10-26 00:11:13 [INFO] Installing dependencies..SUCCESS
2026-10-26 00:11:13 [INFO] Copying user service..SUCCESS
2026-10-26 00:11:13 [INFO] Updating domain name in user service..SUCCESS
2026-10-26 00:11:14 [INFO] Starting and enabling user..SUCCESS
2026-10-26 00:11:14 [INFO] Restarting user..SUCCESS
2026-10-26 00:11:14 [INFO] Script completed in 109 seconds
```

```
$ curl localhost:8080/health
{"app":"OK","mongo":true,"redis":true}
```

**Reading the journal** (`journalctl -u user`):

| Log line | Meaning |
|----------|---------|
| `Started User Service` → `/bin/node /app/server.js` | the first `systemctl start` |
| `Stopping…` → `Stopped` → `Started` | the `systemctl restart` at the end |
| `uid:991` | the app runs as `roboshop`, not root (`User=roboshop`) |
| `user started on port 8080` | listening |
| `Redis connected` | DNS ✅ SG ✅ redis `bind 0.0.0.0` ✅ |
| `MongoDB connected` | DNS ✅ SG ✅ mongod `bindIp 0.0.0.0` ✅ |

## Verify

```bash
systemctl status user                         # active (running)
grep URL /etc/systemd/system/user.service     # abhignadevops.store, no DOMAIN_NAME left
curl localhost:8080/health                    # {"app":"OK","mongo":true,"redis":true}
journalctl -u user -n 20                      # Redis connected, MongoDB connected
```

---

## Problems I hit

| Problem | Cause | Fix |
|---------|-------|-----|
| `cp`/`sed` would fail with "No such file" | Variable set as `script_dir`, used as `scripts_dir` (one extra **s**): bash treats it as a new, **empty** variable → path `/user.service` | Same name everywhere. `bash -n` can't catch it, it's not a syntax error |
| Repo file changed on the server | `sed` ran on `$scripts_dir/user.service` **before** `cp` | Copy first, `sed` the copy in `/etc/systemd/system/` |
| No error until "Starting user" | No `validate` after `cp` and `sed` | `validate $?` after both |
| `user.service` pushed **empty** | File created in VS Code but not saved | `cat user.service` before `git add` |
| `ssh` → `Permission denied` | Wrong password typed (it's case-sensitive, nothing shows while typing) | Same AMI login as the other servers |

---

## Interview questions

**1. What does `scripts_dir=$(dirname "$(realpath "$0")")` do?**
It saves the full path of the folder the script is in, before `cd /app`, so the script still finds `user.service`.

**2. Why `sed` the copy and not the repo file?**
The repo file keeps `DOMAIN_NAME`, so git stays clean and `git pull` on the server keeps working.

**3. Health says `redis: false`. Where do you look?**
`journalctl -u user`, then from the user server `telnet redis.<domain> 6379`: timeout = SG, refused = Redis not listening on `0.0.0.0`, "not known" = DNS.

**4. Why `start` and then `restart`?**
`start` does nothing if the service is already running. `restart` makes a re-run load the new code and service file.

**5. A typo in a variable name: why doesn't bash give an error?**
An unset variable is just empty. Use `set -u` to make bash stop on unset variables.
