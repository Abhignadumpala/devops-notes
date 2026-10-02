# Day 7 - Hands-On: Expense App Setup

[← Back to Day 7 notes](../README.md)

My actual run of the setup, with the mistakes I hit and how I fixed them.

## Backend

**1. Create `/app`, download the code and extract it**

![Download backend code](images/01-backend-download-code.png)

`/app` now has the code: `index.js`, `package.json`, `package-lock.json`, `node_modules/` and `schema/`.

**2. Write the service file, then check the schema file**

![Schema file](images/02-backend-schema-file.png)

![Schema folder](images/03-backend-schema-folder.png)

The schema is inside `/app/schema/backend.sql`, given by the developers with the code (password hidden here).

**3. Install the MySQL client on the backend**

![Install mysql client](images/04-backend-install-mysql-client.png)

Only the `mysql` client is installed here, not `mysql-server`.

**4. Load the schema, then start the backend**

![Load schema and start backend](images/05-backend-load-schema-start-service.png)

- `mysql -h <db-private-ip> -u root -p < ...` → asks for the **MySQL root password** (set on the DB server). No output = success.
- `daemon-reload` → `enable` → `start` → `status` shows **active (running)**.
- Log line: `Expense backend v3 listening on port 8080`.

**5. Verify the backend**

![Verify backend](images/06-backend-verify.png)

- `ps -ef | grep node` → process owner is **`expense`**, not root.
- `netstat -lntp` → `node` listening on **8080**.
- `curl http://localhost:8080/health` → `{"status":"ok"}`.

## Frontend

**6. Install Nginx**

![Install nginx](images/07-frontend-install-nginx.png)

**7. Mistake 1 - placeholder left in the config**

I copied the config but didn't replace `<backend-private-ip>`:

![Config with placeholder](images/08-frontend-expense-conf-placeholder.png)

`nginx -t` caught it:

![nginx -t failed](images/09-frontend-nginx-t-failed.png)

```
nginx: [emerg] host not found in upstream "<backend-private-ip>"
nginx: configuration file /etc/nginx/nginx.conf test failed
```

**Fix:** put the backend's real private IP in `proxy_pass`:

![Config fixed](images/10-frontend-expense-conf-fixed.png)

![nginx -t ok](images/11-frontend-nginx-t-ok.png)

**8. Mistake 2 - didn't restart Nginx (on purpose, to see the error)**

The config was correct and `nginx -t` passed, but I didn't restart Nginx. Calling the API still gave **404**:

![404 without restart](images/12-frontend-404-no-restart.png)

![404 page](images/13-frontend-404-page.png)

Nginx was still running with the **old** config, which has no `/api/` rule. So it looked for a file called `api/health` in `/usr/share/nginx/html` and returned 404.

**9. Restart Nginx → working**

![Restart and status ok](images/14-frontend-restart-status-ok.png)

After `systemctl restart nginx`, `curl http://localhost/api/health` → `{"status":"ok"}`. The request now goes frontend → Nginx → backend → DB. ✅

**Lesson:** a correct config file does nothing until Nginx is restarted. Error page "Not Found" right after a config change → restart first, then debug.
