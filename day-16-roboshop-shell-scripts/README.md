# Day 16 - RoboShop with Shell Scripts

> **In short:** Same RoboShop project, now **automated with shell scripts** instead of typing every command by hand. `roboshop.sh` runs on my **laptop** and creates the EC2 servers + Route 53 records through the AWS CLI. Each component script (`01-mongodb.sh`…) runs **on its own server** and installs that service. GitHub carries the scripts from my laptop to the servers.

## Table of Contents

1. [Big picture: what runs where](#big-picture-what-runs-where)
2. [Files in this folder](#files-in-this-folder)
3. [Security groups: one common SG + one SG per component](#security-groups-one-common-sg--one-sg-per-component)
4. [roboshop.sh: create servers + DNS](#roboshsh-create-servers--dns)
5. [01-mongodb.sh: install MongoDB on the server](#01-mongodbsh-install-mongodb-on-the-server)
6. [How I ran it (step by step)](#how-i-ran-it-step-by-step)
7. [Result](#result)
8. [sed quick recap](#sed-quick-recap)
9. [Shell scripts vs real-time tools](#shell-scripts-vs-real-time-tools)
10. [Key takeaways](#key-takeaways)
11. [Interview Questions](#interview-questions)

**More in this folder:** [Problems I hit and fixes](troubleshooting.md) · [Interview questions](interview-questions/README.md)

---

## Big picture: what runs where

```
 MY UBUNTU LAPTOP                              AWS
 ┌───────────────────────────┐          ┌──────────────────────────────┐
 │ day-16-roboshop-shell-    │          │ roboshop-mongodb (RHEL 9)    │
 │ scripts/                  │          │                              │
 │  ├ roboshop.sh ──① runs here──────────▶ creates this VM + DNS      │
 │  ├ 01-mongodb.sh          │          │ /root/devops-notes (clone)   │
 │  └ mongo.repo             │          │  └ 01-mongodb.sh ──④ runs here│
 └────────────┬──────────────┘          └──────────────▲───────────────┘
              │ ② git push                             │ ③ ssh + git clone
              ▼                                        │
        ┌──────────────────────────────────────────────┐
        │ GitHub: Abhignadumpala/devops-notes (public) │
        └──────────────────────────────────────────────┘
```

| Step | Where | What | Why |
|------|-------|------|-----|
| ① | Laptop | `bash roboshop.sh mongodb` | Calls the **AWS API**: creates the VM and DNS record. Installs nothing inside the VM |
| ② | Laptop → GitHub | `git push` | The new VM is empty; GitHub delivers the scripts |
| ③ | MongoDB VM | `ssh` → `sudo su -` → `git clone` | Same files now exist **inside** the server |
| ④ | MongoDB VM | `bash 01-mongodb.sh` | `dnf`, `systemctl`, `sed` act on **the machine they run on** |

> `01-mongodb.sh` can't run on the laptop: it would try to install MongoDB on the laptop (and Ubuntu has no `dnf`).

## Files in this folder

| File | Runs on | Does |
|------|---------|------|
| [roboshop.sh](roboshop.sh) | Laptop (needs AWS CLI) | Creates EC2 instances + updates Route 53 |
| [01-mongodb.sh](01-mongodb.sh) | MongoDB server (as root) | Installs and configures MongoDB 7.0 |
| [mongo.repo](mongo.repo) | Copied by `01-mongodb.sh` | Tells `dnf` where to download MongoDB 7.0 |

## Security groups: one common SG + one SG per component

Every instance gets **two** SGs:

```
roboshop-mongodb  →  roboshop-mongodb + roboshop-common
roboshop-redis    →  roboshop-redis   + roboshop-common
```

| SG | Inbound rules |
|----|---------------|
| **roboshop-common** | Only **SSH 22 from My IP**. Attached to every instance |
| roboshop-frontend | 80 from anywhere |
| roboshop-mongodb | 27017 from catalogue, user |
| roboshop-redis | 6379 from user, cart |
| roboshop-mysql | 3306 from shipping |
| roboshop-rabbitmq | 5672 from payment, dispatch · 15672 from My IP |
| roboshop-catalogue | 8080 from frontend, cart |
| roboshop-user | 8080 from frontend, payment |
| roboshop-cart | 8080 from frontend, shipping, payment |
| roboshop-shipping / payment | 8080 from frontend |
| roboshop-dispatch | none (only connects out to RabbitMQ) |

> **Why a common SG:** SSH is in **one** place. If my home IP changes, I update **one** rule, not 11 SGs.

## roboshop.sh: create servers + DNS

```bash
bash roboshop.sh mongodb redis mysql      # one server per name
```

**Inputs at the top:**

| Variable | Value |
|----------|-------|
| `ami_id` | `ami-0055977a6e828a4f4` (Redhat-9-DevOps-Practice) |
| `instance_type` | `t3.micro` |
| `hosted_zone_id` | Route 53 zone of my domain |
| `domain_name` | `abhignadevops.store` |
| Key pair | None (password login for `ec2-user`) |

**What it does for each name:**

| Step | Command | Note |
|------|---------|------|
| 1. Create | `aws ec2 run-instances ... --security-groups "roboshop-common" "roboshop-$instance"` | SG **names** work in the default VPC |
| 2. Wait | `aws ec2 wait instance-running` | Public IP may be empty right after launch |
| 3. Get IP | `if [ $instance != "frontend" ]` → private IP, `else` → public IP | |
| 4. DNS | `aws route53 change-resource-record-sets` with `UPSERT` | Creates the record, or overwrites the old IP |

| Server | IP used | Route 53 record |
|--------|---------|-----------------|
| mongodb, redis, cart… | **Private** IP | `mongodb.abhignadevops.store` |
| frontend | **Public** IP | `abhignadevops.store` |

> **UPSERT** = **UP**date if it exists, in**SERT** if it doesn't.

**Quotes in the Route 53 JSON:** variables don't work inside single quotes. Close the quote around each variable:
```bash
'"Name": "'$r53_record_name'",'
```
→ `"Name": "mongodb.abhignadevops.store",`

## 01-mongodb.sh: install MongoDB on the server

**Common part** (same in every component script):

| Code | Meaning |
|------|---------|
| `user_id=$(id -u)` | root = `0` |
| `if [ $user_id -ne 0 ]; then ... exit 1` | Stop unless run as root (`dnf` and `systemctl` need root) |
| `logs_file="${logs_folder}/${0}.log"` | `$0` = script name → `/var/log/roboshop/01-mongodb.sh.log` |
| `mkdir -p $logs_folder` | Create the log folder; no error if it exists |
| `$(date +"%F %T")` | Date and time, e.g. `2026-10-22 00:15:30` |
| `&>> $logs_file` | Output **and** errors appended to the log |
| `R`, `G`, `Y`, `N` | Colors: red, green, yellow, normal |

**validate function** = checks each step:

```bash
validate(){
    if [ $1 -ne 0 ]; then
        echo -e "${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

dnf install mongodb-org -y &>> $logs_file
validate $? "Install MongoDB"
```

| Piece | Meaning |
|-------|---------|
| `$?` → `$1` | Exit code of the last command (`0` = success) |
| `"Install MongoDB"` → `$2` | Message to print |
| `echo -e` | Makes the color codes work |
| `tee -a` | Show on screen **and** append to the log |
| `exit 1` | Stop at the first failure |

**MongoDB steps:**

| Step | Command | Why |
|------|---------|-----|
| 1 | `cp mongo.repo /etc/yum.repos.d/mongo.repo` | Repo for MongoDB 7.0 (8.0 crashes on this AMI). Run from inside the folder |
| 2 | `dnf install mongodb-org -y` | Install |
| 3 | `systemctl enable mongod` + `start` | Start on boot + start now |
| 4 | `sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf` | Listen on all addresses so catalogue and user can connect |
| 5 | `systemctl restart mongod` | Config is read only at start |

```
Am I root? ─no─▶ "run with sudo" → exit 1
   │yes
   ▼
log folder → start time
repo → install → enable+start → sed → restart
   each step: validate → ✅ SUCCESS / ❌ FAILED + stop
```

## How I ran it (step by step)

**On the laptop:**
```bash
cd ~/devops-notes/day-16-roboshop-shell-scripts
bash roboshop.sh mongodb
git push
```

**On the MongoDB server:**
```bash
ssh ec2-user@<public-ip>
sudo su -
dnf install git -y
git clone https://github.com/Abhignadumpala/devops-notes.git
cd devops-notes/day-16-roboshop-shell-scripts
bash 01-mongodb.sh
```

> Changed a script later? Push from the laptop, then `git pull` on the server.

## Result

**roboshop.sh mongodb**
```
Creating instance: mongodb
mongodb ID: i-0b336bf4b51e709ea
mongodb IP: 172.31.0.236
DNS updated: mongodb.abhignadevops.store -> 172.31.0.236
```

**01-mongodb.sh**
```
Adding mongo repo..SUCCESS
Install MongoDB..SUCCESS
Enable and start MongoDB..SUCCESS
Updating remote connections to MongoDB..SUCCESS
Restarting MongoDB..SUCCESS
```

| Check | Result |
|-------|--------|
| Instance | `t3.micro`, RHEL 9 practice AMI, SGs `roboshop-mongodb` + `roboshop-common` |
| Route 53 | `mongodb.abhignadevops.store` → `172.31.0.236`, change status `INSYNC` |
| MongoDB | Installed, enabled, listening on `0.0.0.0:27017` |

**Stop vs start:** after a stop/start, the **private IP stays the same** (DNS still works) but the **public IP changes**.

## sed quick recap

**sed = Stream EDitor**: edits text line by line without opening the file.

| Option | Meaning |
|--------|---------|
| `sed -e '...' file` | Print the result only; file not changed |
| `sed -i '...' file` | **In-place**: save the change into the file |
| `s/old/new/g` | Substitute; `g` = all matches on the line |
| `sed -i '1a text' file` | Append a line **after** line 1 |
| `sed -i '1i text' file` | Insert a line **before** line 1 |
| `sed -i '1c text' file` | Change line 1 |
| `sed -i '/^mail/c text' file` | Change the line that **starts with** `mail` |

## Shell scripts vs real-time tools

| Task | Today (shell) | Real-time tool |
|------|---------------|----------------|
| Create servers, SGs, DNS | `roboshop.sh` | **Terraform** |
| Install and configure software | `01-mongodb.sh` | **Ansible** |
| Package the app | Install on each server | **Docker** |
| Run many services | 11 EC2 servers | **Kubernetes** |
| Databases | Install MongoDB / MySQL / Redis | **RDS, DocumentDB, ElastiCache** |

> Shell is still used daily for small automation, CI/CD steps, EC2 user data and troubleshooting. Those tools automate these same steps.

## Key takeaways

- **Laptop** creates servers (AWS API); **each server** installs its own software.
- **GitHub** moves scripts from the laptop to the servers.
- **roboshop-common** holds SSH for all servers; component SGs hold only app ports.
- **frontend → public IP + root domain**, everything else → **private IP + `<name>.domain`**.
- **validate + `$?`** = stop at the first failed step with a clear SUCCESS / FAILED message.
- **Logs** go to `/var/log/roboshop/<script>.log`.

## Interview Questions

Practice questions with short answers → [interview-questions/](interview-questions/README.md)
