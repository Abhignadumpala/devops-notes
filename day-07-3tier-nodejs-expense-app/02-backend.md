# Backend

## Server Login

| Item | Value |
|------|-------|
| Server name | `backend` |
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`, us-east-1) |
| Username | `ec2-user` |
| Password | `DevOps321` |

```bash
ssh ec2-user@<backend-public-ip>    # enter the password
sudo su -                         # become root
hostnamectl set-hostname backend   # name the server, then: exec bash
```

The backend service is responsible for handling API requests and persisting data to the database. It is written in Node.js.

> **Check with the developer for the exact version required. This setup requires Node.js >= 24.**

---

## Install Node.js

By default, Node.js 16 is available on the system. Enable and install version 24:

```bash
dnf module disable nodejs -y
dnf module enable nodejs:24 -y
dnf install nodejs -y
```

| Command | What It Does |
|---------|--------------|
| `dnf module disable nodejs -y` | Turns off the default (old) Node.js version, so it isn't installed by mistake |
| `dnf module enable nodejs:24 -y` | Picks Node.js **24** as the version to install |
| `dnf install nodejs -y` | Installs Node.js 24 (and `npm` with it). `-y` = don't ask for confirmation |

Verify:

```bash
node -v
```

`node -v` prints the installed version, e.g. `v24.19.0`.

---

## Set Up Application Directory

```bash
mkdir /app
```

Creates the `/app` folder at the top of the filesystem. The app's code will live here. (`mkdir -p /app` does the same but doesn't fail if the folder already exists.)

---

## Create Application User

Add a system user to run the application:

```bash
useradd --system --home /app --shell /sbin/nologin --comment "expense system user" expense
```

| Option | What It Does |
|--------|--------------|
| `--system` | Creates a **system user** (UID below 1000), meant for running apps, not people |
| `--home /app` | Sets `/app` as the user's home folder |
| `--shell /sbin/nologin` | Nobody can log in as this user |
| `--comment "..."` | A description, shown in `/etc/passwd` |
| `expense` | The username |

**Why a system user?**

System users (UID 1–999) are created exclusively to run services — not for human login. Compared to normal users they provide:

- **No login access** — `/sbin/nologin` shell blocks any interactive login, reducing attack surface.
- **No password** — cannot be brute-forced via SSH.
- **Least privilege** — only owns the files it needs; a compromised service can't touch the rest of the system.
- **Process accountability** — `ps aux` clearly shows `expense` owns the backend process, making auditing easy.

Normal users start at UID 1000. You can verify this user was created as a system user:

```bash
id expense
grep expense /etc/passwd
```

| Command | What It Shows |
|---------|---------------|
| `id expense` | The user's UID, GID and groups → UID below 1000 means system user |
| `grep expense /etc/passwd` | The user's line in `/etc/passwd` → confirms home `/app` and shell `/sbin/nologin` |

---

## Download and Extract Application

```bash
curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-backend-v5.tar.gz
```

`curl` downloads the app package. `-o /tmp/backend.tar.gz` saves it as a file in `/tmp` (without `-o`, curl just prints the content on screen). `/tmp` is the place for temporary files.

Extract files directly into `/app` (no subfolder):

```bash
cd /app
tar -xzf /tmp/backend.tar.gz
```

| Command | What It Does |
|---------|--------------|
| `cd /app` | Go into `/app`, so the files are extracted here |
| `tar -xzf /tmp/backend.tar.gz` | `x` = extract, `z` = it's gzip-compressed (`.gz`), `f` = file name follows |

After this, `/app` has the code: `index.js`, `package.json`, `schema/` etc. The package stores its files at the top level (`./index.js`, `./package.json`...), so they land directly in `/app` - no subfolder.

---

## Install Dependencies

```bash
cd /app
npm install
```

`npm install` reads `package.json` in the current folder, downloads all the libraries the app needs into `node_modules/`, and writes the exact versions into `package-lock.json`. It must be run inside `/app`, where `package.json` is.

---

## Configure SystemD Service

Create the service file:

```bash
vim /etc/systemd/system/backend.service
```

```bash
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=<MYSQL-SERVER-IPADDRESS>
Environment=DB_USER=expense
Environment=DB_PWD=<db-app-password>
Environment=DB_DATABASE=transactions
Environment=ADMIN_TOKEN=<admin-token>
ExecStart=/bin/node /app/index.js
SyslogIdentifier=backend
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

> **Replace `<MYSQL-SERVER-IPADDRESS>` with the private IP of the MySQL EC2 instance.**

`vim /etc/systemd/system/backend.service` creates the service file in the folder where custom service files go. What each line does:

