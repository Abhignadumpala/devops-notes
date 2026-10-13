# RoboShop 3 Tier Architecture

[← Back to all notes](../README.md)

![RoboShop architecture](../day-10-databases-sql-nosql-cache-queues/images/01-roboshop-3-tier-architecture.svg)

RoboShop is an online robot store built from small services. Each service runs on its own EC2 server (RHEL 9) and is managed by `systemd`.

---

## Services, Ports and Versions

| Service | Port | Technology | Version |
|---------|------|------------|---------|
| Frontend | 80 | Nginx + React | nginx 1.26, React 19 |
| Catalogue | 8080 | Node.js | 24 |
| User | 8080 | Node.js | 24 |
| Cart | 8080 | Node.js | 24 |
| Shipping | 8080 | Java (Spring Boot 4) | OpenJDK 25, Maven 3.9 |
| Payment | 8080 | Python (Flask + gunicorn) | 3.14 |
| Dispatch | - | Go (consumer only) | 1.25 or newer |
| MongoDB | 27017 | NoSQL Database | 7.0 |
| Redis | 6379 | In-memory Cache | 7 |
| MySQL | 3306 | SQL Database | 8.4 |
| RabbitMQ | 5672 | Message Queue | 4.x |

> **MongoDB stays on 7.0.** MongoDB 8.0 crashes on the RHEL 9 practice AMI (`Fatal assertion 40379` at startup).

All versions come from the RHEL 9 AppStream repos, except MongoDB and RabbitMQ, which use their vendor repos. RHEL 9.8 or newer is needed for Python 3.14, and RHEL 9.7 or newer for Node.js 24, OpenJDK 25 and Go. Check with `cat /etc/redhat-release`.

---

## Server Image (AMI)

All 11 servers use the same AMI:

| Field | Value |
|-------|-------|
| AMI name | `Redhat-9-DevOps-Practice` |
| AMI ID | `ami-0220d79f3f480ecf5` (us-east-1) |
| OS | RHEL 9 |
| Instance type | t3.micro (2 vCPU) |
| Key pair | None (the AMI uses password login for `ec2-user`) |

> AMI IDs are different in every region. In another region, search for the AMI name `Redhat-9-DevOps-Practice`.

---

## Setup Order

Databases first, then the backend services that use them, then the frontend.

**Databases**

1. [01-mongodb.md](01-mongodb.md)
2. [02-redis.md](02-redis.md)
3. [03-mysql.md](03-mysql.md)
4. [04-rabbitmq.md](04-rabbitmq.md)

**Backend**

5. [05-catalogue.md](05-catalogue.md)
6. [06-user.md](06-user.md)
7. [07-cart.md](07-cart.md)
8. [08-shipping.md](08-shipping.md)
9. [09-payment.md](09-payment.md)
10. [10-dispatch.md](10-dispatch.md)

**Frontend**

11. [11-frontend.md](11-frontend.md)

Once the frontend is up, the **System status** link at the top of the website shows which services are up.

---

## Artifacts

Each server downloads its application zip directly from GitHub:

```
https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/<name>-v4.zip
```

| Artifact | Contents |
|----------|----------|
| `frontend-v4.zip` | Built React website (HTML, JS, CSS, fonts, product images) |
| `catalogue-v4.zip` | Node.js code + `db/master-data.js` (products and a demo user) |
| `user-v4.zip` | Node.js code |
| `cart-v4.zip` | Node.js code |
| `shipping-v4.zip` | Java source + `db/master-data.sql` (cities) and `db/app-user.sql` |
| `payment-v4.zip` | Python code + `requirements.txt` |
| `dispatch-v4.zip` | Go source (`main.go`, `go.mod`, `go.sum`) |

The frontend Nginx config is in [11-frontend.md](11-frontend.md#configure-the-reverse-proxy).

> **Demo login:** user `roboshop`, password `RoboShop@1`. You can also register a new user on the website.

---

## Logs and Request Tracing

Every backend service writes one JSON line per request to the journal. Nginx creates a request id for each request and passes it to the backend services in the `X-Request-Id` header. Payment also puts it into the RabbitMQ message, so dispatch logs it too.

Find the id of a request in the browser (DevTools → Network → response header `X-Request-Id`), then search for it on every server:

```shell
journalctl -u catalogue | grep <request-id>
```

One checkout can be followed through frontend → shipping → cart → payment → user → cart → dispatch.

---

## Security Groups

### Step 1: Create 11 security groups (SSH only)

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| SSH | 22 | My IP | your IP (auto) | SSH access |

Names: `roboshop-mongodb`, `roboshop-redis`, `roboshop-mysql`, `roboshop-rabbitmq`, `roboshop-catalogue`, `roboshop-user`, `roboshop-cart`, `roboshop-shipping`, `roboshop-payment`, `roboshop-dispatch`, `roboshop-frontend`

### Step 2: roboshop-frontend (extra rule)

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| HTTP | 80 | Anywhere-IPv4 | 0.0.0.0/0 | HTTP from internet |

### Step 3: roboshop-mongodb

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 27017 | Custom | `roboshop-catalogue` | Catalogue reads products |
| Custom TCP | 27017 | Custom | `roboshop-user` | User reads/writes users and orders |

### Step 4: roboshop-redis

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 6379 | Custom | `roboshop-user` | Guest id counter |
| Custom TCP | 6379 | Custom | `roboshop-cart` | Stores the carts |

### Step 5: roboshop-mysql

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| MYSQL/Aurora | 3306 | Custom | `roboshop-shipping` | Shipping reads city data |

### Step 6: roboshop-rabbitmq

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 5672 | Custom | `roboshop-payment` | Payment publishes orders |
| Custom TCP | 5672 | Custom | `roboshop-dispatch` | Dispatch consumes orders |
| Custom TCP | 15672 | My IP | your IP (auto) | Management UI (optional) |

### Step 7: roboshop-catalogue

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 8080 | Custom | `roboshop-frontend` | Frontend reverse proxy |
| Custom TCP | 8080 | Custom | `roboshop-cart` | Cart checks price and stock |

### Step 8: roboshop-user

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 8080 | Custom | `roboshop-frontend` | Frontend reverse proxy |
| Custom TCP | 8080 | Custom | `roboshop-payment` | Payment checks user, saves order |

### Step 9: roboshop-cart

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 8080 | Custom | `roboshop-frontend` | Frontend reverse proxy |
| Custom TCP | 8080 | Custom | `roboshop-shipping` | Shipping adds shipping cost |
| Custom TCP | 8080 | Custom | `roboshop-payment` | Payment empties the cart |

### Step 10: roboshop-shipping

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 8080 | Custom | `roboshop-frontend` | Frontend reverse proxy |

### Step 11: roboshop-payment

| Type | Port range | Source type | Source | Description |
|------|------------|-------------|--------|-------------|
| Custom TCP | 8080 | Custom | `roboshop-frontend` | Frontend reverse proxy |

### Step 12: roboshop-dispatch

No extra rule. SSH only.
