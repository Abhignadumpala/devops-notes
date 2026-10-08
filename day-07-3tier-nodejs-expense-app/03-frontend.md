# Frontend

## Server Login

| Item | Value |
|------|-------|
| Server name | `frontend` |
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`, us-east-1) |
| Username | `ec2-user` |
| Password | `DevOps321` |
| MySQL root password | `<db-root-password>` (user: `root`) |

```bash
ssh ec2-user@<frontend-public-ip>    # enter the password
sudo su -                         # become root
hostnamectl set-hostname frontend   # name the server, then: exec bash
```

The frontend serves static web content (HTML, CSS, JS) via Nginx. It also acts as a reverse proxy, forwarding `/api/` requests to the backend EC2 instance.

---

## Install Nginx

```bash
dnf install nginx -y
```

Enable and start:

```bash
systemctl enable nginx
systemctl start nginx
```

Verify the default Nginx page is accessible in the browser at `http://<FRONTEND-PUBLIC-IP>`.

---

## Deploy Frontend Content

**What we're doing here:** right after install, Nginx shows its own **default test page** from `/usr/share/nginx/html/`. We delete that default page and put **our own web app** (the expense app's HTML/CSS/JS) in the same folder, so Nginx serves our app instead.

```text
Before:  /usr/share/nginx/html/  →  default Nginx / Red Hat test page
After:   /usr/share/nginx/html/  →  our expense app (index.html, css, js ...)
```

**Step 1 - Remove the default Nginx content:**

```bash
rm -rf /usr/share/nginx/html/*
```

- Deletes everything **inside** the web folder (the folder itself stays).
- Without this, old default files stay mixed with our app, and the test page can keep showing up.

**Step 2 - Download our frontend package:**

```bash
curl -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-frontend-v5.tar.gz
```

- `curl -o <file> <url>` → downloads the URL and saves it as `<file>`.
- The app comes as a `.tar.gz` (a compressed bundle of all the HTML/CSS/JS files).
- We save it in `/tmp` - it's only needed until we extract it.

**Step 3 - Extract it into the Nginx web root:**

```bash
cd /usr/share/nginx/html
tar -xzf /tmp/frontend.tar.gz
```

- First `cd` into the web folder, so the files are extracted **right here** (no extra subfolder).
- `tar -xzf` → `x` extract, `z` it's gzip-compressed (`.gz`), `f` the file name follows.
- Now `index.html` sits directly in `/usr/share/nginx/html/`, so `http://<FRONTEND-PUBLIC-IP>/` opens our app.

```bash
ls /usr/share/nginx/html     # check: index.html and the app files should be here
```

---

## Configure Nginx Reverse Proxy

**What we're doing here:** the browser only talks to the frontend (Nginx). When the app needs data, it calls `/api/...`. We tell Nginx: "any request starting with `/api/` → forward it to the backend server on port 8080". This is the **reverse proxy** setup.

```text
Browser → http://<FRONTEND-PUBLIC-IP>/api/transaction
            → Nginx (frontend) → http://<BACKEND-PRIVATE-IP>:8080/transaction → Backend
```

### Where Nginx config lives

| Path | What it is |
|------|------------|
| `/etc/nginx/nginx.conf` | **Main** (default) Nginx config file |
| `/etc/nginx/default.d/*.conf` | Extra settings loaded **inside the default server** (port 80) - our reverse proxy goes here |
| `/etc/nginx/conf.d/*.conf` | Extra config files for whole new `server { }` blocks (e.g. another site/domain) |

The main `nginx.conf` already has these lines, which is how our file gets picked up automatically:

```nginx
http {
    include /etc/nginx/conf.d/*.conf;          # load every .conf in conf.d
    server {
        listen 80;
        root   /usr/share/nginx/html;
        include /etc/nginx/default.d/*.conf;   # load every .conf in default.d into this server
    }
}
```

**Why a separate file instead of editing `nginx.conf`?**

- It's **safe** - we don't touch the main default file, so the main setup doesn't get disturbed.
- If our config has a mistake, we only fix/delete our own small file.
- Easy to see what **we** added - everything for our app is in one file (`expense.conf`).
- Package updates can replace `nginx.conf`, but our file in `default.d/` stays.

> **Rule:** to add any reverse proxy (or other) settings, create a new `.conf` file in `/etc/nginx/default.d/` - don't edit `nginx.conf`.

### Create the config file

```bash
vim /etc/nginx/default.d/expense.conf
```

```nginx
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 5s;
proxy_read_timeout    30s;   # 504 if the backend takes longer than this

# Browser calls /api/transaction → nginx strips /api → backend gets /transaction
location /api/ {
    proxy_pass http://<BACKEND-PRIVATE-IP>:8080/;
}

location /health {
    stub_status on;
    access_log off;
}

# ── HTTP status code demos at the web-server layer ──────────────────────────
# 301 — page moved permanently
location = /home {
    return 301 /;
}

# 302 — temporary redirect to an external page
location = /docs {
    return 302 https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status;
}

# 403 — nobody is allowed here
location /admin {
    deny all;
}
```

> **Replace `<BACKEND-PRIVATE-IP>` with the private IP of the backend EC2 instance.**

**What each part does:**

| Part | Meaning |
|------|---------|
| `proxy_set_header ...` lines | Pass the real user's details (domain, IP, http/https) to the backend - otherwise the backend only sees Nginx's IP |
| `proxy_connect_timeout 5s` | Give up if the backend can't be connected within 5 seconds |
| `proxy_read_timeout 30s` | If the backend takes longer than 30s to answer → user gets **504** |
| `location /api/ { proxy_pass ... }` | **The main part** - forwards every `/api/...` request to the backend on port 8080 (the trailing `/` strips `/api`) |
| `location /health` | Shows Nginx's own status at `http://<FRONTEND-PUBLIC-IP>/health` |
| `/home`, `/docs`, `/admin` blocks | Only for demo of status codes `301`, `302` and `403` - not needed for the app |

Everything else (`/`, `/index.html`, css, js) is still served from `/usr/share/nginx/html/`.

### Check and apply

```bash
nginx -t                     # check the config syntax is correct
systemctl restart nginx      # restart so Nginx loads the new config
```

- `nginx -t` → must say `syntax is ok` and `test is successful`. If it shows an error, it tells the file and line number - fix it first.
- **Always run `nginx -t` before restarting** - if you restart with a broken config, Nginx won't start and the site goes down.
- Restart Nginx **after any config change** - Nginx reads config only when it starts.

---

## Verification

Open the browser at `http://<FRONTEND-PUBLIC-IP>` and confirm the Expense Tracker UI loads.

Test the reverse proxy is forwarding correctly:

```bash
curl http://localhost/api/health
```

You should get `{"status":"ok","db":"up"}` from the backend.

---

## Security Group

Ensure the frontend EC2 security group allows **inbound TCP on port 80** from the internet (0.0.0.0/0).  
Port 8080 on the backend must **not** be open to the internet — only to the frontend EC2's security group.
