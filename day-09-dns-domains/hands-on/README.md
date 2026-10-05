# Day 9 - Hands-On: Expense App with DNS Names (Route 53)

[← Back to Day 9 notes](../README.md)

## Table of Contents

1. [Why use DNS names instead of IPs](#why-use-dns-names-instead-of-ips)
2. [Records to create in Route 53](#records-to-create-in-route-53)
3. [Backend: connect to MySQL by name](#backend-connect-to-mysql-by-name)
4. [Frontend: proxy to the backend by name](#frontend-proxy-to-the-backend-by-name)
5. [Summary](#summary)

---

## Why use DNS names instead of IPs

- When an EC2 instance is **stopped and started**, its IP can change.
- Before: the backend had the MySQL IP hard-coded, and Nginx had the backend IP. Every IP change meant editing the files and restarting the services - daily.
- Now: use a **DNS name** (e.g. `mysql.mydevops.store`). When the IP changes, update **only the Route 53 record**. No changes on the servers.

```text
Browser → mydevops.store (frontend) → backend.mydevops.store:8080 → mysql.mydevops.store:3306
```

## Records to create in Route 53

In the `mydevops.store` hosted zone, create 3 **A records**:

| Record name | Full name | Value | Why this IP |
|-------------|-----------|-------|-------------|
| `mysql` | `mysql.mydevops.store` | `<mysql-private-ip>` | Only the backend talks to MySQL, inside the VPC |
| `backend` | `backend.mydevops.store` | `<backend-private-ip>` | Only Nginx (frontend) talks to the backend, inside the VPC |
| `frontend` | `frontend.mydevops.store` | `<frontend-public-ip>` | Users open it from the **internet** |

> Private IPs for servers that only talk to each other, public IP only for the server users open.

## Backend: connect to MySQL by name

**1. Create the `mysql` record** in Route 53 → value `<mysql-private-ip>`.

**2. Check it resolves** (on the backend server):

```bash
nslookup mysql.mydevops.store      # should show <mysql-private-ip>
```

> If `nslookup` isn't found: `dnf install bind-utils -y`

**3. Change `DB_HOST` to the DNS name** in the service file:

```bash
vim /etc/systemd/system/backend.service
```

```ini
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=mysql.mydevops.store
Environment=DB_USER=expense
Environment=DB_PWD=<db-password>
Environment=DB_DATABASE=transactions
Environment=ADMIN_TOKEN=<admin-token>
ExecStart=/bin/node /app/index.js
SyslogIdentifier=backend
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Only one line changed: `DB_HOST=<mysql-private-ip>` → `DB_HOST=mysql.mydevops.store`.

**4. Load the schema** using the DNS name:

```bash
mysql -h mysql.mydevops.store -u root -p < /app/schema/backend.sql
```

**5. Reload and restart:**

```bash
systemctl daemon-reload            # service file changed
systemctl restart backend
systemctl status backend           # active (running)
curl http://localhost:8080/health
```

## Frontend: proxy to the backend by name

**1. Create the `backend` record** in Route 53 → value `<backend-private-ip>`.

**2. Check it resolves** (on the frontend server):

```bash
nslookup backend.mydevops.store    # should show <backend-private-ip>
```

**3. Change `proxy_pass` to the DNS name** (after Nginx is installed as usual):

```bash
vim /etc/nginx/default.d/expense.conf
```

```nginx
# Browser calls /api/transaction → nginx strips /api → backend gets /transaction
location /api/ {
    proxy_pass http://backend.mydevops.store:8080/;
}
```

Only this line changed: `http://<backend-private-ip>:8080/` → `http://backend.mydevops.store:8080/`. The rest of `expense.conf` stays the same.

**4. Test and restart Nginx:**

```bash
nginx -t
systemctl restart nginx
```

**5. Create the `frontend` record** in Route 53 → value `<frontend-public-ip>` (for internet users).

Now open `http://frontend.mydevops.store` in the browser.

## Summary

| Server | What changed | Record used |
|--------|--------------|-------------|
| Backend | `DB_HOST` in `backend.service` | `mysql.mydevops.store` → MySQL private IP |
| Frontend | `proxy_pass` in `expense.conf` | `backend.mydevops.store` → backend private IP |
| Users | Open the app by name | `frontend.mydevops.store` → frontend public IP |

- IP changed? → update the **Route 53 record** only. No file edits.
- **Nginx catch:** Nginx looks up `backend.mydevops.store` only when it starts. If the backend IP changes, run `systemctl reload nginx` so it picks up the new IP.
- Always check with `nslookup <name>` before using a name in a config.
- Keep the TTL low on these records so a new IP is picked up quickly.

Next: load balancer.
