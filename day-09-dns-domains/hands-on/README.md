# Day 9 - Hands-On: Expense App with DNS Names (Route 53) and a Load Balancer

[← Back to Day 9 notes](../README.md)

## Table of Contents

1. [Why use DNS names instead of IPs](#why-use-dns-names-instead-of-ips)
2. [Records to create in Route 53](#records-to-create-in-route-53)
3. [Backend: connect to MySQL by name](#backend-connect-to-mysql-by-name)
4. [Frontend: proxy to the backend by name](#frontend-proxy-to-the-backend-by-name)
5. [Second frontend (frontend-2)](#second-frontend-frontend-2)
6. [Load balancer](#load-balancer)
7. [3 load balancers in real projects](#3-load-balancers-in-real-projects)
8. [HTTPS with a TLS certificate](#https-with-a-tls-certificate)
9. [Summary](#summary)

---

## Why use DNS names instead of IPs

- When an EC2 instance is **stopped and started**, its IP can change.
- Before: the backend had the MySQL IP hard-coded, and Nginx had the backend IP. Every IP change meant editing the files and restarting the services - daily.
- Now: use a **DNS name** (e.g. `mysql.mydevops.store`). When the IP changes, update **only the Route 53 record**. No changes on the servers.

```text
Browser → mydevops.store (frontend) → backend.mydevops.store:8080 → mysql.mydevops.store:3306
```

## Records to create in Route 53

In the `mydevops.store` hosted zone, create these **A records** (built up step by step below):

| Record name | Full name | Value | Why this IP |
|-------------|-----------|-------|-------------|
| `mysql` | `mysql.mydevops.store` | `<mysql-private-ip>` | Only the backend talks to MySQL, inside the VPC |
| `backend` | `backend.mydevops.store` | `<backend-private-ip>` | Only Nginx (frontend) talks to the backend, inside the VPC |
| `frontend-1` | `frontend-1.mydevops.store` | `<frontend-1-private-ip>` | Only the LB talks to it |
| `frontend-2` | `frontend-2.mydevops.store` | `<frontend-2-private-ip>` | Only the LB talks to it |
| *(empty - root domain)* | `mydevops.store` | `<lb-public-ip>` | Users open it from the **internet** |

> Private IPs for servers that only talk to each other, public IP only for the server users open (the LB).

> Before the LB, the frontend had its own record with its **public** IP. Once the LB is in front, the frontend records use **private** IPs.

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

**5. Create the `frontend-1` record** in Route 53 → value `<frontend-1-private-ip>` (the LB will use it).

*(Before adding an LB, you can test with a temporary record pointing to the frontend's **public** IP.)*

## Second frontend (frontend-2)

1. Launch another EC2 named **frontend-2**, using the same AMI as the other servers.
2. Set it up exactly like frontend-1: install Nginx, deploy the frontend content, add `expense.conf` with `proxy_pass http://backend.mydevops.store:8080/` → [03-frontend.md](../../day-07-3tier-nodejs-expense-app/03-frontend.md).
3. In Route 53, create a record **`frontend-2`** → `<frontend-2-private-ip>`.

Now there are 2 identical frontends, both sending `/api/` to the same backend.

## Load balancer

The LB is also an **Nginx** server, but used differently: it serves no app files, it only spreads users across frontend-1 and frontend-2.

```text
User → LB (Nginx :80) → frontend-1 / frontend-2 (Nginx :80) → backend:8080 → MySQL:3306
```

**1. Create a security group for the LB:**

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | Anywhere (`0.0.0.0/0`) |
| HTTP | 80 | Anywhere (`0.0.0.0/0`) |

**2. Launch an EC2** named **loadbalancer** with the same AMI and the LB security group.

**3. Connect and install Nginx:**

```bash
dnf install nginx -y
```

**4. Remove the default config and add the LB config:**

The file to edit on the LB server is **`/etc/nginx/nginx.conf`** (the main Nginx config).

```bash
rm -f /etc/nginx/nginx.conf
vim /etc/nginx/nginx.conf          # paste lb.conf
```

Full config → [lb.conf](../../day-07-3tier-nodejs-expense-app/lb.conf). In the `upstream` block, use the **Route 53 names** of the frontends instead of IPs:

```nginx
upstream my_frontend_cluster {
    server frontend-1.mydevops.store:80;
    server frontend-2.mydevops.store:80;
}
```

**5. Check the records and the config, then restart:**

```bash
nslookup frontend-1.mydevops.store     # → frontend-1 private IP
nslookup frontend-2.mydevops.store     # → frontend-2 private IP
nginx -t
systemctl enable nginx
systemctl restart nginx
```

**6. Create the record for users** in Route 53: root domain `mydevops.store` → `<lb-public-ip>`.

**7. Open** `http://mydevops.store` → the Expense app loads through the LB.

All LB steps, status code demos and SG rules → [04-load-balancer.md](../../day-07-3tier-nodejs-expense-app/04-load-balancer.md).

## 3 load balancers in real projects

In real projects every tier gets its own LB, not just the frontend:

```text
Users → [Public LB] → frontend-1 / frontend-2
                          │
                     [Backend LB] → backend-1 / backend-2
                                         │
                                    [DB LB] → db-1 / db-2
```

| LB | Sits before | Public / private | Managed by |
|----|-------------|------------------|------------|
| Frontend LB | Frontend servers | **Public** - users reach it from the internet | Us (DevOps) |
| Backend LB | Backend servers | Private - only frontends talk to it | Us (DevOps) |
| DB LB | DB servers | Private - only backends talk to it | **DB team** |

- Only the frontend LB is public. The other two stay inside the VPC.
- Each tier can then have many servers. If one goes down, its LB sends traffic to the others.

## HTTPS with a TLS certificate

Right now the site is `http://` - traffic is **not encrypted**.

1. Get a **TLS certificate** for the domain (`mydevops.store`) - buy one, or get it from AWS (ACM) or Let's Encrypt.
2. Add it to the **public LB** (the one users hit).
3. The site becomes `https://mydevops.store` - traffic between the user and the LB is encrypted, and the browser shows the lock 🔒.

> TLS (Transport Layer Security) is the newer name for SSL. "SSL certificate" and "TLS certificate" mean the same thing day to day.

## Summary

| Server | What changed | Record used |
|--------|--------------|-------------|
| Backend | `DB_HOST` in `backend.service` | `mysql.mydevops.store` → MySQL private IP |
| Frontend-1, Frontend-2 | `proxy_pass` in `expense.conf` | `backend.mydevops.store` → backend private IP |
| Load balancer | `/etc/nginx/nginx.conf` replaced with `lb.conf` | `frontend-1` / `frontend-2.mydevops.store` → frontend private IPs |
| Users | Open the app by name | `mydevops.store` → LB public IP |

- IP changed? → update the **Route 53 record** only. No file edits.
- **Nginx catch:** Nginx looks up `backend.mydevops.store` only when it starts. Same on the LB for the frontend names. If an IP changes, run `systemctl reload nginx` so it picks up the new IP.
- Always check with `nslookup <name>` before using a name in a config.
- Keep the TTL low on these records so a new IP is picked up quickly.

