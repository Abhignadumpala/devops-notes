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
   - [Reading an Access Log Line](#reading-an-access-log-line)
4. [Forward Proxy vs Reverse Proxy](#forward-proxy-vs-reverse-proxy)
5. [Load Balancing - The Team Lead Analogy](#load-balancing---the-team-lead-analogy)
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

Any application deployment follows the same 9 steps:

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

![Why Nginx is popular](images/01-why-nginx-is-popular.svg)

### Why Nginx Is Popular

| Role | What it does |
|------|--------------|
| **HTTP server** | Serves HTML/CSS/JS files to the browser |
| **Load balancer** | Spreads requests across many servers |
| **Reverse proxy** | Takes the request and forwards it to the backend |
| **SSL termination** | Handles HTTPS so the servers behind it don't have to |
| **Caching server** | Keeps copies of responses to answer faster |

### Important Paths

| Path | What |
|------|------|
| `/usr/share/nginx/html/` | Default HTML directory |
| `/usr/share/nginx/html/index.html` | Default page shown at `http://<public-ip>/` |
| `/etc/nginx/nginx.conf` | Default (main) configuration |
| `/var/log/nginx/` | Logs - `access.log` and `error.log` |

### Ports and Domains

| URL typed | What actually happens |
|-----------|-----------------------|
| `http://<public-ip>/` | Linux server, HTTP on port **80** |
| `http://mydomain.com` | Same as `http://<public-ip>/` - the domain is just a name for the IP |
| `http://mydomain.com:81` | Any port other than 80/443 must be typed |
| `https://mydomain.com` | Same as `https://mydomain.com:443` |

- HTTP → **80**, HTTPS → **443** (the browser adds these automatically).
- Our backend → **8080** (never opened to the internet, only Nginx talks to it).

### Reading an Access Log Line

```text
203.0.113.42 - - [30/Sep/2026:02:24:50 +0000] "GET / HTTP/1.1" 200 9466 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ... Chrome/154.0.0.0 ..." "-"
```

| Part | Meaning |
|------|---------|
| `203.0.113.42` | Client IP (who made the request) |
| `[30/Sep/2026:02:24:50 +0000]` | Time of the request |
| `"GET / HTTP/1.1"` | Method + path + protocol |
| `200` | Status code |
| `9466` | Response size in bytes |
| `"-"` | Referrer (page the user came from - none here) |
| `"Mozilla/5.0 ..."` | User agent (browser + OS) |

```bash
tail -f /var/log/nginx/access.log    # watch requests live
tail -f /var/log/nginx/error.log     # watch errors live
```

## Forward Proxy vs Reverse Proxy

![Forward proxy vs reverse proxy and the team lead analogy](images/02-forward-vs-reverse-proxy.svg)

**Proxy** = someone acting **on behalf of** someone else.

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

## Load Balancing - The Team Lead Analogy

When there are many servers, someone has to **queue and spread** the requests - that's the load balancer.

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

Two ways to give a user sudo access:

1. `/etc/sudoers` → direct changes in the main file (edit with `visudo`)
2. `/etc/sudoers.d/` → individual config files, one per user/group (cleaner, easy to add/remove)

## API

![Request flow in the 3-tier app and REST API methods](images/03-request-flow-and-rest-api.svg)

**API = Application Programming Interface** - the way one program talks to another. Here the frontend (browser) talks to the backend through the API, and the data comes back as **JSON**.

`GET http://<public-ip>/api/transaction`:

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

**CRUD** = Create, Read, Update, Delete - every app does these four things, and each maps to an HTTP method:

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

Computers only care about numbers, humans can't remember numbers - so every response carries a **status code** and we just need to know the ranges.

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
