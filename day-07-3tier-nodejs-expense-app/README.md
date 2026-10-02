# Day 7 - Expense Project: Database, Backend & Frontend

A complete 3-tier app on 3 Linux servers, set up step by step.

> **📌 Remember this structure - it works for ANY programming language**
>
> 1. Install the programming language - Node.js 24
> 2. Create one directory for the application - `/app`
> 3. Create one system user to run the application - `expense`
> 4. Download the application as `.tar.gz` into `/tmp`
> 5. Extract it into `/app`
> 6. Install dependencies
> 7. Create the systemctl service file
> 8. Load the schema into the DB
> 9. Start the application
>
> Whether the app is Node.js, Java or Python, these **9 steps stay the same**. Only the language, build tool, build file and file extension change:
>
> | Step | Node.js | Java | Python |
> |------|---------|------|--------|
> | 1. Install language | `nodejs:24` | Java (JDK) | Python 3 |
> | 6. Install dependencies | `npm install` (reads `package.json`) | `mvn package` (reads `pom.xml`) | `pip install -r requirements.txt` |
> | Code extension | `.js` | `.java` | `.py` |
> | 7. `ExecStart=` in service file | `/bin/node /app/index.js` | `/bin/java -jar /app/<app>.jar` | `/bin/python3 /app/<app>.py` |
>
> Once I understand this structure, I can deploy an app in any language.

> **📌 Node.js - things to remember**
>
> | Item | What It Is |
> |------|------------|
> | File extension | `.js` |
> | Build tool | `npm` |
> | Build file | `package.json` → app name, version, description, start scripts, dependencies |
> | Install command | `npm install` → reads `package.json` and downloads the dependencies |
> | `package-lock.json` | Locks the **exact versions** of all dependencies **and their sub-dependencies**, so every install is the same |
> | `node_modules/` | Folder where all the downloaded dependencies live |

## Table of Contents

