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
8. [502 vs 503 vs 504: What to Check](#502-vs-503-vs-504-what-to-check)
9. [Security Groups: Allow Each Hop](#security-groups-allow-each-hop)
10. [Example: 504 After Fixing Only the DB Security Group](#example-504-after-fixing-only-the-db-security-group)
11. [Example: dnf install nginx → Port 443 Timed Out](#example-dnf-install-nginx--port-443-timed-out)
12. [Timeout vs Refused](#timeout-vs-refused)
13. [Quick Checklist](#quick-checklist)
14. [Example: Schema Loaded Before the DB Was Ready](#example-schema-loaded-before-the-db-was-ready)
15. [Example: root@localhost Has an Empty Password](#example-rootlocalhost-has-an-empty-password)

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
| `Access denied for user 'expense'` right after setup | `expense` user never created - schema load failed | [Schema loaded before the DB was ready](#example-schema-loaded-before-the-db-was-ready) |
| `Access denied for user 'root'@'localhost'` but remote root works | `root@localhost` has a different/empty password | [root@localhost empty](#example-rootlocalhost-has-an-empty-password) |

## 502 vs 503 vs 504: What to Check

All three are **5XX = server-side problem**, not the user's request. The usual place to look is the **backend**.

| Code | Name | Meaning | In our 3-tier app |
|------|------|---------|-------------------|
| **502** | Bad Gateway | Nginx reached for the backend and got **no valid reply**, often an immediate "connection refused" | **Backend app is down or crashed** |
| **503** | Service Unavailable | The server is up but **can't serve the request right now** | Backend is up but a dependency isn't ready. Usually the **DB is down**, or the server is overloaded / in maintenance |
| **504** | Gateway Timeout | Nginx waited for the backend and **got no reply in time** | Frontend → backend **blocked** (backend SG 8080, wrong IP) or backend **too slow** |

Easy way to remember:
- **502** → backend is **down**
- **503** → backend is up but **not ready** (often the DB)
- **504** → backend is **too slow, or blocked**

**Start the same way for every 5XX:**

```bash
# Frontend server - which code, and what does Nginx say?
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Backend server - is the app OK?
systemctl status backend
journalctl -u backend -n 50
curl http://localhost:8080/health
```

### 502 Bad Gateway → is the backend running?

On the **backend** server:

```bash
systemctl status backend          # "active (running)"? or failed / inactive
ps -ef | grep node                # node /app/index.js listed?
netstat -lntp | grep 8080         # port 8080 in LISTEN?
journalctl -u backend -n 50       # why did it stop / crash?
```

On the **frontend** server:

```bash
grep proxy_pass /etc/nginx/default.d/expense.conf    # right backend private IP and :8080?
tail -20 /var/log/nginx/error.log                    # "connect() failed (111: Connection refused)"
```

Fix:

```bash
systemctl daemon-reload           # only if backend.service was edited
systemctl restart backend
curl http://localhost:8080/health
```

### 503 Service Unavailable → is the DB OK?

On the **backend** server:

```bash
curl http://localhost:8080/health                    # {"status":"degraded","db":"down"} ?
journalctl -u backend -n 50                          # DB error: Access denied / ECONNREFUSED / timeout
systemctl show backend -p Environment                # DB_HOST, DB_USER, DB_PWD correct?
mysql -h <mysql-private-ip> -u expense -p -e "show databases;"   # can backend log in to DB?
```

On the **DB** server:

```bash
systemctl status mysqld           # MySQL running?
netstat -lntp | grep 3306         # MySQL listening on 3306?
systemctl start mysqld            # start it if stopped
```

Also check: **DB SG** allows **3306** from the backend private IP. For DB login errors, see [Access Denied](#example-500-error--access-denied-for-user-expense) and [ERROR 2003](#example-error-2003-cant-connect-to-mysql-110).

### 504 Gateway Timeout → can the frontend reach the backend?

On the **frontend** server:

```bash
curl http://<backend-private-ip>:8080/health         # hangs → blocked; JSON → reachable
grep proxy_pass /etc/nginx/default.d/expense.conf    # right backend private IP?
tail -20 /var/log/nginx/error.log                    # "upstream timed out (110: Connection timed out)"
```

On the **backend** server:

```bash
systemctl status backend
curl http://localhost:8080/health                    # fast reply? slow → backend itself is slow
```

In AWS:
- **Backend SG** → inbound **8080** from the frontend **private** IP (or frontend SG).

Fix the IP in `expense.conf` if needed:

```bash
vim /etc/nginx/default.d/expense.conf
nginx -t
systemctl restart nginx
```

### Summary: Error → Where → Commands

| Error | Check on | Commands |
|-------|----------|----------|
| **502** | Backend | `systemctl status backend`, `ps -ef \| grep node`, `netstat -lntp \| grep 8080`, `journalctl -u backend` |
| **503** | Backend + DB | `curl localhost:8080/health`, `journalctl -u backend`, `mysql -h <db-ip> -u expense -p`, `systemctl status mysqld` |
| **504** | Frontend → backend | `curl http://<backend-ip>:8080/health` (from frontend), `grep proxy_pass expense.conf`, **backend SG 8080** |

## Security Groups: Allow Each Hop

Check the flow **frontend → backend → DB**. Each server must allow the one **before** it:

```text
Users ─80─▶ Frontend (Nginx) ─8080─▶ Backend (Node.js) ─3306─▶ DB (MySQL)
```

| Security group | Inbound rule | Source |
|----------------|--------------|--------|
| **Frontend SG** | 80 (and 22 for SSH) | `0.0.0.0/0` (users) |
| **Backend SG** | **8080** | Frontend **private** IP (or frontend SG) |
| **DB SG** | **3306** | Backend **private** IP (or backend SG) |

- Use **private** IPs. Servers in the same VPC talk over private IPs, so a rule with a public IP won't match.
- **Test each hop** from the server one step before it. Whichever hop times out is the SG to fix:
  ```bash
  curl http://<backend-private-ip>:8080/health      # from frontend
  mysql -h <mysql-private-ip> -u expense -p          # from backend
  ```

**Inbound vs outbound:**

| Rule | Means | Example |
|------|-------|---------|
| **Inbound** | Others coming **in** to my server | SSH (22), users opening the site (80), frontend → backend (8080) |
| **Outbound** | My server going **out** | `dnf install`, `curl`, downloads. Keep **All traffic → `0.0.0.0/0`** (the default) |

- Security groups are **stateful**: if my server starts a connection going out, the reply coming back is allowed automatically. So downloading over HTTPS needs **outbound** 443, **not inbound** 443.
- Inbound 443 is only needed if my own website uses HTTPS.

## Example: 504 After Fixing Only the DB Security Group

Backend IP was added to the **DB SG**, but the app still shows **504 Gateway Timeout**.

**Meaning:** 504 comes from **Nginx**. It forwarded the request to the backend and got **no reply in time**. The problem is **frontend → backend**. The DB SG fix was needed too, but it fixes the next hop (backend → DB), not this one.

```text
Browser ──▶ Frontend (Nginx) ──✖──▶ Backend :8080 ──▶ DB :3306
                           waited, no reply → 504
```

1. **Backend SG** → inbound **8080** from the frontend's **private** IP (or frontend SG). Most likely fix.
2. **`proxy_pass`** in `/etc/nginx/default.d/expense.conf` → must have the correct backend **private** IP and `:8080` (old IP if the backend was recreated):
   ```bash
   cat /etc/nginx/default.d/expense.conf
   nginx -t
   systemctl restart nginx
   ```
3. **Test from the frontend server:**
   ```bash
   curl http://<backend-private-ip>:8080/health
   ```
   | Result | Meaning |
   |--------|---------|
   | Hangs, then times out | Backend SG 8080 or wrong IP |
   | `Connection refused` | Backend app not running → `systemctl status backend` |
   | `{"status":"ok","db":"up"}` | Fixed. Reload the app |

**The error tells you the hop:**

| Error | Problem between | Check |
|-------|-----------------|-------|
| **502** | Frontend → backend (backend **down**) | `systemctl status backend` |
| **503** | Backend up but **not ready** (often DB down) | DB server, `systemctl status mysqld` |
| **504** | Frontend → backend (**no reply / blocked**) | **Backend SG 8080**, `proxy_pass` IP |
| `"db":"down"` / `ERROR 2003` | Backend → DB | **DB SG 3306**, `DB_HOST` |

## Example: dnf install nginx → Port 443 Timed Out

On the frontend server:

```text
[root@ip-<frontend-private-ip> ~]# dnf install nginx -y
Errors during downloading metadata for repository 'epel':
  - Curl error (28): Timeout was reached for https://mirrors.fedoraproject.org/metalink?repo=epel-9...
    [Failed to connect to mirrors.fedoraproject.org port 443: Connection timed out]
Error: Failed to download metadata for repo 'epel'
```

**Meaning:** **443 = HTTPS**. `dnf` tried to download from the internet over HTTPS and got **no reply** (`Curl error (28)` = timeout). It's a **network** problem, not an nginx problem. Any `dnf install` would fail the same way.

**Cause:** the security group's **outbound rules** were edited by mistake, so the server can't go out to the internet.

1. **Test internet from the server:**
   ```bash
   curl -I https://google.com      # should return HTTP 200 / 301
   ```
2. **Fix:** EC2 → instance → Security → Security group → **Outbound rules** → Edit:
   ```text
   Type: All traffic   Destination: 0.0.0.0/0
   ```
   Opening **inbound** 443 does **not** fix this (stateful, see above).
3. Run `dnf install nginx -y` again. Fixed ✅
4. If outbound is fine and other sites work, only the EPEL mirror is down. nginx comes from the normal RHEL 9 repo, so skip EPEL:
   ```bash
   dnf install nginx -y --disablerepo=epel
   ```
5. Still failing? Check the subnet's route table has `0.0.0.0/0` → Internet Gateway, and the Network ACL allows traffic.

## Timeout vs Refused

| Result | What happened | Usual cause |
|--------|---------------|-------------|
| **Connection timed out** (`110`, curl `28`) | Request went out, **nothing came back** | Something is **blocking** it: security group, NACL, no internet route, wrong IP |
| **Connection refused** (`111`) | Reached the server, it said **"no"** right away | Server is up but nothing is **listening** on that port (service stopped) |

Timeout → think **network / SG**. Refused → think **service not running**.

| Port | Used for |
|------|----------|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MySQL |
| 8080 | Our backend (Node.js) |

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

## Example: Schema Loaded Before the DB Was Ready

From my [second run](../hands-on/README.md#4-problem-1---dbdown-because-i-set-up-in-the-wrong-order). I set up **frontend → backend → DB**.

**Symptoms, top to bottom:**

| Where | Command | Result | Means |
|---|---|---|---|
| Frontend | `curl http://localhost/api/health` | 5XX page | Nginx OK, backend not answering |
| Frontend | `curl http://<backend-private-ip>:8080/health` | `Connection refused` | Nothing on 8080 yet (an SG block would **time out**) |
| Frontend | `tail /var/log/nginx/error.log` | `connect() failed (111: Connection refused) while connecting to upstream` | Same - backend down |
| Backend | schema load | `ERROR 2003 ... (111)` | MySQL not running yet → schema **not loaded** |
| Backend | `curl http://localhost:8080/health` | `"db":"down"`, `Access denied for user 'expense'` | Backend reaches MySQL, but `expense` user doesn't exist |

**Root cause:** the schema load (`mysql -h <db-ip> -u root -p... < /app/schema/backend.sql`) runs on the backend but **creates** the DB, table and `expense` user **in** MySQL. The DB wasn't ready, so none of it was created.

**Fix:**

1. DB server: `systemctl start mysqld` + set the root password → check `mysql -u root -p<db-root-password> -e "SELECT 1;"`
2. Backend: run the schema load again → only the password warning = success
3. Backend: `systemctl restart backend` → `curl http://localhost:8080/health` → `{"status":"ok","db":"up"}`
4. Frontend: `curl http://localhost/api/health` → same ✅

**Prevent it:** build **DB → backend → frontend** and test each tier before moving up. Diagram: [Day 7 mental model](../../day-07-3tier-nodejs-expense-app/README.md#mental-model---build-in-reverse-of-the-request-flow).

## Example: root@localhost Has an Empty Password

From my [second run](../hands-on/README.md#6-problem-2---rootlocalhost-had-an-empty-password).

![MySQL account = user + host](../images/08-mysql-accounts-user-host.svg)

**Symptoms:**

| Where | Command | Result |
|---|---|---|
| Backend | `mysql -h <db-private-ip> -u root -p<db-root-password>` | ✅ works |
| DB server | `mysql -u root -p<db-root-password>` | ❌ `ERROR 1045 Access denied for user 'root'@'localhost' (using password: YES)` |
| DB server | `mysql_secure_installation --set-root-pass <db-root-password>` | `Password already set, You cannot reset the password with mysql_secure_installation` |

**Debug steps:**

1. **Did I type the wrong password?** → `history | grep -i "set-root-pass\|ALTER USER"` → same password both times. Not a typo.
2. **Is there a password at all?** → `mysql -u root -e "SELECT 1;"` with **no** password → it worked. Root on the DB server had **none**.
3. **Check every root account:**
   ```bash
   mysql -u root -e "SELECT user, host, IF(authentication_string='','EMPTY','set') AS pwd FROM mysql.user WHERE user='root';"
   ```
   ```text
   | root | %         | set   |   ← backend logs in with this one
   | root | localhost | EMPTY |   ← DB server logs in with this one
   ```

**Root cause:** a MySQL account is **user + host**. `root@localhost` and `root@%` are separate accounts. `set-root-pass` set only `root@%` and printed nothing. An account with **no** password rejects **any** password → Access denied.

**Fix** (on the DB server, no restart needed):

```bash
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '<db-root-password>';"
mysql -u root -p<db-root-password> -e "SHOW DATABASES;"    # transactions listed ✅
```

If you can't log in locally at all, log in as `root@%` instead (`mysql -h <db-private-ip> -u root -p...`, works from the DB server too) and run the same `ALTER USER`.

**Where passwords live:**

| Password | Real copy on | Set by |
|---|---|---|
| `root@localhost` | DB server, `mysql.user` table (hashed) | `mysql_secure_installation` / `ALTER USER` |
| `root@%` | DB server, `mysql.user` table | `mysql_secure_installation` / `ALTER USER` |
| `expense@%` (app) | DB server, `mysql.user` table | `backend.sql` (schema load from the backend) |
| Copy of `expense` password | Backend, `DB_PWD=` in `backend.service` | Me, when writing the file - must **match** the DB |

**Rules:**

- `set-root-pass` works only **once** (while root has no password). After that → `ALTER USER`.
- A password change in MySQL works **at once** - no restart. Changing `backend.service` needs `daemon-reload` + `restart backend`.
- Editing `DB_PWD` never changes a MySQL password - it only changes what the app sends.
- Always check right after setting a password: `mysql -u root -p<db-root-password> -e "SELECT 1;"`.

