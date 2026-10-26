# 10-frontend.sh: Frontend Server (Nginx)

[← Day 16 notes](../README.md) · [Common part of every script](../00-common-part.md)

## What this server does

**Frontend** is the only server users reach from the internet. **Nginx** does 2 jobs:
1. Serves the **web pages** (React files in `/usr/share/nginx/html`).
2. **Reverse proxy**: forwards every `/api/<service>/` call to the right backend.

| Fact | Value |
|------|-------|
| Server | `roboshop-frontend` (RHEL 9) |
| Software | Nginx 1.26 |
| Port | 80 |
| Called by | the browser (internet) |
| Calls | catalogue, user, cart, shipping, payment (all on 8080) |
| SG inbound | 80 from anywhere (`0.0.0.0/0`) |
| Other SGs must allow | 8080 from `roboshop-frontend` on all 5 app servers |
| DNS | `abhignadevops.store` → frontend **public** IP (the only public record) |
| Config file I add | `/etc/nginx/default.d/roboshop.conf` |
| Files used | `10-frontend.sh`, `roboshop.conf` |
| Result | shop opens at `http://abhignadevops.store`, all 5 `/api/*/health` = 200, 3 orders placed |

```
Browser ── http://abhignadevops.store ──► FRONTEND (nginx :80)
                                            ├─ /api/catalogue/ ──► catalogue:8080
                                            ├─ /api/user/      ──► user:8080
                                            ├─ /api/cart/      ──► cart:8080
                                            ├─ /api/shipping/  ──► shipping:8080
                                            ├─ /api/payment/   ──► payment:8080
                                            └─ everything else ──► files in /usr/share/nginx/html
```

---

## "Frontend has no .service file?" It does: nginx brings its own

| | App servers (catalogue ... payment) | Frontend |
|---|---|---|
| What runs | **my** app code (`node`, `java`, `gunicorn`) | **Nginx**, a ready-made web server |
| `.service` file | I write it (`payment.service`) | comes with the package: `dnf install nginx` → `/usr/lib/systemd/system/nginx.service` |
| Config I write | `.service` with `Environment=` lines | **`roboshop.conf`**: where to send each request |

## How frontend talks to the others: 3 layers

A security group alone is not enough. Every request needs all 3:

| Layer | Answers | Example |
|-------|---------|---------|
| 1. **Nginx config** (`roboshop.conf`) | **Where** do I send it? | `/api/catalogue/` → `catalogue.abhignadevops.store:8080` |
| 2. **DNS** (Route 53) | What **IP** is that name? | `catalogue.abhignadevops.store` → `172.31.9.48` |
| 3. **Security group** | Is it **allowed in**? | `roboshop-catalogue`: 8080 from `roboshop-frontend` |

---

## Steps the script does

1. Common part: root check, log file, `timestamp`, `validate`
2. Install **Nginx 1.26**, enable + start it
3. Delete nginx's default web page
4. Download + unzip the RoboShop web pages
5. Copy `roboshop.conf` and put in my domain
6. **Test** the config (`nginx -t`)
7. Restart nginx

---

## The code, block by block

### 1. The common part

Same as every script: [00-common-part.md](../00-common-part.md).

### 2. Install Nginx 1.26

```bash
dnf module disable nginx -y &>>$logs_file
dnf module enable nginx:1.26 -y &>>$logs_file
dnf install nginx -y &>>$logs_file
validate $? "Installing nginx"

systemctl enable nginx &>>$logs_file
systemctl start nginx &>>$logs_file
validate $? "Enable and start nginx"
```

**`dnf module`** = pick a version stream. `disable` clears the default, `enable nginx:1.26` picks 1.26, then `install` gets that version. Same idea as Redis 7 and Node.js 24.

### 3. Remove the default page + put in RoboShop

```bash
rm -rf /usr/share/nginx/html/* &>>$logs_file
validate $? "Removing default nginx content"

curl -L -o /tmp/frontend.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip &>>$logs_file
cd /usr/share/nginx/html &>> $logs_file
unzip /tmp/frontend.zip &>> $logs_file
validate $? "Downloading and unzipping frontend code"
```

**What it does:** `/usr/share/nginx/html` is nginx's web folder (`root` in `nginx.conf`). Delete the "Welcome to nginx" page, unzip the shop's files (`index.html`, `assets/`, `images/`) there.

**Why `rm -rf` first:** on a re-run, `unzip` would ask "replace?" and hang (same as `/app` in the app scripts).

> 💡 One `validate` checks 3 commands: only `unzip`'s exit code counts. If `curl` fails, I only find out at `unzip`. Optional: add `validate $?` after `curl`.

### 4. Copy roboshop.conf, then put in my domain

