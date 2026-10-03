# Day 8 - Nginx, Forward & Reverse Proxy, REST API & HTTP Status Codes

> **Nginx is popular because one tool can do many jobs:**
> * HTTP server
> * Load balancer
> * Reverse proxy
> * SSL termination
> * Caching server

## Table of Contents

1. [Quick Recap - Deploying the Backend](#quick-recap---deploying-the-backend)
2. [Frontend](#frontend)
3. [Nginx](#nginx)
   - [Why Nginx Is Popular](#why-nginx-is-popular)
   - [Important Paths](#important-paths)
   - [Ports and Domains](#ports-and-domains)
   - [Nginx Logs](#nginx-logs)
4. [Forward Proxy vs Reverse Proxy](#forward-proxy-vs-reverse-proxy)
5. [Load Balancing](#load-balancing)
6. [Nginx Reverse Proxy Config](#nginx-reverse-proxy-config)
7. [Side Note: sudoers](#side-note-sudoers)
8. [API](#api)
9. [HTTP Methods (CRUD)](#http-methods-crud)
10. [HTTP Status Codes](#http-status-codes)
11. [Summary](#summary)
12. [Interview Questions](#interview-questions)

**Diagrams:** [Why Nginx](images/01-why-nginx-is-popular.svg) · [Forward vs Reverse Proxy](images/02-forward-vs-reverse-proxy.svg) · [Request Flow & REST API](images/03-request-flow-and-rest-api.svg) · [Status Codes](images/04-http-status-codes.svg)

---

## Quick Recap - Deploying the Backend

Deploying an app means getting its code onto a server and keeping it running. Whatever the language, the steps are the same - only the commands change.

**The 9 steps (Node.js example):**

1. Install the programming language - `nodejs:24`
2. Create a directory for the application - `/app`
3. Create a system user to run the application - `expense`
4. Download the application as `.tar.gz` into `/tmp`
5. Extract it into `/app`
6. Install dependencies
7. Create the `systemctl` service file
8. Load the schema into the DB
9. Start the application

**Node.js things to remember:**

| Item | What it is |
|------|------------|
| `.js` | Node.js file extension |
| `package.json` | Name, version, description, start scripts, dependencies, etc. |
| `npm` | Node's build / package tool |
| `npm install` | Downloads every dependency listed in `package.json` |
| `package-lock.json` | Locks the **exact** versions of dependencies and sub-dependencies |
| `node_modules/` | Folder where all the dependencies are stored |

Nowadays there's no need for heavy application servers - applications come with **built-in lightweight servers** (Node.js listens on port 8080 by itself).

## Frontend

The frontend is just **HTML, CSS and JS** files. They don't run on the server - the server only hands them to the browser, and the browser runs them. So all we need is a web server that can serve files → **Nginx**.

## Nginx

**Nginx** (pronounced "engine-x") is a web server - software that listens on a port (80/443), receives requests from browsers and sends back a response. It's light, fast and can handle thousands of connections at once.

![Why Nginx is popular](images/01-why-nginx-is-popular.svg)

### Why Nginx Is Popular

Most tools do one job. Nginx can do five, so one install covers many needs - HTTP server, load balancer, reverse proxy, SSL termination and caching server.

#### 1. HTTP Server

We write the website as HTML/CSS/JS files and keep them in Nginx's folder (`/usr/share/nginx/html`). When someone opens our IP or domain in the browser, Nginx (the HTTP server) picks up those files and sends them back - and the browser shows them as the webpage we designed.

**In short:** we keep the files → Nginx serves them → the user sees the webpage.

```text
/usr/share/nginx/html/index.html   →   http://<public-ip>/   →   webpage in the browser
```

**Example:** in our expense app, the frontend files are extracted into `/usr/share/nginx/html`, and opening `http://<public-ip>/` shows the expense app UI.

#### 2. Load Balancer

When the same app runs on many servers, Nginx receives every request and shares them across the servers, so no single server gets overloaded. If one server goes down, it sends requests to the others.

**Example:** 3 frontend servers behind one Nginx - request 1 → server 1, request 2 → server 2, request 3 → server 3. More in [Load Balancing](#load-balancing).

#### 3. Reverse Proxy

Nginx receives the user's request and **forwards it to another server** behind it (like our backend), then sends the answer back to the user. The user only talks to Nginx and never sees the backend.

**Example:** `http://<public-ip>/api/transaction` → Nginx forwards it to `http://<backend-private-ip>:8080/transaction`. More in [Forward Proxy vs Reverse Proxy](#forward-proxy-vs-reverse-proxy).

#### 4. SSL Termination

HTTPS traffic is encrypted. Nginx holds the SSL certificate, **decrypts** the HTTPS request, and passes it to the servers behind it as plain HTTP. So only Nginx deals with certificates - the backend servers don't have to.

**Example:** user opens `https://mydomain.com` (port 443) → Nginx decrypts → backend gets a normal HTTP request on 8080.

#### 5. Caching Server

Nginx keeps a **copy** of responses (images, CSS, pages that don't change often). When the next user asks for the same thing, Nginx answers from its copy instead of asking the backend again - faster for the user, less load on the backend.

**Example:** the logo image is requested 1000 times - the backend sends it once, Nginx serves the other 999 from its cache.

### Important Paths

On Linux, every package puts its files in fixed places. Knowing these 4 paths is enough to deploy, configure and debug Nginx.

| Path | What |
|------|------|
| `/usr/share/nginx/html/` | Nginx default HTML directory - web files go here |
| `/usr/share/nginx/html/index.html` | Default HTML page. If you open `http://<public-ip>/` and see the Nginx welcome page, **Nginx is installed and running** |
| `/etc/nginx/nginx.conf` | Nginx default configuration is stored here |
| `/var/log/nginx/` | Nginx logs - `access.log` and `error.log` |

> **Interview Q:** Where do you change Nginx's default port number?
> In `/etc/nginx/nginx.conf` - change the `listen 80;` line in the `server` block, then `nginx -t` and `systemctl restart nginx`.

### Ports and Domains

A **port** is like a door number on the server - one IP can run many apps, each listening on its own port. A **domain** is just an easy name that DNS turns into the IP.

**Examples:**

| URL typed | What actually happens |
|-----------|-----------------------|
| `http://<public-ip>/` | Connects to the Linux server on HTTP port **80** - no port typed, so the browser uses 80 by default (same as `http://<public-ip>:80/`) |
| `http://mydomain.com` | After the domain is mapped in DNS, the name is converted to the IP → same as `http://<public-ip>/` |
| `http://mydomain.com:81` | Connects on port **81**. Works only if Nginx is set to `listen 81;` - and the port **must be typed** in the URL |
| `https://mydomain.com` | Same as `https://mydomain.com:443` - HTTPS default port is **443** |
| backend | Our backend app is reached on port **8080** (only Nginx talks to it, not the internet) |

**Why everyone uses default ports:**

- If you don't mention a port in the URL, the browser takes the **default port** - **80** for `http`, **443** for `https`.
- So clients never need to remember or type port numbers - they just type the domain.
- The port number is written in the **server's config file** (`listen 80;`), not given to users.
- If the server uses a non-default port (like 81), the browser still tries 80 unless you type `:81` - that's why we stick to the defaults.

### Nginx Logs

A **log** is a file where Nginx writes down everything that happens - like a register at a building entrance. When something breaks, logs are the first place to look.

Both logs are in `/var/log/nginx/`:

| File | What's in it |
|------|--------------|
| `access.log` | Every request - who came (IP), when (timestamp), what they asked for, status code, which browser |
| `error.log` | Errors - if something fails, the details are stored here |

```bash
tail -f /var/log/nginx/access.log    # watch requests live
tail -f /var/log/nginx/error.log     # watch errors live (-f = follow, shows new lines as they come)
```

**Where the log format comes from:**

Nginx doesn't decide the log line by itself - the format is defined in the config file `/etc/nginx/nginx.conf`, inside the `http { }` block:

```nginx
http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    ...
}
```

- `log_format main '...'` → creates a format named **main**. Each `$variable` is filled in by Nginx for every request.
- `access_log /var/log/nginx/access.log main;` → write every request to `access.log` **using the `main` format**.
- The error log is set separately (outside `http`): `error_log /var/log/nginx/error.log;`
- Want different details in the log? Change `log_format` (or create a new one), then `nginx -t` and `systemctl restart nginx`.

**Reading an access log line (format → real line):**

```text
203.0.113.42 - - [30/Sep/2026:02:24:50 +0000] "GET / HTTP/1.1" 200 9466 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36 Edg/154.0.0.0" "-"
```

| Variable in `log_format` | Value in the line | Meaning |
|--------------------------|-------------------|---------|
| `$remote_addr` | `203.0.113.42` | Client IP - where the request came from |
| `-` | `-` | Just a fixed dash written in the format |
| `$remote_user` | `-` | Logged-in user (HTTP basic auth) - none, so `-` |
| `[$time_local]` | `[30/Sep/2026:02:24:50 +0000]` | Timestamp of the request |
| `"$request"` | `"GET / HTTP/1.1"` | Method + path + protocol (asked for the home page) |
| `$status` | `200` | Status code - success |
| `$body_bytes_sent` | `9466` | Response size in bytes |
| `"$http_referer"` | `"-"` | Page the user came from - none, typed directly |
| `"$http_user_agent"` | `"Mozilla/5.0 (Windows NT 10.0 ...) ... Edg/154.0.0.0"` | Browser + OS (here: Microsoft Edge on Windows 10/11) |
| `"$http_x_forwarded_for"` | `"-"` | Real client IP if the request came through another proxy - none here |

> Any value that's empty is written as `-`.

## Forward Proxy vs Reverse Proxy

![Forward proxy vs reverse proxy and the team lead analogy](images/02-forward-vs-reverse-proxy.svg)

**Proxy** = someone acting **on behalf of** someone else - a middleman between the client and the server.

- **Forward proxy** sits on the **client's side**. The client sends its request to the proxy, and the proxy goes to the internet for it. The website sees the proxy, not the real client.
- **Reverse proxy** sits on the **server's side**. The client thinks it's talking to the website, but the proxy receives the request and passes it to the real server behind it. The client never sees the real server.

**Analogies:**

- Forward proxy = asking a friend to buy something for you - the shop only sees your friend.
- Reverse proxy = a hotel reception - guests talk to reception, which sends the request to housekeeping, kitchen, etc. Guests never deal with the staff behind it directly.

**Comparison:**

| | Forward Proxy | Reverse Proxy |
|---|---------------|---------------|
| Works for | The **client** (client is aware of it) | The **server** (server is aware of it) |
| Hides | The client's identity | The server's identity |
| Used for | VPN, changing geo location, traffic monitoring and content restriction (office internet) | SSL/TLS termination, cache, load balancing |
| Example | Office proxy / VPN app on your laptop | Nginx in front of our backend |

```text
Forward:  Client → [Forward Proxy] → Internet → Server
Reverse:  Client → Internet → [Reverse Proxy] → Server(s)
```

## Load Balancing

One server can handle only so many requests. When traffic grows, we run **many copies of the same app on many servers**. Now someone has to decide which server gets each request - that's the **load balancer**.

A load balancer:

- Is the **single entry point** - users hit the load balancer, not the servers
- **Spreads requests** across servers so no single server is overloaded
- **Checks health** - if a server is down, it stops sending requests to it
- Makes adding/removing servers easy - users don't notice

```text
              Users
                │
                ▼
        ┌───────────────┐
        │ Load Balancer │   (e.g. Nginx)
        └───────────────┘
         │      │      │
         ▼      ▼      ▼
     Server1 Server2 Server3   ← same app on all
```

The simplest method is **round-robin** - request 1 → server 1, request 2 → server 2, request 3 → server 3, then back to server 1.

### Analogy - The Team Lead

Think of a team lead (TL):

- Monitors all the members
- Knows how many members are available today
- Knows how much work each member is doing
- Gives the next task to whoever can take it

A delivery manager works the same way one level up - they don't do the work, they route it to the right lead:

```text
                Delivery Manager   ← like Nginx (single entry point)
               /        |        \
         UI Lead   Backend Lead   DB Lead
            |           |            |
        UI team   Backend team    DB team
```

The load balancer = TL: it checks which servers are healthy and how busy they are, and sends each request to one of them.

## Nginx Reverse Proxy Config

This is how we make our frontend Nginx act as a reverse proxy: any request starting with `/api/` is passed to the backend server, everything else is served from the HTML folder. The extra headers make sure the backend still knows who the real user is.

`/etc/nginx/default.d/expense.conf`:

```nginx
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

location /api/ {
    proxy_pass http://<backend-private-ip>:8080/;
}

location /health {
    stub_status on;
    access_log off;
}
```

| Line | Meaning |
|------|---------|
| `proxy_http_version 1.1` | Talk to the backend using HTTP/1.1 (keeps connections alive) |
| `Host $host` | Pass on the domain/IP the user typed |
| `X-Real-IP $remote_addr` | Pass the real client IP - otherwise the backend only sees Nginx's IP |
| `X-Forwarded-For` | Client IP + every proxy the request passed through |
| `X-Forwarded-Proto $scheme` | Whether the user came on `http` or `https` |
| `location /api/` | Any URL starting with `/api/` goes to the backend |
| `proxy_pass http://...:8080/` | The trailing `/` strips `/api` → `/api/transaction` reaches the backend as `/transaction` |
| `location /health` + `stub_status on` | Shows Nginx's own stats (active connections, requests) at `http://<public-ip>/health` |
| `access_log off` | Don't fill the log with health-check hits |

After editing, always:

```bash
nginx -t                    # check config syntax
systemctl restart nginx
```

## Side Note: sudoers

`sudo` lets a normal user run commands as root. Who is allowed to use sudo is decided by the **sudoers** config.

Two ways to give a user sudo access:

1. `/etc/sudoers` → direct changes in the main file (edit with `visudo`)
2. `/etc/sudoers.d/` → individual config files, one per user/group (cleaner, easy to add/remove)

## API

![Request flow in the 3-tier app and REST API methods](images/03-request-flow-and-rest-api.svg)

**API = Application Programming Interface** - the way one program talks to another. Here the frontend (browser) talks to the backend through the API, and the data comes back as **JSON**.

**Analogy:** a waiter in a restaurant - you (frontend) don't go into the kitchen (backend); you give your order to the waiter (API), and the waiter brings back the food (JSON response).

**Example:** `GET http://<public-ip>/api/transaction`:

```json
{
    "result": [
        { "id": 26, "amount": 1000, "description": "food", "category": "Food" },
        { "id": 25, "amount": 500, "description": "shopping in mall", "category": "Shopping" },
        { "id": 20, "amount": 7000, "description": "Malaysia", "category": "Travel" },
        { "id": 17, "amount": 1500, "description": "Team Outing", "category": "Travel" }
    ]
}
```

## HTTP Methods (CRUD)

An **HTTP method** tells the server **what action** you want on the data. Almost every app only does four things with data - **CRUD** = Create, Read, Update, Delete - and each maps to a method.

**Examples:**

| CRUD | Method | URL | Body |
|------|--------|-----|------|
| Read all | `GET` | `http://<public-ip>/api/transaction` | - |
| Read one | `GET` | `http://<public-ip>/api/transaction/31` | - |
| Create | `POST` | `http://<public-ip>/api/transaction` | `{"amount": 200, "category": "Entertainment", "description": "movie"}` |
| Update | `PUT` | `http://<public-ip>/api/transaction` | Full record **with** `id` (below) |
| Delete | `DELETE` | `http://<public-ip>/api/transaction/32` | - (deletes transaction 32) |

`PUT` - updating transaction 17's category:

```json
{
    "id": 17,
    "amount": 1500,
    "description": "Team Outing",
    "category": "Entertainment"
}
```

Try them with `curl`:

```bash
curl http://<public-ip>/api/transaction                         # GET
curl -X POST http://<public-ip>/api/transaction \
     -H "Content-Type: application/json" \
     -d '{"amount": 200, "category": "Entertainment", "description": "movie"}'
curl -X DELETE http://<public-ip>/api/transaction/32             # DELETE
```

## HTTP Status Codes

![HTTP status codes](images/04-http-status-codes.svg)

A **status code** is a 3-digit number the server sends back with every response to say **what happened** - success, moved, your mistake, or the server's mistake. Computers only care about numbers, humans can't remember them all - so we just learn the ranges.

| Range | Meaning |
|-------|---------|
| **1XX** | Information |
| **2XX** | Success |
| **3XX** | Redirection |
| **4XX** | Client-side error |
| **5XX** | Server-side error |

**2XX - Success**

| Code | Meaning |
|------|---------|
| `200` | OK - you got the response |
| `201` | Created (after `POST`) |
| `204` | No content - info deleted (after `DELETE`) |

**4XX - Client-side error** (the request is wrong)

| Code | Meaning |
|------|---------|
| `400` | Bad request |
| `401` | Wrong credentials (not logged in) |
| `403` | No authorization (logged in, but not allowed) |
| `404` | Not found |

**5XX - Server-side error** (the request is fine, the server failed)

| Code | Meaning |
|------|---------|
| `500` | Internal server error |
| `501` | Not implemented |
| `502` | Bad gateway - frontend (Nginx) is not able to connect to the backend |
| `503` | Service unavailable |
| `504` | Gateway timeout - backend is not responding on time |

**Client mistake example** - a typo in the key (`descrition` instead of `description`):

```json
{
    "id": 17,
    "amount": 1500,
    "descrition": "Team Outing",
    "category": "Entertainment"
}
```

The backend doesn't get the `description` field it expects. That's the **client's** fault, so the answer is in the **4XX** range (e.g. `400 Bad Request`), not 5XX.

> **Quick rule:** 4XX → check what you sent. 5XX → check the server (502/504 → is the backend up and reachable?).

## Summary

- Nginx = HTTP server + load balancer + reverse proxy + SSL termination + cache.
- Web files live in `/usr/share/nginx/html`, config in `/etc/nginx/nginx.conf`, logs in `/var/log/nginx`.
- Forward proxy works for the client and hides it; reverse proxy works for the server and hides it.
- `location /api/` + `proxy_pass` sends API calls to the backend on 8080; `X-Forwarded-*` headers keep the real client details.
- REST API: `GET` read, `POST` create, `PUT` update, `DELETE` delete; data travels as JSON.
- Status codes: 2XX success, 3XX redirect, 4XX client error, 5XX server error.

## Interview Questions

Quick revision questions for this day are in [interview-questions/README.md](interview-questions/README.md).
