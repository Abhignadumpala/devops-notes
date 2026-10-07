# Day 7 - Troubleshooting

[← Back to Day 7 notes](../README.md)

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

## Common Mistakes

| Problem | Fix |
|---------|-----|
| Backend fails to start after editing the service file | `systemctl daemon-reload` |
| Backend can't connect to DB | Wrong `DB_HOST` IP, or DB security group missing 3306 |
| Page loads but no data | Wrong backend IP in `expense.conf`, or backend SG missing 8080 |
| Nginx won't restart | Run `nginx -t` to find the config error |
| Used public IP between servers | Use **private** IPs |
| `nginx -t` → `host not found in upstream "<backend-private-ip>"` | Placeholder not replaced. Put the real backend private IP in `proxy_pass` |
| `curl localhost/api/health` → **404** even though `expense.conf` is correct | Nginx wasn't restarted. `systemctl restart nginx` and check again |
| Loaded the schema before the DB was set up → `Access denied for user 'expense'` | Set up DB first, then re-run the schema load on the backend. See [My Mistake](#my-mistake---loaded-the-schema-before-the-db-was-ready) |

## The Error Tells You the Layer

Run `curl http://localhost/api/health` on the frontend and read the result:

| You See | Problem Is At | Fix |
|---------|---------------|-----|
| **404 Not Found** (HTML page) | **Nginx** - no `/api/` rule loaded, so Nginx looks for a file `api/health` and doesn't find it | Check `/etc/nginx/default.d/expense.conf`, `nginx -t`, **restart nginx** |
| **502 Bad Gateway** | Backend app not running on 8080 | `systemctl status backend` on the backend |
| **504 Gateway Timeout** (after a delay) | Frontend → backend blocked, or wrong backend IP | `backend-sg` must allow 8080 from `frontend-sg` |
| `"db":"down"` | Backend → DB blocked, or wrong DB details | `mysql-sg` must allow 3306 from backend, check `DB_HOST` |
| `{"status":"ok"}` | Nothing - all working ✅ | |

> **Always restart after changing config.** Nginx reads its config only when it starts. Even if everything in `expense.conf` is written correctly, if you don't restart Nginx you'll still get **404 Page Not Found**. Restart and check again - the page works.
>
> ```bash
> nginx -t                  # check syntax first
> systemctl restart nginx   # load the new config
> curl http://localhost/api/health
> ```
>
> Same idea for the backend: after editing `backend.service` → `systemctl daemon-reload` + `systemctl restart backend`.

## My Mistake - Loaded the Schema Before the DB Was Ready

I set up the servers in the wrong order: **frontend → backend → DB**. The backend's schema step needs a working DB, so it broke. I've seen many people make the same mistake.

### Root Cause in Short

Found the root cause of the "db down" error 🎯

- The servers need to be set up in **reverse of the request flow**: **DB → Backend → Frontend**.
- I first did frontend → backend → DB. The problem: on the backend we run:
  ```bash
  mysql -h <db-ip> -u root -p<db-root-password> < /app/schema/backend.sql
  ```
- This loads the schema **into** the DB (the file lives on the backend in `/app/schema/`), but the DB wasn't set up yet - no MySQL running, no root password.
- So the schema never loaded → the `expense` DB user was never created → the backend showed `"db":"down"` / `Access denied for user 'expense'`.
- **Fix:** set up the DB (start `mysqld` + set the root password) → go back to the backend → run the schema load again → restart the backend. Works ✅ No need to rebuild anything.

Picture of the right vs wrong order: [Mental Model - Build in Reverse of the Request Flow](../README.md#mental-model---build-in-reverse-of-the-request-flow).

### What I did wrong

1. Set up the frontend fully (Nginx + `expense.conf`).
2. Set up the backend fully - including **Load Database Schema** - but the DB server wasn't set up yet.
3. Ran `mysql_secure_installation --set-root-pass ...` on the **backend** server by mistake. MySQL server isn't on the backend, so it did nothing.
4. Only then set up the DB server.

### What I saw

| Where | Command | Result | Meaning |
|---|---|---|---|
| Frontend | `curl http://localhost/api/health` | **5XX** "backend service is unavailable" | Nginx is fine, backend isn't answering |
| Frontend | `curl http://<backend-private-ip>:8080/health` | `Connection refused` | Nothing running on 8080 (a security group block would **time out** instead) |
| Frontend | `tail /var/log/nginx/error.log` | `connect() failed (111: Connection refused) while connecting to upstream` | Same - backend down |
| DB | `mysql -u root -p<password>` | `ERROR 1045 Access denied for user 'root'@'localhost'` | Root password was never set |
| DB | `mysql -u root` (no password) | Opened `mysql>` | Confirmed - root had **no** password |
| Backend | schema load (`mysql -h ... < backend.sql`) | `ERROR 2003 Can't connect to MySQL server ... (111)` | DB wasn't ready - schema **not loaded** |
| Backend | `curl http://localhost:8080/health` | `"db":"down"`, `Access denied for user 'expense'@...` | Backend reaches MySQL, but the `expense` user doesn't exist - the schema creates it |

### How I fixed it

1. **On the DB server** - set the root password (on the right server this time):
   ```bash
   systemctl status mysqld                               # must be running
   mysql_secure_installation --set-root-pass <db-root-password>
   mysql -u root -p<db-root-password> -e "SHOW DATABASES;"   # check it works
   ```
2. **Back on the backend** - load the schema again (now it creates the DB, table and `expense` user):
   ```bash
   mysql -h <mysql-private-ip> -u root -p<db-root-password> < /app/schema/backend.sql
   ```
   Only the "password on the command line" warning = success.
3. **Restart and check the backend:**
   ```bash
   systemctl daemon-reload
   systemctl restart backend
   curl http://localhost:8080/health      # {"status":"ok","db":"up"} ✅
   ```
4. **On the frontend:** `curl http://localhost/api/health` → `{"status":"ok","db":"up"}` ✅

### Lessons

- **Order matters: DB → backend → frontend.** Each tier needs the one after it to be ready.
- **Load the schema only after the DB is set up** (`mysqld` running + root password set).
- Run `mysql_secure_installation` **on the DB server**, not the backend. The backend only has the MySQL **client**.
- Check right after setting the password: `mysql -u root -p<password> -e "SELECT 1;"`.
- `Access denied for user 'expense'` = schema not loaded. `Access denied for user 'root'` = root password wrong / not set.
- `Connection refused` = nothing listening. `Timeout` = firewall / security group.