```bash
cp "$scripts_dir/roboshop.conf" /etc/nginx/default.d/roboshop.conf
validate $? "Copied roboshop config"

sed -i "s/DOMAIN_NAME/$domain_name/g" /etc/nginx/default.d/roboshop.conf
validate $? "Updating domain name in roboshop config"
```

**Why `/etc/nginx/default.d/`:** RHEL's `nginx.conf` has `include /etc/nginx/default.d/*.conf;` **inside** its default `server { listen 80; }` block. A file dropped there becomes part of that server, so no `server {}` of my own is needed.

**Why `cp` first, then `sed` the copy:** I first wrote it the other way round (sed the repo file, then cp). Same result in nginx, but:

| | `sed` repo file → `cp` | `cp` → `sed` the copy ✅ |
|---|---|---|
| Repo file after the run | changed (`DOMAIN_NAME` gone) | stays `DOMAIN_NAME` |
| `git status` on the server | `modified: roboshop.conf` | clean |
| Next `git pull` | **refused**: *"Your local changes would be overwritten"* | works |

> **Rule:** never edit the template. Copy it, then edit the copy.

### 5. Test the config, then restart

```bash
nginx -t &>> $logs_file
validate $? "Nginx Configuration"

systemctl restart nginx
validate $? "Restarting nginx"
```

**`nginx -t`** = check the config **without** applying it. A typo, a missing `;` or an unknown DNS name → FAILED, and the script stops **before** the restart, so the running site isn't broken.

> ⚠️ Nginx looks up every `proxy_pass` hostname at start. If one DNS record is missing → `host not found in upstream` → `nginx -t` fails. That's why frontend goes **last**, after all app servers + DNS records exist.

---

## roboshop.conf, block by block

### Security headers + compression

```nginx
server_tokens off;
add_header X-Request-Id $request_id always;
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options SAMEORIGIN always;
add_header Referrer-Policy strict-origin-when-cross-origin always;

gzip on;
gzip_types text/css application/javascript application/json image/svg+xml;
gzip_min_length 1024;
```

| Line | Meaning |
|------|---------|
| `server_tokens off` | hide the nginx version in errors and headers |
| `X-Request-Id $request_id` | a unique ID per request, sent to the backends and back to the browser: one click can be traced on every server |
| `X-Content-Type-Options nosniff` | browser must trust the file type nginx says (blocks MIME tricks) |
| `X-Frame-Options SAMEORIGIN` | other sites can't put my shop in an `<iframe>` (blocks clickjacking) |
| `gzip on` + types | compress CSS / JS / JSON bigger than 1 KB → faster pages |

### Settings for every backend call

```nginx
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Request-Id      $request_id;
proxy_hide_header X-Request-Id;
proxy_connect_timeout 5s;
proxy_read_timeout    30s;
```

