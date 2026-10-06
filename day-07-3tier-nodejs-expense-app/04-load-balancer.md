# Load Balancer

The load balancer (LB) sits in front of the frontend EC2s and spreads incoming traffic across them. It's a plain EC2 running Nginx, used differently:

- It does **not** serve any app files (no HTML/CSS/JS).
- It does **not** talk to the backend. It only forwards requests to the **frontends**.

```text
User → LB (Nginx) → frontend-1 / frontend-2 (Nginx) → backend:8080 → MySQL:3306
```

---

## Install Nginx

```bash
dnf install nginx -y
```

---

## Replace the Default Config

**File to edit on the LB server: `/etc/nginx/nginx.conf`**

On the frontend we never edit `nginx.conf`. On the LB we **replace it completely**, because the LB doesn't serve the default web page at all.

```bash
rm -f /etc/nginx/nginx.conf
vim /etc/nginx/nginx.conf
```

Paste the content of [lb.conf](lb.conf):

```nginx
upstream my_frontend_cluster {
    server frontend-1.mydevops.store:80;
    server frontend-2.mydevops.store:80;
}

server {
    listen       80;
    server_name  _;

    location / {
        proxy_pass            http://my_frontend_cluster;
        proxy_set_header      Host              $host;
        proxy_set_header      X-Real-IP         $remote_addr;
        proxy_set_header      X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout    10s;
    }
}
```

*(Only the important part shown - the full file with `events {}` and `http {}` is in [lb.conf](lb.conf).)*

> The frontend names are Route 53 records pointing to the frontends' **private IPs** (not public). Without DNS, put the private IPs directly: `server <FRONTEND-1-PRIVATE-IP>:80;`

| Part | Meaning |
|------|---------|
| `upstream my_frontend_cluster` | The list of frontend servers. Nginx sends requests to them **one by one in turn** (round robin) |
| `proxy_pass http://my_frontend_cluster` | Forward every request to that list |
| `proxy_read_timeout 10s` | Shorter than the frontend's `30s` - through the LB, a slow request times out here first (**504**) |

Check the names resolve, then test the configuration:

```bash
nslookup frontend-1.mydevops.store
nslookup frontend-2.mydevops.store
nginx -t
```

---

## Start the Service

```bash
systemctl enable nginx
systemctl start nginx
```

---

## Verification

Create a Route 53 record `mydevops.store` → `<lb-public-ip>`, then open `http://mydevops.store` (or `http://<LB-PUBLIC-IP>`) in the browser and confirm the Expense Tracker UI loads.

```bash
systemctl status nginx
tail -f /var/log/nginx/access.log
```

To see the LB switching: run `tail -f /var/log/nginx/access.log` on **both** frontends and refresh the page a few times - requests show up on frontend-1 and frontend-2 in turn.

---

## HTTP Status Code Demos

The LB is where `502`, `503` and `504` are easiest to show (comments in [lb.conf](lb.conf)):

| Code | How to see it |
|------|---------------|
| `502` | Stop Nginx on the frontends → LB can't reach any upstream |
| `503` | Uncomment `return 503 ...` in `lb.conf` → `systemctl reload nginx` |
| `504` | Frontend/backend takes longer than `proxy_read_timeout 10s` |

What each code means → [Day 8 - status codes](../day-08-nginx-proxy-api-status-codes/README.md#http-status-codes).

---

## Security Group

- **LB SG:** inbound **22** (SSH) and **80** (HTTP) from anywhere (`0.0.0.0/0`).
- **Frontend SG:** inbound **80** only from the **LB's SG**, not from the internet.
