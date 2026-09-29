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

### Create 3 EC2 Servers

| Setting | Value |
|---------|-------|
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`) |
| Names | `mysql`, `backend`, `frontend` |
| Login | `ec2-user` / password given in class |

Note the **private IP** of each server - servers talk to each other using private IPs.

### Security Groups

| Server | Inbound Port | Allow From |
|--------|--------------|------------|
| Frontend | 80 | Internet (`0.0.0.0/0`) |
| Backend | 8080 | Frontend only |
| Database | 3306 | Backend only |
| All | 22 | My IP (for SSH) |

> Only the frontend is open to the internet. Backend and database are hidden behind it.

### Setup Order

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

### 1. Install Node.js

RHEL offers multiple versions of the same software as **modules**. The default Node.js is old, so pick the version the app needs.

```bash
dnf module list nodejs              # see available versions
dnf module disable nodejs -y        # disable default version
dnf module enable nodejs:24 -y      # enable required version
dnf install nodejs -y
node -v
```

### 2. Create a System User

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

Why a system user? → see [Concepts Learned](#1-system-user).

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

Why not run the app as a human or root user?

1. **Too many privileges** - if the server is hacked, their credentials leak.
2. **Bigger blast radius** - attacker gets everything that user can access.
3. Files and folders end up owned by a person's name.
4. **Person resigns** → account removed → app breaks.
5. **Auditing** - hard to tell whether a human or the app did something.

A **system user** has no password, no login, no shell. It follows **least privilege** and limits the **blast radius**.

### 2. Build Tools

Before an app can run, someone has to download dependencies, compile, run tests and package it into an **artifact** (`.zip`, `.tar.gz`, `.jar`, `.war`, `.ear`). A **build tool** automates this. A **build file** describes the app (name, version, dependencies, how to start).

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

On `systemctl start backend`, Linux finds `backend.service`, injects the environment, and runs `ExecStart` as `User`.

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