| Line | What It Does |
|------|--------------|
| `Description=` | A name shown in `systemctl status` |
| `After=network.target` | Start only after the network is ready (the app needs it to reach the DB) |
| `User=expense` | Run the app as the `expense` system user, not root |
| `Environment=DB_HOST=` | DB server's private IP - where the app connects |
| `Environment=DB_USER=` / `DB_PWD=` | The DB username and password the app logs in with |
| `Environment=DB_DATABASE=` | Which database to use (`transactions`) |
| `Environment=ADMIN_TOKEN=` | Secret needed for **Delete All** |
| `ExecStart=/bin/node /app/index.js` | The command that starts the app |
| `SyslogIdentifier=backend` | Name used in the logs (`journalctl`) |
| `Restart=on-failure` | Restart the app automatically if it crashes |
| `RestartSec=5` | Wait 5 seconds before restarting |
| `WantedBy=multi-user.target` | Lets `systemctl enable` start it on boot |

`ADMIN_TOKEN` protects **Delete All**. The UI asks for it; a missing token gives `401`, a wrong one `403`. Optional: `RATE_LIMIT_MAX` (default `10`) and `RATE_LIMIT_WINDOW_SEC` (default `60`) control when write requests start getting `429`.

---

## Load Database Schema

> ⚠️ **Do this step only after the DB server is ready.** On the MySQL server first: MySQL installed, `mysqld` running, root password set ([01-mysql.md](01-mysql.md)). Check from the backend: `mysql -h <MYSQL-SERVER-IPADDRESS> -u root -p -e "SELECT 1;"` must work.
>
> **Common mistake:** setting up the whole backend before the DB. The schema load fails, so the `expense` DB user is never created, and the app says `Access denied for user 'expense'`. Order: **DB → backend → frontend.** See [Troubleshooting](troubleshooting/README.md#my-mistake---loaded-the-schema-before-the-db-was-ready).

```bash
dnf install mysql -y
mysql -h <MYSQL-SERVER-IPADDRESS> -u root -p < /app/schema/backend.sql
```

**`dnf install mysql -y`** - installs the MySQL **client** package on the **backend** server. The MySQL **server** (`mysql-server`) is on the DB server; the backend only needs the client to **connect** to it and send SQL - like Chrome (client) connecting to facebook.com (server). We need it here to load the schema: create the database, the table and the DB user.

**`mysql -h <MYSQL-SERVER-IPADDRESS> -u root -p < /app/schema/backend.sql`** - connects to the DB server and runs the SQL file on it:

| Part | What It Does |
|------|--------------|
| `mysql` | The MySQL client we just installed |
| `-h <MYSQL-SERVER-IPADDRESS>` | **Host** - connect to the DB server's private IP |
| `-u root` | Log in as the MySQL `root` user |
| `-p` | Ask for the password (the MySQL root password set on the DB server) |
| `< /app/schema/backend.sql` | Feed the SQL file into the client - run every command in it |

What the SQL file does **on the DB server**:

1. Creates the `transactions` database (if it doesn't exist).
2. Creates the `transactions` table - columns `id`, `amount`, `description`, `category`.
3. Creates the `expense` DB user with its password (if it doesn't exist).
4. Gives that user full access to the `transactions` database - the app logs in with it (`DB_USER` / `DB_PWD`).

No output = success. It needs port **3306** open from the backend in the DB security group.

---

## Start the Service

```bash
systemctl daemon-reload
systemctl enable backend
systemctl start backend
```

| Command | What It Does |
|---------|--------------|
| `systemctl daemon-reload` | Makes systemd read the new `backend.service` (run again after every edit) |
| `systemctl enable backend` | Start the app automatically when the server boots |
| `systemctl start backend` | Start the app now |

---

## Verification

Check service status:

```bash
systemctl status backend
```

Shows if the service is `active (running)`, its PID and the last few log lines.

Check application logs:

```bash
journalctl -u backend -f
```

`journalctl` shows logs from systemd services. `-u backend` = only this service, `-f` = follow live (Ctrl+C to stop).

Test the health endpoint (from the same server):

```bash
curl http://localhost:8080/health
```

Calls the app's health check on port 8080 from the same server - proves the app is running and can reach the DB.

Expected: `{"status":"ok","db":"up"}`. If MySQL is unreachable you get `503` with `"db":"down"`.

Every request is logged with its status code, e.g. `PUT /transaction/3 200 12ms`. Watch them live with `journalctl -u backend -f` while you click around the UI.

---

## Security Group

Ensure the backend EC2 security group allows **inbound TCP on port 8080** from the frontend EC2's security group only (not from the internet).