| Line | Meaning |
|------|---------|
| `X-Real-IP` / `X-Forwarded-For` | tell the backend the **real** visitor IP (otherwise it only sees the frontend's IP) |
| `proxy_hide_header X-Request-Id` | the backend sends the ID back too; hide theirs, nginx already adds it |
| `proxy_connect_timeout 5s` | can't connect in 5 s → give up (502) |
| `proxy_read_timeout 30s` | backend takes longer than 30 s → 504 |

### The reverse proxy (the core)

```nginx
location /api/catalogue/ { proxy_pass http://catalogue.DOMAIN_NAME:8080/; }
location /api/user/      { proxy_pass http://user.DOMAIN_NAME:8080/; }
location /api/cart/      { proxy_pass http://cart.DOMAIN_NAME:8080/; }
location /api/shipping/  { proxy_pass http://shipping.DOMAIN_NAME:8080/; }
location /api/payment/   { proxy_pass http://payment.DOMAIN_NAME:8080/; }
```

**The trailing `/` matters:**
```
/api/catalogue/products ── proxy_pass ...:8080/  ──► /products                 ✅ prefix removed
/api/catalogue/products ── proxy_pass ...:8080   ──► /api/catalogue/products   ❌ app returns 404
```

### Clean JSON errors when a backend is down

```nginx
error_page 502 = @bad_gateway;
error_page 504 = @gateway_timeout;
location @bad_gateway {
    default_type application/json;
    return 502 '{"message":"service not reachable (502 Bad Gateway from nginx)"}';
}
location @gateway_timeout { ... return 504 '{"message":"service did not answer in time ..."}'; }
```

| Code | Means | Typical cause |
|------|-------|---------------|
| **502** | nginx couldn't reach the backend | service stopped, SG blocks 8080, wrong port |
| **504** | backend didn't answer in 30 s | backend stuck / overloaded |

Errors the backend returns itself (its own 404, 503...) pass through unchanged. `@name` = a named location, only used internally.

### Nginx health, images, assets, React pages

```nginx
location = /health { stub_status on; access_log off; }
location /images/  { expires 1h;  try_files $uri /images/placeholder.jpg; }
location /assets/  { expires max; try_files $uri =404; }
location /         { expires -1;  try_files $uri $uri/ /index.html; }
```

| Block | Meaning |
|-------|---------|
| `= /health` + `stub_status` | nginx's own counters (`Active connections: ...`). `=` = exact match only |
| `/images/` | product pictures, cached 1 h; missing one → placeholder |
| `/assets/` | JS/CSS with a content hash in the name → cache forever (`expires max`) |
| `/` + `try_files ... /index.html` | React decides pages like `/cart` in the browser, so any unknown path gets `index.html` (a refresh on `/account` still works) |

---

## How I ran it

```bash
# laptop: both servers in one command (roboshop.sh loops over $@)
bash roboshop.sh dispatch frontend
```
```
Creating instance: dispatch
dispatch IP: 172.31.11.148
DNS updated: dispatch.abhignadevops.store -> 172.31.11.148
Creating instance: frontend
frontend IP: 3.239.40.121
DNS updated: abhignadevops.store -> 3.239.40.121
```
Frontend gets the **public** IP and the root domain (`if [ $instance != "frontend" ]` in `roboshop.sh`).

```bash
git add 10-frontend.sh roboshop.conf
git commit -m "Add: frontend script and nginx reverse proxy config"
git push

# frontend server
ssh ec2-user@<frontend-public-ip>
sudo su -
dnf install git -y
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v1.git
cd shellscript-roboshop-v1
bash 10-frontend.sh
```

## Result: checked from my laptop, through the internet

| URL | Answer |
|-----|--------|
| `http://abhignadevops.store/` | `200`, the shop page |
| `/health` (nginx) | `200` `Active connections: 1 ...` |
| `/api/catalogue/health` | `200` `{"app":"OK","mongo":true}` |
| `/api/user/health` | `200` `{"app":"OK","mongo":true,"redis":true}` |
| `/api/cart/health` | `200` `{"app":"OK","redis":true}` |
| `/api/shipping/health` | `200` `OK` |
| `/api/payment/health` | `200` `{"app":"OK","rabbitmq":true}` |

Response headers show `roboshop.conf` is live: `Server: nginx` (no version), `X-Request-Id: 13a99dcf...`, `X-Frame-Options: SAMEORIGIN`.

**End to end:** registered, logged in, added to cart, checked out, paid. **3 orders** in Order history (2:30:44 PM, 2:31:18 PM, 3:00:15 PM). One order touches frontend → catalogue → mongodb, user → mongodb + redis, cart → redis, shipping → mysql, payment → rabbitmq.

## Verify

```bash
systemctl status nginx --no-pager                    # active (running)
nginx -t                                             # syntax is ok / test is successful
grep proxy_pass /etc/nginx/default.d/roboshop.conf   # real domain, no DOMAIN_NAME
curl -s localhost/api/catalogue/health               # through nginx to catalogue
tail -f /var/log/nginx/access.log                    # every request
tail -f /var/log/nginx/error.log                     # 502s: "connect() failed ... upstream"
```

---

## Problems I hit

| Problem | Cause | Fix |
|---------|-------|-----|
| "No service file for frontend?" | Nginx isn't my code | `nginx.service` comes with the package; I write `roboshop.conf` instead |
| `roboshop.conf` missing from the repo | Wrote the script first | Wrote it next to the script, pushed both (else `cp` → FAILED) |
| `sed` on the repo file, then `cp` | Edits a tracked file → later `git pull` refuses | `cp` first, `sed` the copy |
| Frontend's DNS goes stale after a stop/start | Its **public** IP changes; the A record keeps the old one | Re-run the Route 53 UPSERT after every start (or an Elastic IP) |

---

## Interview questions

**1. What is a reverse proxy?**
A server in front of the backends. The browser only talks to nginx; nginx forwards `/api/<service>/` to the right backend with `proxy_pass`. Backends stay private.

**2. Why does `proxy_pass` end with `/`?**
It removes the matched prefix: `/api/catalogue/products` → `/products`. Without it the backend gets `/api/catalogue/products` and returns 404.

**3. 502 vs 504?**
502 = nginx couldn't reach the backend (down, SG, wrong port). 504 = it connected, but no answer in time.

**4. Why `nginx -t` before restart?**
It tests the config without applying it. A bad config fails the script before the restart, so the live site keeps running.

**5. Why is frontend set up last?**
Nginx resolves every `proxy_pass` hostname at start. If a backend's DNS record is missing, nginx won't start. And the shop needs all backends to work.

**6. Frontend has no `.service` file. How is it managed?**
`dnf install nginx` installs `nginx.service`. I only add config (`roboshop.conf`) and use `systemctl enable/restart nginx`.

**7. Why is frontend the only server with a public DNS record?**
It's the only entry point from the internet. All other records point to private IPs, and their SGs only allow other RoboShop SGs.
