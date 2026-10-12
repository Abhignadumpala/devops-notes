# Day 12 - Nginx: Reverse Proxy for a Multi-Service Backend

> **In short:** One frontend Nginx sits in front of many backend services (catalogue, user, cart, shipping, payment). It routes each request by path, and adds the same tracing, security headers, compression, caching and JSON errors to every service.

## Table of Contents

1. [What this is / why it matters](#what-this-is--why-it-matters)
2. [How it works](#how-it-works)
   - [Routing Multiple Services Behind One Entry Point](#routing-multiple-services-behind-one-entry-point)
   - [Common Settings for Every Backend Call](#common-settings-for-every-backend-call)
   - [Tracing One Request Across Every Service](#tracing-one-request-across-every-service)
   - [Security Headers and Hiding Server Details](#security-headers-and-hiding-server-details)
   - [Compression](#compression)
   - [Consistent JSON Error Responses](#consistent-json-error-responses)
   - [Health Checks](#health-checks)
   - [Caching Static Assets](#caching-static-assets)
   - [Serving a Single-Page App (React)](#serving-a-single-page-app-react)
3. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
4. [Key takeaways](#key-takeaways)
5. [Interview Questions](#interview-questions)

**More in this folder:** [Interview questions](interview-questions/README.md)

---

## What this is / why it matters

- In [Day 8](../day-08-nginx-proxy-api-status-codes/README.md) Nginx had one backend behind it.
- Real apps split the backend into many services - e.g. `catalogue`, `user`, `cart`.
- Nginx sits in front of all of them and:
  1. Sends each request to the right service
  2. Adds tracing, security headers and error handling to every service in one place

## How it works

### Routing Multiple Services Behind One Entry Point

- Each service gets its own `location` block, matched by a path prefix.
- The **trailing slash** on both the path and the `proxy_pass` target strips the `/api/<service>` prefix before forwarding.

```nginx
# /api/catalogue/products -> http://<catalogue-ip>:8080/products
location /api/catalogue/ { proxy_pass http://<catalogue-ip>:8080/; }
location /api/user/      { proxy_pass http://<user-ip>:8080/; }
location /api/cart/      { proxy_pass http://<cart-ip>:8080/; }
location /api/shipping/  { proxy_pass http://<shipping-ip>:8080/; }
location /api/payment/   { proxy_pass http://<payment-ip>:8080/; }
```

**Example:**

1. The browser calls `http://abhignadevops.store/api/catalogue/product/STAN-1`
2. Nginx matches `/api/catalogue/`
3. Nginx forwards it to `http://<catalogue-ip>:8080/product/STAN-1`
4. The browser never knows the catalogue service's private IP or port

### Common Settings for Every Backend Call

These are reused in every `location` block that proxies to a service:

```nginx
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 5s;
proxy_read_timeout    30s;   # returns 504 if a service takes longer than this
```

| Setting | What it does |
|---|---|
| `Host` | Passes the domain the user typed |
| `X-Real-IP` | The real client's IP |
| `X-Forwarded-For` | Chain of IPs the request passed through |
| `X-Forwarded-Proto` | `http` or `https` the user used |
| `proxy_connect_timeout` | How long to wait to connect to the service |
| `proxy_read_timeout` | How long to wait for the answer → `504` after that |

**Why the `X-Forwarded-*` headers matter:** to every service, each request looks like it comes from Nginx. These headers keep the real client's IP and protocol, so the service logs show who really made the request.

### Tracing One Request Across Every Service

```nginx
add_header X-Request-Id $request_id always;
proxy_set_header X-Request-Id $request_id;
proxy_hide_header X-Request-Id;  # hide the service's own ID; Nginx's ID is the real one
```

1. Nginx creates a unique `$request_id` for every request
2. It passes the ID to the service that handles it
3. It sends the same ID back to the browser in the response
4. If catalogue calls cart, the same ID goes through both
5. One failed click → search one ID across every service's logs (no guessing by timestamp)

### Security Headers and Hiding Server Details

```nginx
server_tokens off;   # don't show the Nginx version to clients
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options SAMEORIGIN always;
add_header Referrer-Policy strict-origin-when-cross-origin always;
```

| Header | What it stops |
|---|---|
| `server_tokens off` | Hides the Nginx version - no free hint for attackers looking for a known bug |
| `X-Content-Type-Options nosniff` | Browser won't guess the file type (e.g. run a text file as JS) |
| `X-Frame-Options SAMEORIGIN` | Other sites can't load my page inside an iframe (clickjacking) |
| `Referrer-Policy` | Sends only the domain, not the full URL, when users click away to other sites |

### Compression

```nginx
gzip on;
gzip_types text/css application/javascript application/json image/svg+xml;
gzip_min_length 1024;
```

- Nginx compresses responses bigger than 1 KB before sending them.
- Faster for text-heavy files - CSS, JS, JSON, SVG.
- Images (JPG/PNG) are already compressed, so they're not listed.

### Consistent JSON Error Responses

- If Nginx can't reach a service, or the service is too slow, Nginx returns its own **HTML** error page.
- A JSON API client can't parse HTML → so return JSON instead:

```nginx
error_page 502 = @bad_gateway;
error_page 504 = @gateway_timeout;

location @bad_gateway {
    default_type application/json;
    return 502 '{"message":"service not reachable (502 Bad Gateway from nginx)"}';
}
location @gateway_timeout {
    default_type application/json;
    return 504 '{"message":"service did not answer in time (504 Gateway Timeout from nginx)"}';
}
```

| Error comes from | Example | What Nginx does |
|---|---|---|
| **Nginx itself** | `502` service down, `504` service too slow | Replaced with the JSON message above |
| **The service** | Its own `404`, `503` | Passed through untouched - the service is reporting its own problem |

### Health Checks

```nginx
location = /health {
    stub_status on;
    access_log off;
}
```

- `stub_status` shows Nginx's own connection counters.
- This checks **Nginx only** - not whether the backend services are healthy.
- `access_log off` keeps health-check hits out of the logs.

### Caching Static Assets

```nginx
# product images - fall back to a placeholder if missing
location /images/ {
    expires 1h;
    try_files $uri /images/placeholder.jpg;
}

# filenames in /assets contain a content hash, so they never change - cache forever
location /assets/ {
    expires max;
    try_files $uri =404;
}
```

| Path | Cache time | Why |
|---|---|---|
| `/images/` | 1 hour | An image can change but keep the same filename |
| `/assets/` | Forever (`max`) | Filename has a hash (e.g. `app.3f9a1c.js`) - new content = new filename |

### Serving a Single-Page App (React)

```nginx
location / {
    expires -1;
    try_files $uri $uri/ /index.html;
}
```

1. React handles paths like `/product/STAN-1` or `/cart` inside the browser
2. There's no real file at that path on the server
3. `try_files` falls back to `index.html` for any unknown path
4. React's router loads and shows the right page
5. `expires -1` → `index.html` is never cached, so users always get the latest build

## Common problems and how to solve them

| Problem | What happens | Fix |
|---|---|---|
| **Forgot the `X-Forwarded-*` headers** | Every service log shows Nginx's IP as the client | Add the `proxy_set_header` lines to every proxied `location` |
| **Nginx's default HTML error pages on a JSON API** | Clients expecting JSON break when parsing the error | Custom `error_page` blocks that return JSON |
| **Wrong cache time** | Hashed assets re-downloaded too often, or old images stuck in the browser | Hashed filenames → cache forever; unhashed images → short cache |
| **Missing trailing slash in `proxy_pass`** | Service gets `/api/catalogue/products` instead of `/products` → `404` | Keep the slash on both the `location` path and the `proxy_pass` URL |

## Key takeaways

- One Nginx fronts many services, routing by path (`/api/<service>/`) - the browser never knows any service's real address.
- `X-Request-Id` traces one request across every service it touches.
- Nginx's own errors (`502`/`504`) → reshape into JSON. A service's own errors → pass through.
- Cache time should match how the file changes: forever for hashed names, short for anything else.

See also: [Day 7 - Expense App](../day-07-3tier-nodejs-expense-app/README.md) · [Day 8 - Nginx](../day-08-nginx-proxy-api-status-codes/README.md) · [Day 11 - Backend Deployment](../day-11-backend-deployment-languages/README.md) · [RoboShop setup docs](../roboshop-docs/README.md)

---

## Interview Questions

10 questions with short answers → [interview-questions/](interview-questions/README.md)
