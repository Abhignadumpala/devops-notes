# Day 7 - Expense Project: Database, Backend & Frontend

A complete 3-tier app on 3 Linux servers, set up step by step.

## Table of Contents

1. [What We Are Building](#what-we-are-building)
2. [Before You Start](#before-you-start)
3. [Part 1 - Database Server (MySQL)](#part-1---database-server-mysql)
4. [Part 2 - Backend Server (Node.js)](#part-2---backend-server-nodejs)
5. [Part 3 - Frontend Server (Nginx)](#part-3---frontend-server-nginx)
6. [Test the Full App](#test-the-full-app)
7. [Troubleshooting](#troubleshooting)
8. [Concepts Learned](#concepts-learned)
9. [Summary](#summary)
10. [Interview Questions](#interview-questions)

---

## What We Are Building

**Expense app** - records daily expenses.

| id | category | amount | date | description |
|----|----------|--------|------|-------------|
| 1 | food | 100 | 29-SEP-2026 | masala dosa |

### Architecture

```text
            port 80              port 8080             port 3306
User ───────────────▶ Frontend ───────────▶ Backend ───────────▶ Database
(browser)             (Nginx)               (Node.js)            (MySQL)
                      public IP             private IP           private IP
```

| Server | Software | Port | Job |
|--------|----------|------|-----|
| Frontend | Nginx | 80 | Shows the web page, forwards `/api/` requests to backend |
| Backend | Node.js | 8080 | Business logic, reads/writes the database |
| Database | MySQL | 3306 | Stores the expenses |

See [Day 6](../day-06-3-tier-architecture-databases/README.md) for 3-tier basics.

---

## Before You Start

Create the **security groups first**, then the servers - each server needs its security group while launching.

### Overview

| Server Name | Security Group | Inbound Rules | Public Access? |
|-------------|----------------|---------------|----------------|
| `frontend` | `frontend-sg` | 22 from My IP, 80 from anywhere | Yes |
| `backend` | `backend-sg` | 22 from My IP, 8080 from `frontend-sg` | No |
| `mysql` | `mysql-sg` | 22 from My IP, 3306 from `backend-sg` | No |

> Only the frontend is open to the internet. Backend and database are hidden behind it.

### Step 1: Create Security Groups

Create them in this order: **frontend-sg → backend-sg → mysql-sg**. Each rule points to the previous group, so that group must already exist.

#### Clicks (same for every security group)

1. Log in to the AWS Console → search **EC2** → open it.
2. Top-right corner → check the region is **N. Virginia (us-east-1)**.
3. Left menu → **Network & Security** → **Security Groups**.
4. Click **Create security group**.
5. **Basic details**: fill in **Security group name**, **Description**, and leave **VPC** as the default VPC.
6. **Inbound rules** → click **Add rule** for each rule in the table below:
   - **Type**: choose from the dropdown (port fills in automatically, except Custom TCP)
   - **Source**: `My IP`, `Anywhere-IPv4`, or `Custom` → start typing `sg-` / the group name and select it
7. **Outbound rules**: leave as is (All traffic).
8. Click **Create security group**.

#### Values for Each Security Group

**1. frontend-sg**

| Field | Value |
|-------|-------|
| Name | `frontend-sg` |
| Description | `Allow HTTP from internet and SSH from my IP` |

| Type | Port | Source | Why |
|------|------|--------|-----|
| SSH | 22 | My IP | Log in from my laptop |
| HTTP | 80 | Anywhere-IPv4 (`0.0.0.0/0`) | Users open the website |

**2. backend-sg**

| Field | Value |
|-------|-------|
| Name | `backend-sg` |
| Description | `Allow 8080 from frontend and SSH from my IP` |

| Type | Port | Source | Why |
|------|------|--------|-----|
| SSH | 22 | My IP | Log in from my laptop |
| Custom TCP | 8080 | Custom → `frontend-sg` | Only frontend can call backend |

**3. mysql-sg**

| Field | Value |
|-------|-------|
| Name | `mysql-sg` |
| Description | `Allow MySQL from backend and SSH from my IP` |

| Type | Port | Source | Why |
|------|------|--------|-----|
| SSH | 22 | My IP | Log in from my laptop |
| MYSQL/Aurora | 3306 | Custom → `backend-sg` | Only backend can reach DB |

> Using a **security group as the source** (instead of an IP) keeps the rule working even if the server's IP changes.

> **Created them in the wrong order?** If a group doesn't exist yet, don't use `0.0.0.0/0` for 3306 or 8080 - that opens the DB/backend to the whole internet. Create the missing group, then fix the rule: select the security group → **Inbound rules** tab → **Edit inbound rules** → change **Source** to the right group → **Save rules**.

### Step 2: Launch 3 EC2 Instances

#### Easiest Way to Find the AMI

1. Region (top-right) = **N. Virginia (us-east-1)**.
2. EC2 → left menu → **Images → AMIs**.
3. Change the dropdown next to the search bar from **Owned by me** to **Public images**.
4. Search `ami-0220d79f3f480ecf5` → press Enter → tick **Redhat-9-DevOps-Practice**.
5. Click **Launch instance from AMI** → the launch page opens with the AMI already selected (skip step 3 below).

#### Clicks (repeat 3 times - mysql, backend, frontend)

1. EC2 → left menu → **Instances** → **Launch instances**.
2. **Name and tags** → Name: `mysql` (then `backend`, then `frontend`).
3. **Application and OS Images (AMI)**:
   - In the search box type `ami-0220d79f3f480ecf5` → press **Enter**.
   - Open the **Community AMIs** tab → click **Select** next to `Redhat-9-DevOps-Practice`.
   - Check the name shows **Redhat-9-DevOps-Practice**.
   - It shows **"No results found in Quick Start AMIs"** at first - that's normal. The AMI is under the **Community AMIs** tab. Search by the **AMI ID** (not the name) to get exactly one result, and make sure the region is **N. Virginia (us-east-1)** - the AMI exists only there.
4. **Instance type** → `t3.micro` (or `t2.micro` if that's the free-tier one in the region).
5. **Key pair (login)** → open the dropdown → pick the first option **Proceed without a key pair (Not recommended)**.
6. **Network settings** → click **Edit**:
   - VPC: default
   - Subnet: No preference
   - **Auto-assign public IP**: Enable
   - **Firewall (security groups)**: **Select existing security group** → choose `mysql-sg` (then `backend-sg`, then `frontend-sg`).
7. **Configure storage** → leave the default.
8. **Summary** (right side) → Number of instances: `1` → click **Launch instance**.
9. Click **View all instances** → wait until **Instance state = Running** and **Status check = 2/2 checks passed**.

#### Values for Each Instance

| Field | mysql | backend | frontend |
|-------|-------|---------|----------|
| Name | `mysql` | `backend` | `frontend` |
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`) | same | same |
| Instance type | `t3.micro` | `t3.micro` | `t3.micro` |
| Key pair | Proceed without a key pair | same | same |
| Auto-assign public IP | Enable | Enable | Enable |
| Security group | `mysql-sg` | `backend-sg` | `frontend-sg` |
| Storage | Default | Default | Default |

> **Pick the right AMI.** The practice AMI has password login enabled, so no key pair is needed. The official Red Hat images (names like `RHEL-10.x_HVM...-Hourly2`) have password login disabled - an instance launched from them without a key pair can't be logged into - and they add an hourly Red Hat license charge.

### Step 3: Note the IPs

Select each instance → **Details** tab:

| Server | Public IP (for SSH / browser) | Private IP (for server-to-server) |
|--------|-------------------------------|------------------------------------|
| mysql | `<mysql-public-ip>` | `<mysql-private-ip>` → used in backend service file |
| backend | `<backend-public-ip>` | `<backend-private-ip>` → used in nginx config |
| frontend | `<frontend-public-ip>` → open in browser | - |

### Step 4: Connect

No key needed - log in with the AMI's password:

```bash
ssh ec2-user@<public-ip>
# enter the password when asked
```

> **Stop the instances** after practice to save free-tier credits. Public IPs change after stop/start; private IPs don't.

### Step 5: Install in This Order

**Database → Backend → Frontend.** Each tier needs the one after it to be ready.

Run all commands as root:

```bash
sudo su -
```

---

## Part 1 - Database Server (MySQL)

SSH into the **mysql** server.

### 1. Install MySQL Server

```bash
dnf install mysql-server -y
```

### 2. Start MySQL

```bash
systemctl enable mysqld
systemctl start mysqld
systemctl status mysqld
```

### 3. Set Root Password

```bash
mysql_secure_installation --set-root-pass <db-root-password>
```

### 4. Verify

```bash
netstat -lntp        # 3306 should be listening
mysql -u root -p     # log in (asks for password)
```

```sql
SHOW DATABASES;
exit
```

✅ Database is ready. The schema is loaded later from the backend server.

---

## Part 2 - Backend Server (Node.js)

SSH into the **backend** server.

**Backend setup steps:**

1. Install the programming runtime (Node.js)
2. Create a system user
3. Create one directory for the code (`/app`)
4. Download the code
5. Install dependencies/libraries
6. Create a systemctl service file

> **Note - Before building any Node.js application, check these first:**
>
> | Check | For This App | Simple Meaning |
> |-------|--------------|----------------|
> | Node.js version | `24` | The version the app is written for. Install the same one, or the app may not run. |
> | Build tool | `npm` | The tool that downloads libraries and builds/runs the app. |
> | Build file | `package.json` | Lists the app's name, version and the libraries it needs. `npm` reads this file. |
> | Dependencies folder | `node_modules/` | Where `npm install` puts all the downloaded libraries. |
> | Lock file | `package-lock.json` | One dependency depends on other dependencies, and those depend on more. All of them (not just the ones in `package.json`) are listed here with exact versions, so every install gets the same versions. |
>
> Ask the developers (or check `package.json`) for these before you start, so you install the right version and know where everything goes.

### 1. Install Node.js

RHEL offers multiple versions of the same software as **modules**. The default Node.js is old, so pick the version the app needs.

```bash
dnf module list nodejs              # see available versions
dnf module disable nodejs -y        # disable default version
dnf module enable nodejs:24 -y      # enable required version
dnf install nodejs -y
node -v
```

| Command | What It Does |
|---------|--------------|
| `dnf module list nodejs` | Lists the Node.js versions available |
| `dnf install nodejs` (alone) | Installs the **default** version - you don't know which version you get |
| `dnf module disable nodejs -y` | Disables the default version |
| `dnf module enable nodejs:24 -y` | Enables the exact version the app needs |

### 2. Create a System User

Before creating the user, understand why we need one.

#### Human User vs System User

| | Human User | System User |
|---|------------|-------------|
| Who uses it | A real person (you, a teammate) | An application or service |
| How it logs in | Username/password or username/key | It doesn't log in at all |
| Shell/terminal | Yes | No (`/sbin/nologin`) |
| UID | 1000 and above | Below 1000 |
| Example | `ec2-user`, `ramesh` | `expense`, `nginx`, `mysql` |

#### Problems with Running the App as a Human or Root User

1. **Too much access** - a human/root user can do a lot on the server. If the server is hacked, their credentials leak and the attacker gets all those privileges.
2. **Bigger blast radius** - "blast radius" means how much damage spreads. The attacker can reach everything that user can reach, not just the app.
3. **Files owned by a person** - the app's files and folders end up under a person's name, which gets messy.
4. **What if the person resigns?** - their account gets removed, and the app running under it stops working.
5. **Auditing and accountability** - in the logs you can't tell whether the person did something or the app did it.

#### Why a System User

Instead of running applications or services with human credentials, we create a **system user** just for the app. This:

- **limits the blast radius** - if the app is hacked, the damage stays inside the app.
- **follows least privilege** - the app gets only the access it needs, nothing more.
- has **no interactive login** - no password, no key, no login, no shell/terminal. Even if the app is hacked, the attacker can't log in as this user.
- doesn't depend on any person - nobody "owns" it, so nothing breaks when someone leaves.

> **If nobody can log in as the system user, how does the app run?**
>
> Nobody logs in and starts the app by hand. **systemd** (the service manager) starts it for us. In the service file we write `User=expense`, so when we run `systemctl start backend`, systemd starts the app **as the `expense` user**. The app runs with only that user's permissions, and nobody ever needs a login. See [Step 5](#5-create-the-service-file).

#### Create It

```bash
useradd --system --home /app --shell /sbin/nologin --comment "expense system user" expense
id expense
```

| Option | Meaning |
|--------|---------|
| `--system` | System user (UID below 1000) |
| `--home /app` | Home directory |
| `--shell /sbin/nologin` | Nobody can log in as this user |
| `--comment` | Description |

### 3. Download the Code

```bash
mkdir -p /app
curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-backend-v3.tar.gz
cd /app
tar -xzf /tmp/backend.tar.gz --strip-components=1
ls /app
```

`--strip-components=1` extracts the files directly into `/app` instead of a subfolder.

### 4. Install Dependencies

```bash
cd /app
npm install
```

`npm` reads `package.json` and downloads the libraries into `node_modules/`.

### 5. Create the Service File

When we install a package like Nginx (`dnf install nginx -y`), it brings its own service file, so `systemctl start nginx` works straight away.

Our backend is a customised app developed by us, so it has no service file. systemctl can't start it until we write one. The service file answers 3 questions:

1. **Who** runs the app? → `User=`
2. **How** to run the app? → `ExecStart=`
3. **What settings** does the app need (DB address, username, password)? → `Environment=`

Custom service files go in `/etc/systemd/system/`:

```bash
vim /etc/systemd/system/backend.service
```

```ini
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=<mysql-private-ip>
Environment=DB_USER=expense
Environment=DB_PWD=<db-app-password>
Environment=DB_DATABASE=transactions
ExecStart=/bin/node /app/index.js
SyslogIdentifier=backend
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

| Line | Meaning |
|------|---------|
| `After=network.target` | Start after network is ready |
| `User=expense` | Run as the system user |
| `Environment=` | Settings passed into the app (DB address, user, password) |
| `ExecStart=` | Command that starts the app |
| `Restart=on-failure` | Auto-restart if the app crashes |
| `RestartSec=5` | Wait 5 seconds before restarting |
| `WantedBy=multi-user.target` | Allows `enable` (start on boot) |

### 6. Load the Database Schema

Install the MySQL **client** (the server is on the other machine):

```bash
dnf install mysql -y
mysql -h <mysql-private-ip> -u root -p < /app/schema/backend.sql
```

| Option | Meaning |
|--------|---------|
| `-h` | Database server IP |
| `-u` | Database user |
| `-p` | Ask for password |
| `< file.sql` | Run the SQL file |

This creates the `transactions` database, table, and the `expense` DB user.

### 7. Start the Backend

```bash
systemctl daemon-reload      # needed after creating/editing a service file
systemctl enable backend
systemctl start backend
systemctl status backend
```

| Command | What It Does |
|---------|--------------|
| `systemctl daemon-reload` | Makes systemd read the new/changed service file |
| `systemctl enable backend` | Starts the app automatically when the server boots |
| `systemctl start backend` | Starts the app now |
| `systemctl status backend` | Shows if the app is running |

**What happens when we run `systemctl start backend`:**

1. systemd looks in `/etc/systemd/system/`.
2. It finds `backend.service`.
3. It reads `User=expense` and runs the app as that user.
4. It passes the `Environment=` values (DB details) into the app.
5. It runs the `ExecStart=` command → `/bin/node /app/index.js`, and the app starts.

### 8. Verify

```bash
netstat -lntp                       # 8080 should be listening
curl http://localhost:8080/health   # should respond OK
journalctl -u backend -f            # live logs (Ctrl+C to exit)
```

✅ Backend is ready.

---

## Part 3 - Frontend Server (Nginx)

SSH into the **frontend** server.

### 1. Install and Start Nginx

```bash
dnf install nginx -y
systemctl enable nginx
systemctl start nginx
```

Open `http://<frontend-public-ip>` in the browser → default Nginx page.

### 2. Replace Default Page with Our App

```bash
rm -rf /usr/share/nginx/html/*
curl -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-frontend-v3.tar.gz
cd /usr/share/nginx/html
tar -xzf /tmp/frontend.tar.gz --strip-components=1
```

`/usr/share/nginx/html` = folder Nginx serves web pages from.

### 3. Connect Frontend to Backend (Reverse Proxy)

The browser only talks to the frontend. Nginx forwards any `/api/` request to the backend.

```text
Browser ── /api/expense ──▶ Nginx (frontend) ──▶ http://<backend-private-ip>:8080/expense
```

```bash
vim /etc/nginx/default.d/expense.conf
```

```nginx
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

location /api/ {
    proxy_pass http://<backend-private-ip>:8080/;
}

location /health {
    stub_status on;
    access_log off;
}
```

### 4. Check Config and Restart

```bash
nginx -t                   # test config syntax
systemctl restart nginx
```

### 5. Verify

```bash
curl http://localhost/api/health    # response comes from the backend
```

✅ Frontend is ready.

---

## Test the Full App

1. Open `http://<frontend-public-ip>` in the browser.
2. Add an expense (e.g. food, 100, masala dosa).
3. It should appear in the list.
4. Check it reached the database (from backend server):

```bash
mysql -h <mysql-private-ip> -u root -p
```

```sql
USE transactions;
SELECT * FROM transactions;
```

---

## Troubleshooting

Check from **frontend to database**, one tier at a time.

| # | Check | Command |
|---|-------|---------|
| 1 | Service running? | `systemctl status nginx` / `backend` / `mysqld` |
| 2 | Port listening? | `netstat -lntp` |
| 3 | Process running? | `ps -ef \| grep node` |
| 4 | Logs | `journalctl -u backend -f` / `/var/log/nginx/error.log` |
| 5 | Can backend reach DB? | `mysql -h <mysql-private-ip> -u root -p` |
| 6 | Can frontend reach backend? | `curl http://<backend-private-ip>:8080/health` |
| 7 | Security group allows the port? | AWS console |

### Common Mistakes

| Problem | Fix |
|---------|-----|
| Backend fails to start after editing the service file | `systemctl daemon-reload` |
| Backend can't connect to DB | Wrong `DB_HOST` IP, or DB security group missing 3306 |
| Page loads but no data | Wrong backend IP in `expense.conf`, or backend SG missing 8080 |
| Nginx won't restart | Run `nginx -t` to find the config error |
| Used public IP between servers | Use **private** IPs |

---

## Concepts Learned

### 1. System User

- **Human user** → for people, logs in with username/password or key, has a shell.
- **System user** → for apps/services, no login, no credentials, no shell.
- Running apps as a human/root user means more privileges, bigger blast radius, files under a person's name, breaks when the person resigns, and poor auditing.
- So we run apps as a system user → smaller blast radius and least privilege.

Full explanation → [Part 2, Step 2](#2-create-a-system-user).

### 2. Build Tools

Developers write a lot of files. Before the app can run, the same steps have to be repeated every time. A **build tool** automates them.

**What a build tool does:**

1. **Installs dependencies** (libraries the code needs).
2. **Automates repeating steps**: clean old output → download new code → compile the code → install dependencies → create the application.
3. **Gives a standard project structure**, so every project is organised the same way.
4. **Runs test cases** automatically and **creates the artifact**, the packaged app (`.zip`, `.tar.gz`, `.jar`, `.war`, `.ear`).

A **build file** holds info about the application: name, description, version, dependencies, and how to start it.

| Language | Build Tool | Build File | Code Extension |
|----------|------------|------------|----------------|
| Java | Maven | `pom.xml` | `.java` |
| Node.js | npm | `package.json` | `.js` |
| Python | pip | `requirements.txt` | `.py` |

In this project: Node.js 24, `npm`, `package.json`, dependencies in `node_modules/`, exact versions in `package-lock.json`.

### 3. Systemd Service Files

Nginx and MySQL come with service files, so `systemctl start nginx` just works. Our backend is **custom code** - we write `/etc/systemd/system/backend.service` to tell Linux:
- **Who** runs it (`User=`)
- **How** to run it (`ExecStart=`)
- **What settings** it needs (`Environment=`)

A service file answers 3 questions:
1. **Who** has to run this application?
2. **How** to run the application?
3. Does the application need any **environment** (DB URL, credentials, etc.)?

What happens on `systemctl start backend`:
1. Goes to `/etc/systemd/system`
2. Searches for `backend.service`
3. Runs the start command (`ExecStart`) and injects the environment
4. Uses the `User` info to decide who runs the service

#### systemctl Commands

Works the same for packages (`nginx`) and our custom service (`backend`):

```bash
systemctl start backend      # start now
systemctl stop backend       # stop
systemctl restart backend    # stop + start
systemctl status backend     # is it running?
systemctl enable backend     # start automatically on boot
systemctl disable backend    # don't start on boot
```

Example with a package: `dnf install nginx -y` → `systemctl start nginx` works straight away, because the package brings its own service file. Our backend is a customised application developed by us, so it can't start through systemctl until we write its service file.

### 4. Server vs Client Packages

| | Server | Client |
|---|--------|--------|
| Web | facebook.com | Chrome |
| MySQL | `mysql-server` (DB server) | `mysql` (backend server) |

### 5. Public IP vs Private IP

| | Public IP | Private IP |
|---|-----------|------------|
| Reachable from | Internet | Only inside the network |
| Example | `106.205.31.68` | `192.168.1.13`, `172.31.x.x` |
| Changes on EC2 stop/start | Yes | No |
| Use for | Users, SSH from laptop | Server-to-server |

**IPv4** = 2^32 ≈ 4 billion addresses - not enough for every device, so private IPs are reused inside networks.

### 6. Reverse Proxy

Nginx on the frontend forwards `/api/` requests to the backend. The user never talks to the backend directly, so the backend stays private.

---

## Summary

### Key Topics

1. **System user** - why apps don't run as human users
2. **Programming languages** - extensions, build tools, build files, dependencies
3. **Systemctl service files** - running custom apps as services
4. **Public IP vs private IP**
5. **Security group** - DB must allow inbound 3306 from the backend

### Servers at a Glance

| Server | Install | Key Files | Port |
|--------|---------|-----------|------|
| Database | `mysql-server` | - | 3306 |
| Backend | `nodejs`, `mysql` (client) | `/app`, `/etc/systemd/system/backend.service` | 8080 |
| Frontend | `nginx` | `/usr/share/nginx/html`, `/etc/nginx/default.d/expense.conf` | 80 |

- Set up in order: **DB → Backend → Frontend**.
- Servers talk over **private IPs**; only the frontend is public.
- Run apps as a **system user**.
- Custom apps need a **systemd service file** + `daemon-reload`.
- Troubleshoot: service → port → process → logs → security group.

---

## Interview Questions

**1. Explain how you deployed a 3-tier application.**

I built an expense app on 3 EC2 servers. **DB**: installed MySQL, set the root password. **Backend**: installed Node.js, created a system user, downloaded the code to `/app`, ran `npm install`, created a systemd service with the DB details, loaded the schema. **Frontend**: installed Nginx, deployed the web files and configured a reverse proxy for `/api/` to the backend. Servers talk over private IPs, and security groups allow only 80 from the internet, 8080 from frontend and 3306 from backend.

**2. Why run an application as a system user, not root or a human user?**

Instead of running applications on servers with human credentials, we use a system user to limit the blast radius and follow least privilege. It has no password, no login and no shell (`/sbin/nologin`), the app doesn't break when an employee leaves, and audit logs clearly show what the app did.

**3. If a system user can't log in, how does the app run?**

systemd starts it. The service file has `User=expense`, so `systemctl start backend` runs the app as the `expense` user. Nobody needs to log in, and the app gets only that user's permissions.

**4. What is a systemd service file? Where is it stored?**

A config file that tells Linux how to run an app as a service - who runs it (`User`), how (`ExecStart`), settings (`Environment`), and restart behaviour. Custom ones go in `/etc/systemd/system/<name>.service`.

**5. Why run `systemctl daemon-reload`?**

systemd caches service files. After creating or editing one, `daemon-reload` makes it read the changes.

**6. What does `Restart=on-failure` do?**

Automatically restarts the app if it crashes (after `RestartSec` seconds).

**7. What is a build tool? Give examples.**

Automates downloading dependencies, compiling, testing and packaging into an artifact. Java → Maven (`pom.xml`), Node.js → npm (`package.json`), Python → pip (`requirements.txt`).

**8. What is an artifact?**

The packaged, ready-to-deploy output of a build - `.jar`, `.war`, `.zip`, `.tar.gz`.

**9. `package.json` vs `package-lock.json` vs `node_modules`?**

`package.json` lists dependencies and app info. `package-lock.json` lists every dependency, including the dependencies of dependencies, with exact versions. `node_modules/` holds the downloaded dependencies.

**10. What is a reverse proxy? Why use Nginx for it?**

A server that receives client requests and forwards them to backend servers. Nginx serves the frontend and forwards `/api/` to the backend, so the backend is never exposed to the internet.

**11. Public IP vs private IP? Why use private IP between servers?**

Public IP is reachable from the internet and changes on stop/start. Private IP works only inside the VPC and doesn't change. Server-to-server traffic uses private IPs - more secure, faster, no data charges.

**12. How do you secure a 3-tier app with security groups?**

Frontend: 80/443 from `0.0.0.0/0`. Backend: 8080 only from frontend SG. DB: 3306 only from backend SG. SSH 22 only from my IP.

**13. `mysql-server` vs `mysql` package?**

`mysql-server` is the database server (on the DB machine). `mysql` is the client used to connect to it (on the backend machine).

**14. Why use `dnf module`?**

RHEL offers several versions of software like Node.js as modules. `dnf module disable` / `enable nodejs:24` installs the exact version the app needs.

**15. The page loads but shows no data. How do you debug?**

Check backend status and logs (`systemctl status backend`, `journalctl -u backend`), test `curl http://localhost:8080/health`, check backend IP in Nginx config, check DB connectivity from backend (`mysql -h <db-ip>`), and check SG ports 8080 and 3306.

**16. How do you validate Nginx config before restarting?**

`nginx -t`.
