# Day 8 - Troubleshooting Step by Step

[← Back to Day 8 notes](../README.md)

## Table of Contents

1. [Rule: Check the Logs First](#rule-check-the-logs-first)
2. [Step-by-Step Approach](#step-by-step-approach)
3. [Example: 500 Error → Access Denied for User 'expense'](#example-500-error--access-denied-for-user-expense)
4. [Example: ERROR 2003 Can't Connect to MySQL (110)](#example-error-2003-cant-connect-to-mysql-110)
5. [Example: "db":"down" with Empty Error](#example-dbdown-with-empty-error)
6. [Launched from an AMI? Old IPs Everywhere](#launched-from-an-ami-old-ips-everywhere)
7. [Read the MySQL Error Code](#read-the-mysql-error-code)
8. [Quick Checklist](#quick-checklist)

---

## Rule: Check the Logs First

When the app shows an error, don't guess. **Check the logs first.** They tell you which server has the problem and what the exact error is. Follow the request's path: **frontend → backend → DB**.

## Step-by-Step Approach

**Step 1: Frontend logs (Nginx).** On the frontend server:

```bash
cd /var/log/nginx/
tail -f access.log     # watch requests live, look at the status code
tail -f error.log      # Nginx's own errors (e.g. can't connect to backend)
```

Reproduce the problem in the browser and look at the status code in the new line:

| You see | Means | Go to |
|---------|-------|-------|
| `500` | Internal server error, so the backend app failed | Backend logs (step 2) |
| `502` | Nginx can't reach the backend | Is the backend running? (step 3) |
| `503` | Service unavailable, usually the DB is down | DB server |
| `504` | Backend too slow | Backend logs (step 2) |
| `4XX` | Our request is wrong | Check the URL, method or JSON we sent |

**Step 2: Backend logs.** On the backend server:

```bash
journalctl -u backend          # all logs of the backend service
journalctl -u backend -f       # follow live
```

- `-u backend` means "logs of the **unit** (service) named `backend`".
- The backend logs show the **clear, real error**, for example a DB login failure or a crash.

**Step 3: Is the backend running?** On the backend server, check it 3 ways:

```bash
systemctl status backend       # service → should say "active (running)"
ps -ef | grep node             # process → node /app/index.js should be listed
netstat -lntp | grep 8080      # port → 8080 should be in LISTEN state
```

| Check | Good result | Tells you |
|-------|-------------|-----------|
| `systemctl status` | `running` | The service is up |
| `ps -ef` | process listed | The app process is really running |
| `netstat -lntp` | port `8080` opened | The app is listening for requests |

**Step 4: Test the backend directly.** On the backend server:

```bash
curl http://localhost:8080/health
```

`{"status":"ok","db":"up"}` means the backend works and can reach the DB. If this works but the app still fails, the problem is between the frontend and backend: check the backend IP in `expense.conf` and the security group for port 8080.

## Example: 500 Error → Access Denied for User 'expense'

1. The browser shows an error. The frontend `access.log` shows **`500`**.
2. Check the backend logs:
   ```bash
   journalctl -u backend
   ```
   You see an error like:
   ```text
   Access denied for user 'expense'@'<backend-private-ip>' (using password: YES)
   ```
3. **Meaning:** the backend **reached** MySQL (so network and port 3306 are fine), but MySQL **refused the login**. The user, password or allowed host is wrong.
   - MySQL checks the user **together with the host it connects from**, which is why the backend's IP shows up in the error.
4. **Test the login by hand** from the backend server:
   ```bash
   mysql -h <mysql-private-ip> -u expense -p<DB_PASSWORD> -e "show databases;"
   ```
   - Same error → problem is on the **MySQL side** (step 5).
   - Works → problem is in the **service file** (step 6).
5. **Check the user on the MySQL server:**
   ```sql
   SELECT user, host FROM mysql.user;
   ```
   If you only see `expense | localhost`, the user can't log in from another server. Create/fix it for any host (`%`):
   ```sql
   CREATE USER IF NOT EXISTS 'expense'@'%' IDENTIFIED BY '<DB_PASSWORD>';
   ALTER USER 'expense'@'%' IDENTIFIED BY '<DB_PASSWORD>';
   GRANT ALL ON transactions.* TO 'expense'@'%';
   FLUSH PRIVILEGES;
   ```
6. **Check you entered the right password** in the service file. Correct `DB_USER` / `DB_PWD` (and check `DB_HOST`):
   ```bash
   vim /etc/systemd/system/backend.service
   systemctl show backend -p Environment     # what systemd actually loaded
   ```
7. **Reload, restart and watch the logs:**
   ```bash
   systemctl daemon-reload        # service file changed, so systemd must re-read it
   systemctl restart backend
   journalctl -u backend -f       # watch the logs
   ```
   > Forgetting `daemon-reload` is a very common reason a fixed password **still fails**. systemd keeps using the old values until you run it.
   >
   > `daemon-reload` is only needed for service files **you create or edit** (like `backend.service`). After installing MySQL, just `systemctl enable mysqld` + `systemctl start mysqld` is enough.
8. **Check the backend is really running** (service, process, port):
   ```bash
   systemctl status backend       # service → should say "active (running)"
   ps -ef | grep node             # process → node /app/index.js should be listed
   netstat -lntp | grep 8080      # port → 8080 should be in LISTEN state
   ```
9. **Check health again:**
   ```bash
   curl http://localhost:8080/health
   ```
   The response should no longer say `"db":"down"`. Then check the app in the browser. Success, error solved.

## Example: ERROR 2003 Can't Connect to MySQL (110)

Loading the schema from the backend server fails:

```bash
mysql -h <mysql-private-ip> -u root -p<DB_PASSWORD> < /app/schema/backend.sql
```
```text
ERROR 2003 (HY000): Can't connect to MySQL server on '<mysql-private-ip>:3306' (110)
```

**Meaning:** `(110)` = **connection timed out**. The backend never reached MySQL, so this is a **network** problem. The password isn't even checked yet.

1. **MySQL security group** (most common). Inbound rule must allow port `3306` from the backend:
   - Type `MYSQL/Aurora`, Port `3306`
   - Source: backend's security group ID, or backend private IP, or VPC CIDR (e.g. `172.31.0.0/16`)
2. **Right IP?** Must be the MySQL server's **private** IP (`hostname -I` on the DB server).
3. **MySQL running and listening?** On the DB server:
   ```bash
   systemctl status mysqld
   netstat -lntp | grep 3306
   ```
4. **Test the port** from the backend server:
   ```bash
   telnet <mysql-private-ip> 3306     # or: nc -zv <mysql-private-ip> 3306
   ```
   Hangs → security group or wrong IP.
5. Port reachable → load the schema again.

> Tip: use `-p` without the password so MySQL asks for it. A password on the command line shows up in history and screenshots.

## Example: "db":"down" with Empty Error

```bash
curl http://localhost:8080/health
```
```text
{"status":"degraded","db":"down","error":""}
```

**Meaning:** the backend app **is running** (it answered on 8080) but it **can't talk to the DB**.

1. **Network to DB.** Test from the backend server:
   ```bash
   mysql -h <mysql-private-ip> -u expense -p -e "show databases;"
   ```
   Timeout `(110)` → see [ERROR 2003](#example-error-2003-cant-connect-to-mysql-110).
2. **Service file values.** `DB_HOST` (MySQL **private** IP), `DB_USER`, `DB_PWD`, `DB_DATABASE=transactions`:
   ```bash
   cat /etc/systemd/system/backend.service
   systemctl show backend -p Environment
   ```
3. **Schema loaded?** If the schema load failed earlier, the `transactions` DB and `expense` user don't exist yet.
4. **Real error is in the logs** (the health output shows `error:""`):
   ```bash
   journalctl -u backend -n 50
   ```
5. Fix → `systemctl daemon-reload` → `systemctl restart backend` → `curl http://localhost:8080/health` again.

## Launched from an AMI? Old IPs Everywhere

If the server was created from a **recently used AMI** (or recreated), it gets a **new private IP**. But old IPs are still written in places:

| Where | Old IP problem | Fix |
|-------|----------------|-----|
| **MySQL security group inbound rule** | Rule allows `3306` from the **old backend IP**/32, so the new backend is blocked → `(110)` timeout | Edit inbound rules → put the **new** backend private IP |
| `/etc/systemd/system/backend.service` (copied by the AMI) | `DB_HOST` still points to the **old MySQL IP** | Update `DB_HOST` → `daemon-reload` → `restart backend` |
| `/etc/nginx/default.d/expense.conf` on frontend (copied by the AMI) | `proxy_pass` still points to the **old backend IP** → `504` | Update the IP → `nginx -t` → `restart nginx` |

- The AMI doesn't copy security group rules, but reusing the **same security group** keeps the old IP rule.
- **Better:** in the inbound rule, use the **backend's security group ID** (`sg-xxxx`) or the VPC CIDR as the source instead of a single IP. Then a new IP doesn't break anything.

```bash
hostname -I        # shows this server's current private IP
```

## Read the MySQL Error Code

| Error | Meaning | Look at |
|-------|---------|---------|
| `ERROR 2003 ... (110)` timed out | Can't reach the server at all | Security group 3306, private IP, old IP after AMI |
| `ERROR 2003 ... (111)` connection refused | Reached the server, MySQL not listening | `systemctl status mysqld`, `netstat -lntp \| grep 3306` |
| `Access denied ... (using password: YES)` | Reached MySQL, login refused | Password, `'expense'@'%'` user |
| `Access denied ... (using password: NO)` | Password empty / not loaded | `DB_PWD` in service file + `daemon-reload` |
| `Unknown database 'transactions'` | Login OK, schema not loaded | Load `backend.sql` |

## Quick Checklist

```text
1. tail -f /var/log/nginx/access.log      → which status code?
2. journalctl -u backend                   → what's the real error?
3. systemctl status backend                → running?
   ps -ef | grep node                      → process running?
   netstat -lntp | grep 8080               → port opened?
4. curl http://localhost:8080/health       → backend + DB ok?
5. Access denied? → mysql -h <mysql-private-ip> -u expense -p   → login works by hand?
                   → SELECT user, host FROM mysql.user;          → 'expense'@'%' exists?
6. Fix → systemctl daemon-reload (if service file changed) → systemctl restart backend
       → journalctl -u backend -f
       → systemctl status backend / ps -ef | grep node / netstat -lntp | grep 8080
       → curl http://localhost:8080/health ("db" not "down")
```
