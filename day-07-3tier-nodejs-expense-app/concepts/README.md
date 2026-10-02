# Day 7 - Concepts Learned

[← Back to Day 7 notes](../README.md)

## Table of Contents

1. [1. System User](#1-system-user)
2. [2. Build Tools](#2-build-tools)
3. [3. Systemd Service Files](#3-systemd-service-files)
4. [4. Server vs Client Packages](#4-server-vs-client-packages)
5. [5. Public IP vs Private IP](#5-public-ip-vs-private-ip)
6. [6. Reverse Proxy](#6-reverse-proxy)
7. [7. Nginx](#7-nginx)
8. [8. Nginx as a Load Balancer](#8-nginx-as-a-load-balancer)
9. [9. REST API & HTTP Methods](#9-rest-api--http-methods)
10. [10. HTTP Status Codes](#10-http-status-codes)

---

## 1. System User

- **Human user** → for people, logs in with username/password or key, has a shell.
- **System user** → for apps/services, no login, no credentials, no shell.
- Running apps as a human/root user means more privileges, bigger blast radius, files under a person's name, breaks when the person resigns, and poor auditing.
- So we run apps as a system user → smaller blast radius and least privilege.

Full explanation → [Part 2, Step 2](../README.md#2-create-a-system-user).

## 2. Build Tools

Developers write a lot of files. Before the app can run, the same steps have to be repeated every time. A **build tool** automates them.

**What a build tool does:**

1. **Installs dependencies** (libraries the code needs).
2. **Automates repeating steps**: clean old output → download new code → compile the code → install dependencies → create the application.
3. **Gives a standard project structure**, so every project is organised the same way.
4. **Runs test cases** automatically and **creates the artifact**, the packaged app (`.zip`, `.tar.gz`, `.jar`, `.war`, `.ear`).

A **build file** holds info about the application: name, description, version, dependencies, and how to start it.

| Language | Build Tool | Build File | Code Extension |
|----------|------------|------------|----------------|
| Java | Maven | `pom.xml` | `.java` |
| Node.js | npm | `package.json` | `.js` |
| Python | pip | `requirements.txt` | `.py` |

In this project: Node.js 24, `npm`, `package.json`, dependencies in `node_modules/`, exact versions in `package-lock.json`.

## 3. Systemd Service Files

### Package vs Service

- **Package** → the app's compiled code that we download and store on the server. It just sits on disk. Example: `dnf install nginx -y` downloads the Nginx package.
- **Service** → when that package is **running** in the background, it's called a service. Example: `systemctl start nginx` → Nginx is now a running service.

| | Package | Service |
|---|---------|---------|
| What it is | Code/files stored on disk | The app running in the background |
| How we get it | `dnf install nginx -y` | `systemctl start nginx` |
| Doing work? | No, just stored | Yes, serving requests |
| Our backend | Code in `/app` | Running via `backend.service` |

Nginx and MySQL come with service files, so `systemctl start nginx` just works. Our backend is **custom code** - we write `/etc/systemd/system/backend.service` to tell Linux:
- **Who** runs it (`User=`)
- **How** to run it (`ExecStart=`)
- **What settings** it needs (`Environment=`)

A service file answers 3 questions:
1. **Who** has to run this application?
2. **How** to run the application?
3. Does the application need any **environment** (DB URL, credentials, etc.)?

What happens on `systemctl start backend`:
1. Goes to `/etc/systemd/system`
2. Searches for `backend.service`
3. Runs the start command (`ExecStart`) and injects the environment
4. Uses the `User` info to decide who runs the service

### systemctl Commands

Works the same for packages (`nginx`) and our custom service (`backend`):

```bash
systemctl start backend      # start now
systemctl stop backend       # stop
systemctl restart backend    # stop + start
systemctl status backend     # is it running?
systemctl enable backend     # start automatically on boot
systemctl disable backend    # don't start on boot
```

Example with a package: `dnf install nginx -y` → `systemctl start nginx` works straight away, because the package brings its own service file. Our backend is a customised application developed by us, so it can't start through systemctl until we write its service file.

## 4. Server vs Client Packages

| | Server | Client |
|---|--------|--------|
| Web | facebook.com | Chrome |
| MySQL | `mysql-server` (DB server) | `mysql` (backend server) |

## 5. Public IP vs Private IP

| | Public IP | Private IP |
|---|-----------|------------|
| Reachable from | Internet | Only inside the network |
| Example | `106.205.31.68` | `192.168.1.13`, `172.31.x.x` |
| Changes on EC2 stop/start | Yes | No |
| Use for | Users, SSH from laptop | Server-to-server |

**IPv4** = 2^32 ≈ 4 billion addresses - not enough for every device, so private IPs are reused inside networks.

## 6. Reverse Proxy

Nginx on the frontend forwards `/api/` requests to the backend. The user never talks to the backend directly, so the backend stays private.

### Forward Proxy vs Reverse Proxy

Both stand "in the middle", but on opposite sides:

| | Forward Proxy | Reverse Proxy |
|---|---------------|---------------|
| Works for | The **client** | The **server** |
| Hides | Client's identity from the server | Server's identity from the client |
| Examples | VPN, changing location, office internet filtering | SSL termination, caching, load balancing, our Nginx `/api/` |

Our frontend Nginx is a **reverse proxy** - the browser only ever talks to Nginx, never to the backend.

### Why the `X-Forwarded-*` Headers?

After Nginx forwards a request, the backend sees **every request coming from Nginx's IP**, not the real user. These headers carry the original details along:

| Header | Carries |
|--------|---------|
| `X-Real-IP` | The real client IP |
| `X-Forwarded-For` | The client IP plus every proxy it passed through |
| `X-Forwarded-Proto` | Whether the user came on `http` or `https` |
| `Host` | The domain/IP the user typed |

So the backend logs still show **who** made the request.

## 7. Nginx

Nginx is more than a web server. It can be:

- **HTTP server** - serves HTML/CSS/JS
- **Reverse proxy** - forwards requests to the backend (what we did)
- **Load balancer** - spreads requests across many servers
- **SSL/TLS termination** - handles HTTPS so the servers behind it don't have to
- **Cache** - stores responses to answer faster

Newer backend frameworks (like our Node.js app) come with their **own built-in server**, so a separate heavy app server isn't needed - Nginx just sits in front.

### Important Paths

| Path | What |
|------|------|
| `/usr/share/nginx/html/` | Default folder for web files (`index.html`) |
| `/etc/nginx/nginx.conf` | Main config file |
| `/etc/nginx/default.d/*.conf` | Extra config loaded into the default server (our `expense.conf`) |
| `/var/log/nginx/access.log` | Every request |
| `/var/log/nginx/error.log` | Errors |

### Ports and Domains

- HTTP = port **80**, HTTPS = port **443** - the browser adds them automatically.
- Any other port must be typed in the URL, e.g. `http://<public-ip>:81`.
- A **domain name** is just an easy name for the same public IP - `http://mydomain.com` and `http://<frontend-public-ip>` reach the same server.

### Reading an Access Log Line

```text
203.0.113.42 - - [30/Sep/2026:02:24:50 +0000] "GET / HTTP/1.1" 200 9466 "-" "Mozilla/5.0 ..."
```

| Part | Meaning |
|------|---------|
| `203.0.113.42` | Client IP |
| `[30/Sep/2026:02:24:50 +0000]` | Time |
| `"GET / HTTP/1.1"` | Method + path |
| `200` | Status code |
| `9466` | Response size (bytes) |
| `"Mozilla/5.0 ..."` | Browser (user agent) |

```bash
tail -f /var/log/nginx/access.log     # watch requests live
```

## 8. Nginx as a Load Balancer

In our setup Nginx serves the frontend **and** proxies to one backend. Nginx can also run on its **own server** just to balance traffic across many identical servers:

```text
        Internet
           │
           ▼
   ┌───────────────────┐
   │ Load Balancer EC2 │  ← Nginx only, no app code
   └───────────────────┘
       │           │
       ▼           ▼
 Frontend-1    Frontend-2     ← same app on both
```

```nginx
upstream app_servers {
    server <frontend-1-private-ip>:80;
    server <frontend-2-private-ip>:80;
}

server {
    listen 80;
    location / {
        proxy_pass http://app_servers;
    }
}
```

- `upstream` = a named group of servers.
- By default Nginx uses **round-robin** - request 1 → server 1, request 2 → server 2, then back to server 1.
- If one server goes down or is replaced, users don't notice - the others keep serving. This is how "add more servers" actually works.

## 9. REST API & HTTP Methods

An **API** is how the frontend talks to the backend. A **REST API** maps CRUD to HTTP methods, with the resource in the URL:

| Operation | Method | Example |
|-----------|--------|---------|
| Read all | `GET` | `GET /transaction` |
| Read one | `GET` | `GET /transaction/2` |
| Create | `POST` | `POST /transaction` + JSON body |
| Update | `PUT` | `PUT /transaction` + JSON body with `id` |
| Delete one | `DELETE` | `DELETE /transaction/4` |
| Delete all | `DELETE` | `DELETE /transaction` |

Our v3 backend supports `GET`, `POST` and `DELETE` (no `PUT`).

**Same API, two URLs:**

- Backend's own URL: `http://<backend-private-ip>:8080/transaction`
- What the browser calls: `http://<frontend-public-ip>/api/transaction` → Nginx strips `/api` and forwards it

So the browser never needs the backend's IP or port.

**Test without the UI** using `curl`:

```bash
# create
curl -X POST http://<frontend-public-ip>/api/transaction \
     -H "Content-Type: application/json" \
     -d '{"amount": 100, "category": "Food", "description": "dosa"}'
# → 201 Created

# read all
curl http://<frontend-public-ip>/api/transaction
```

Response is **JSON** - key-value data, easy for people and code to read:

```json
{
  "result": [
    { "id": 2, "amount": 1000, "description": "travelling", "category": "Travel" },
    { "id": 1, "amount": 5000, "description": "lunch with family", "category": "Food" }
  ]
}
```

## 10. HTTP Status Codes

The server answers with a number that says what happened:

| Range | Meaning | Common Codes |
|-------|---------|--------------|
| 1XX | Info | - |
| 2XX | Success | `200` OK, `201` Created, `204` No Content (e.g. after delete) |
| 3XX | Redirect | `301` Moved Permanently, `304` Not Modified (use your cached copy) |
| 4XX | **Client** mistake | `400` Bad Request, `401` Unauthorized, `403` Forbidden, `404` Not Found, `405` Method Not Allowed |
| 5XX | **Server** problem | `500` Internal Server Error, `501` Not Implemented, `502` Bad Gateway, `503` Service Unavailable, `504` Gateway Timeout |

- **401 vs 403:** `401` = "I don't know who you are" (no/invalid login). `403` = "I know who you are, but you're not allowed".
- **405:** the URL exists but not for that method - e.g. our backend returns `405` for `PUT /transaction`.
- **502 / 504 in 3-tier:** usually not Nginx's fault - the backend behind it is down (`502`) or too slow (`504`). See [Troubleshooting](../troubleshooting/README.md#the-error-tells-you-the-layer).