1. [What We Are Building](#what-we-are-building)
2. [Before You Start](#before-you-start)
3. [Part 1 - Database Server (MySQL)](#part-1---database-server-mysql)
4. [Part 2 - Backend Server (Node.js)](#part-2---backend-server-nodejs)
5. [Part 3 - Frontend Server (Nginx)](#part-3---frontend-server-nginx)
6. [Test the Full App](#test-the-full-app)
7. [Troubleshooting](#troubleshooting)
8. [Hands-On](#hands-on)
9. [Concepts Learned](#concepts-learned)
10. [Summary](#summary)
11. [Interview Questions](#interview-questions)

**More in this folder:**

| Folder / File | What's Inside |
|---------------|---------------|
| [hands-on/](hands-on/README.md) | My actual run with screenshots, mistakes and fixes |
| [troubleshooting/](troubleshooting/README.md) | Debug steps, common mistakes, what each error means |
| [concepts/](concepts/README.md) | System user, build tools, service files, IPs, reverse proxy, Nginx, load balancer, REST API, status codes |
| [interview-questions/](interview-questions/README.md) | 26 questions with short answers |
| [01-mysql.md](01-mysql.md), [02-backend.md](02-backend.md), [03-frontend.md](03-frontend.md) | Quick setup commands per server |

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

Run all setup commands as **root**, not ec2-user. Log in as `ec2-user`, then switch to root:

```bash
ssh ec2-user@<public-ip>    # 1. log in as ec2-user
sudo su -                   # 2. become root
whoami                      # 3. should print: root
```

The prompt also shows it: `#` = root, `$` = normal user.

**Why root?** Every setup step changes the system, and a normal user isn't allowed to:

| Command | Why It Needs Root |
|---------|-------------------|
| `dnf install ...` | Installs software system-wide |
| `useradd ...` | Creates users |
| `mkdir /app`, `tar` into `/app` | `/` is owned by root. As ec2-user: `mkdir: cannot create directory '/app': Permission denied` |
| `npm install` in `/app` | Writes `node_modules/` inside `/app` |
| `vim /etc/systemd/system/backend.service` | `/etc` is owned by root |
| `systemctl ...` | Manages system services |

> **Root sets up, the system user runs.** We use root only to set up the server (install packages, create the `expense` user, create `/app`, put the code there, write the service file). The app itself runs as `expense` because systemd reads `User=expense`. So the running app never has root power. Check with `ps -ef | grep node` → the process owner is `expense`, not root.

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

SSH into the **backend** server and switch to root (`sudo su -`). All the steps below (create the system user, create `/app`, download the code, `npm install`, service file) are run as **root**.

**Backend setup steps:**

1. Install the programming language - Node.js 24
2. Create one directory for the application - `/app`
3. Create one system user to run the application - `expense`
4. Download the application as `.tar.gz` into `/tmp`
5. Extract it into `/app`
6. Install dependencies (`npm install`)
7. Create the systemctl service file
8. Load the schema into the DB
9. Start the application

All 3 servers use the AMI **`Redhat-9-DevOps-Practice`** (`ami-0220d79f3f480ecf5`) - see [Step 2](#step-2-launch-3-ec2-instances).

> **Note - Before building any Node.js application, check these first:**
>
> | Check | For This App | Simple Meaning |
> |-------|--------------|----------------|
> | Node.js version | `24` | The version the app is written for. Install the same one, or the app may not run. |
> | Build tool | `npm` | The tool that downloads libraries and builds/runs the app. |
> | Build file | `package.json` | Lists the app's name, version, description, start scripts and the libraries it needs. `npm` reads this file. |
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

#### Check the User Was Created

**1. `id expense`**

```bash
id expense
```

```
uid=991(expense) gid=991(expense) groups=991(expense)
```

UID below 1000 → it's a **system user** (the number may be different on your server). If the user doesn't exist: `id: 'expense': no such user`.

**2. Look in `/etc/passwd`** (where Linux stores all users)

```bash
grep expense /etc/passwd
```

```
expense:x:991:991:expense system user:/app:/sbin/nologin
```

| Field | Value | Meaning |
|-------|-------|---------|
| 1 | `expense` | Username |
| 2 | `x` | Password placeholder (stored elsewhere) |
| 3 | `991` | UID (below 1000 = system user) |
| 4 | `991` | GID |
| 5 | `expense system user` | Our `--comment` |
| 6 | `/app` | Our `--home` |
| 7 | `/sbin/nologin` | Our `--shell` (no login) |

This one line confirms all our `useradd` options.

**3. Try to log in as the user** (should fail)

```bash
su - expense
```

```
This account is currently not available.
```

This proves `/sbin/nologin` is working.

### 3. Download the Code

```bash
mkdir -p /app
curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-backend-v3.tar.gz
cd /app
tar -xzf /tmp/backend.tar.gz --strip-components=1
ls /app
```

`--strip-components=1` removes the first folder level from each path in the archive. This package stores files as `./index.js`, `./package.json`..., so it only strips the leading `./` - plain `tar -xzf` gives the same result here. It matters when a package has everything inside a top folder (e.g. `backend/index.js`); then it puts the files straight into `/app` instead of `/app/backend/`.

#### What `mkdir -p /app` Means

| Part | Meaning |
|------|---------|
| `mkdir` | **m**a**k**e **dir**ectory - creates a folder |
| `-p` | **p**arents - creates missing parent folders, and **no error if the folder already exists** |
| `/app` | The leading `/` means start from the top of the filesystem → folder is `/app` |

```bash
mkdir /app         # run twice → error: File exists
mkdir -p /app      # run twice → no error, does nothing
mkdir -p /a/b/c    # creates /a, /a/b and /a/b/c in one go
```

We use `-p` so the command is **safe to run again** (`useradd --home /app` may have already created it).

#### Where Is `/app`?

`/app` is at the **top** of the filesystem, not in root's home folder. If the prompt shows `[ root@backend ~ ]#`, the `~` means you are in `/root`, so plain `ls` won't show `app`.

```
/             ← top of the filesystem
├── app       ← our folder
├── etc
├── root      ← root's home (~)
└── ...
```

```bash
ls -ld /app    # check the folder exists → drwxr-xr-x ... root root ... /app
cd /app        # go into it
pwd            # prints /app
```

A path starting with `/` (like `/app`) is the same from anywhere. `mkdir app` (no `/`) would create `/root/app` instead.

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

**Example - filled in on my backend server:**

```ini
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=172.31.4.135
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

- `DB_HOST` → the **private IP of the MySQL server** (EC2 console → mysql instance → *Private IPv4 address*). Yours will be different.
- `DB_PWD` → the password of the `expense` DB user, the same one set in `/app/schema/backend.sql`.
- Save and exit vim: `Esc` → `:wq` → `Enter`.

| Line | Meaning |
|------|---------|
| `After=network.target` | Start after network is ready |
| `User=expense` | Run as the system user |
| `Environment=` | Settings passed into the app (DB address, user, password) |
| `ExecStart=` | Command that starts the app |
| `Restart=on-failure` | Auto-restart if the app crashes |
| `RestartSec=5` | Wait 5 seconds before restarting |
| `WantedBy=multi-user.target` | Allows `enable` (start on boot) |

**What happens when we run `systemctl start backend`:**

1. systemd looks in `/etc/systemd/system/`.
2. It finds `backend.service`.
3. It reads `User=expense` and runs the app as that user.
4. It passes the `Environment=` values (DB details) into the app.
5. It runs the `ExecStart=` command → `/bin/node /app/index.js`, and the app starts.

> **Note:** The backend needs to know where the database is, so we give the DB server's IP in `Environment=DB_HOST=`. Use the DB server's **private IP**: it doesn't change on stop/start and the traffic stays inside AWS. More → [Public IP vs Private IP](concepts/README.md#5-public-ip-vs-private-ip).

### 6. Load the Database Schema

**Why?** The app stores expenses, so the database needs a **table** to keep them in. Each expense is one row:

| id | category | amount | description |
|----|----------|--------|-------------|
| 1 | food | 100 | masala dosa |

The table structure (the **schema**) is given by the application team inside the code, in `/app/schema/backend.sql`. We just load it into the DB server.

#### Check the schema file first

```bash
cat /app/schema/backend.sql
```

```sql
CREATE DATABASE IF NOT EXISTS transactions;
USE transactions;

CREATE TABLE IF NOT EXISTS transactions (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    amount      INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    category    VARCHAR(50) NOT NULL
);

CREATE USER IF NOT EXISTS 'expense'@'%' IDENTIFIED BY '<db-app-password>';
GRANT ALL ON transactions.* TO 'expense'@'%';
FLUSH PRIVILEGES;
```

What it does:

1. Creates the `transactions` database (if it doesn't exist).
2. Creates the `transactions` table with columns `id`, `amount`, `description`, `category`.
3. Creates the `expense` DB user with a password (if it doesn't exist).
4. Gives that user full access to the `transactions` database. The backend logs in to the DB as this user (`DB_USER` / `DB_PWD` in the service file).

#### Where Is the Table Created?

On the **DB server**, not on the backend. The backend only **sends** the SQL:

```
BACKEND SERVER                              DB SERVER
┌───────────────────────┐                   ┌────────────────────────────┐
│ /app/schema/          │                   │ mysql-server (mysqld)      │
│   backend.sql         │   port 3306       │                            │
│        │              │ ───────────────►  │ runs the SQL               │
│        ▼              │   sends the SQL   │   → creates DB, table, user│
│ mysql (client)        │                   │ stored in /var/lib/mysql/  │
└───────────────────────┘                   └────────────────────────────┘
```

1. The `mysql` client on the backend reads `backend.sql`.
2. `-h <mysql-private-ip>` tells it to connect to the DB server on port 3306.
3. The MySQL server runs the SQL and stores the database, table and user on its own disk.

#### Why Load It From the Backend?

1. **The file is on the backend.** `backend.sql` comes inside the backend code package. The developers ship the table structure with the code that uses it. The DB server only has MySQL, not this file.
2. **It tests the same connection the app will use.** If this works, the DB IP is right, port 3306 is open in the security group, and MySQL is accepting logins. If it fails here, the app would fail too.

#### What `IF NOT EXISTS` Does

| On the DB server | What Happens |
|------------------|--------------|
| Table **doesn't exist** | It gets **created** |
| Table **already exists** | **Skipped** - no error, existing data is safe |

Same for the database and the user. Without it, running the file again gives `ERROR 1050: Table 'transactions' already exists`. With it, the file is **safe to run again**.

#### Install the MySQL client

To talk to the DB server from the backend server, we need the MySQL **client**, not the server:

| | Server | Client |
|---|--------|--------|
| Web | facebook.com | Chrome |
| MySQL | `mysql-server` → on the DB server | `mysql` → on the backend server |

Just like Chrome (client) connects to facebook.com (server), the `mysql` client on the backend connects to `mysql-server` on the DB server.

```bash
dnf install mysql -y
```

#### Allow backend → DB in the security group

The DB server must accept connections from the backend on port **3306**. In `mysql-sg`, allow inbound **3306** from `backend-sg` (or from the backend server's private IP). Without this, the `mysql` command just hangs. See [Step 1](#step-1-create-security-groups).

#### Load it

```bash
mysql -h <mysql-private-ip> -u root -p < /app/schema/backend.sql
```

| Option | Meaning |
|--------|---------|
| `-h` | Database server IP |
| `-u` | Database user |
| `-p` | Ask for password |
| `< file.sql` | Run the SQL file |

Now the table is ready, and the backend can read and write expenses.

> Here we connect to the DB directly from the backend server. In real projects we connect to the DB through a **bastion host** (a jump server). That comes later.

### 7. Start the Backend

> **Don't jump to `systemctl start backend` right after writing the service file.** First:
>
> 1. **Load the DB schema** ([Step 6](#6-load-the-database-schema)) - the service file uses `DB_USER=expense` and `DB_DATABASE=transactions`, which don't exist until `backend.sql` is loaded. Otherwise the app can't log in to the DB (`"db":"down"`).
> 2. **Run `systemctl daemon-reload`** - systemd only knows service files it has already loaded. Without it you get `Unit backend.service not found`. Run it again **every time you edit** the file.
>
> **Order:** write service file → load schema → `daemon-reload` → `enable` → `start` → `status`

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

Flow of `systemctl start backend` → [Step 5](#5-create-the-service-file).

If it fails, `journalctl -u backend -f` shows the error (e.g. wrong DB IP, port 3306 blocked).

### 8. Verify

```bash
systemctl status backend            # should say active (running)
ps -ef | grep node                  # node process running as the expense user
netstat -lntp                       # port 8080 should be listening
curl http://localhost:8080/health   # app health check
journalctl -u backend -f            # live logs (Ctrl+C to exit)
```

| Command | What It Checks |
|---------|----------------|
| `systemctl status backend` | Is the service running? |
| `ps -ef \| grep node` | Is the `node` process running, and as which user? |
| `netstat -lntp` | Which ports are open. Look for `8080` |
| `curl http://localhost:8080/health` | Does the app answer? `"status":"ok"` means the app is running |
| `journalctl -u backend -f` | App logs, for errors |

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
Browser ── /api/transaction ──▶ Nginx (frontend) ──▶ http://<backend-private-ip>:8080/transaction
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

How to debug each tier, common mistakes, and what each error (404 / 502 / 504 / db down) means → [troubleshooting/](troubleshooting/README.md)

---

## Hands-On

My actual run with screenshots, including the mistakes I hit and how I fixed them → [hands-on/](hands-on/README.md)

---

## Concepts Learned

System user, build tools, service files, package vs service, server vs client, public vs private IP, reverse proxy, Nginx & load balancing, REST API, HTTP status codes → [concepts/](concepts/README.md)

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

26 questions with short answers → [interview-questions/](interview-questions/README.md)
