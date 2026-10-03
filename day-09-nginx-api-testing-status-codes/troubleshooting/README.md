# Day 9 - Troubleshooting Step by Step

[← Back to Day 9 notes](../README.md)

## Table of Contents

1. [Rule: Check the Logs First](#rule-check-the-logs-first)
2. [Step-by-Step Approach](#step-by-step-approach)
3. [Example: 500 Error → Access Denied for User 'expense'](#example-500-error--access-denied-for-user-expense)
4. [Quick Checklist](#quick-checklist)

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
3. **Meaning:** the backend can't log in to MySQL. The DB **credentials are wrong** (user or password).
4. **Fix:** correct `DB_USER` / `DB_PWD` (and check `DB_HOST`) in the service file:
   ```bash
   vim /etc/systemd/system/backend.service
   ```
5. Reload and restart:
   ```bash
   systemctl daemon-reload        # service file changed, so systemd must re-read it
   systemctl restart backend
   ```
6. Check again with `curl http://localhost:8080/health` and the app. Success, error solved.

## Quick Checklist

```text
1. tail -f /var/log/nginx/access.log      → which status code?
2. journalctl -u backend                   → what's the real error?
3. systemctl status backend                → running?
   ps -ef | grep node                      → process running?
   netstat -lntp | grep 8080               → port opened?
4. curl http://localhost:8080/health       → backend + DB ok?
5. Fix → systemctl daemon-reload (if service file changed) → systemctl restart backend
```
