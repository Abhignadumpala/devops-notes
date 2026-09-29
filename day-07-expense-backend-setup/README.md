# Day 7 - Expense Project: Backend Setup

## Table of Contents

1. [What We Are Building](#what-we-are-building)
2. [Backend Setup Steps](#backend-setup-steps)
3. [Step 1: Install Node.js](#step-1-install-nodejs)
4. [Step 2: System User](#step-2-system-user)
5. [Step 3: Download the Code](#step-3-download-the-code)
6. [Step 4: Install Dependencies](#step-4-install-dependencies)
7. [Build Tools](#build-tools)
8. [Step 5: Systemd Service File](#step-5-systemd-service-file)
9. [Step 6: Load the Database Schema](#step-6-load-the-database-schema)
10. [Public IP vs Private IP](#public-ip-vs-private-ip)
11. [Security Group: Backend → Database](#security-group-backend--database)
12. [Summary](#summary)

---

## What We Are Building

**Expense app** - records daily expenses.

| id | category | amount | date | description |
|----|----------|--------|------|-------------|
| 1 | food | 100 | 29-SEP-2026 | masala dosa |

3-tier (see [Day 6](../day-06-3-tier-architecture-databases/README.md)):

```text
Frontend (nginx) → Backend (Node.js) → Database (MySQL)
```

Today: **Backend** server.

---

## Backend Setup Steps

1. Install programming runtime (Node.js)
2. Create a system user to run the app
3. Create an app directory and download the code
4. Install dependencies
5. Create a systemd service file
6. Load the database schema
7. Start the service

---

## Step 1: Install Node.js

RHEL uses **modules** to offer multiple versions of the same software.

```bash
dnf module list nodejs              # list available Node.js versions
sudo dnf module disable nodejs -y   # disable the default (old) version
sudo dnf module enable nodejs:24 -y # enable the version we need
sudo dnf install nodejs -y
node -v                             # verify
```

> Plain `dnf install nodejs` installs the default version, which may not be the one the app needs. Always pin the version.

---

## Step 2: System User

### Why Not Run the App as a Human or Root User?

1. **Too many privileges** - if the server is hacked, their credentials leak.
2. **Bigger blast radius** - an attacker gets everything that user can access.
3. Files and folders end up owned by a person's name.
4. **What if the person resigns?** The app breaks when their account is removed.
5. **Auditing & accountability** - hard to tell whether a human or the app did something.

### System User

A **system user** is for running applications:
- No password, no login, no shell/terminal access
- **Least privilege** - only access to what the app needs
- Limits the **blast radius**

```bash
sudo useradd --system --home /app --shell /sbin/nologin --comment "expense system user" expense
id expense
```

| Option | Meaning |
|--------|---------|
| `--system` | System user (UID < 1000) |
| `--home /app` | Home directory |
| `--shell /sbin/nologin` | Cannot log in |
| `--comment` | Description |

---

## Step 3: Download the Code

```bash
sudo mkdir -p /app
curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-backend-v3.tar.gz
cd /app
sudo tar -xzf /tmp/backend.tar.gz
```

---

## Step 4: Install Dependencies

```bash
cd /app
sudo npm install
sudo chown -R expense:expense /app
```

`npm install` reads `package.json` and downloads dependencies into `node_modules/`.

---

## Build Tools

Developers write many files. Before the app can run, someone has to:

1. Download and install dependencies (libraries)
2. Compile the code
3. Run unit tests
4. Package the app into an **artifact** (`.zip`, `.tar.gz`, `.jar`, `.war`, `.ear`)

A **build tool** automates these repeated steps and gives a standard project structure.

A **build file** describes the app: name, description, version, dependencies, how to start it.

| Language | Build Tool | Build File | Code Extension |
|----------|------------|------------|----------------|
| Java | Maven | `pom.xml` | `.java` |
| Node.js | npm | `package.json` | `.js` |
| Python | pip | `requirements.txt` | `.py` |

### Node.js in Our Project

| Question | Answer |
|----------|--------|
| Node.js version | 24 |
| Build tool | npm |
| Build file | `package.json` |
| Dependencies folder | `node_modules/` |
| Exact dependency versions | `package-lock.json` |

---

## Step 5: Systemd Service File

Packages like **nginx** come with a service file, so `systemctl start nginx` just works.

Our backend is a **custom application** - systemctl doesn't know how to start it. We must create a service file that tells:
- **Who** runs the app (user)
- **How** to run it (command)
- **What environment** it needs (DB host, credentials)

```bash
sudo vim /etc/systemd/system/backend.service
```

```ini
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=<db-private-ip>
Environment=DB_USER=expense
Environment=DB_PWD=<db-password>
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
| `Environment=` | Variables injected into the app |
| `ExecStart=` | Command to start the app |
| `Restart=on-failure` | Restart automatically if it crashes |
| `RestartSec=5` | Wait 5 seconds before restarting |
| `WantedBy=multi-user.target` | Needed for `enable` (start on boot) |

### Start the Service

```bash
sudo systemctl daemon-reload     # reload after creating/editing a service file
sudo systemctl enable backend
sudo systemctl start backend
sudo systemctl status backend
```

### What Happens on `systemctl start backend`

1. Looks in `/etc/systemd/system/`
2. Finds `backend.service`
3. Injects the environment variables
4. Runs `ExecStart` as the given `User`

---

## Step 6: Load the Database Schema

### Server vs Client Packages

| | Server | Client |
|---|--------|--------|
| Web | facebook.com | Chrome |
| MySQL | `mysql-server` (on DB server) | `mysql` (on backend server) |

```bash
sudo dnf install mysql -y
mysql -h <db-private-ip> -u root -p < /app/schema/backend.sql
```

- `-h` = DB host
- `-u` = DB user
- `-p` = prompts for password
- `< file.sql` = run the SQL file

Then restart the backend:

```bash
sudo systemctl restart backend
```

---

## Public IP vs Private IP

| | Public IP | Private IP |
|---|-----------|------------|
| Reachable from | Internet | Only inside the network (VPC) |
| Example | `106.205.31.68` | `192.168.1.13`, `172.31.x.x` |
| Changes on EC2 stop/start | Yes | No |
| Use for | Users, SSH from laptop | Server-to-server (backend → DB) |

**IPv4** = 2^32 ≈ **4 billion** addresses - not enough for every device, so private IPs are reused inside networks.

> Backend should connect to the DB using its **private IP** - faster, free, and not exposed to the internet.

---

## Security Group: Backend → Database

DB server security group must allow inbound MySQL from the backend:

| Type | Port | Source |
|------|------|--------|
| MySQL | 3306 | Backend server's security group / private IP |

---

## Summary

1. **System user** - run apps without login, least privilege, small blast radius.
2. **Languages & build tools** - Java/Maven/`pom.xml`, Node/npm/`package.json`, Python/pip/`requirements.txt`; dependencies go in `node_modules/`.
3. **Systemd service file** - tells Linux who, how, and with what environment to run a custom app.
4. **Public vs private IP** - servers talk to each other over private IPs.
5. **Security group** - DB must allow port 3306 inbound from backend.
