# Network Commands: Where to Run Each One, and What It Tests

The short version: **which server** to run each command on, and **what question it answers**.
Example: **cart** (caller) connects to **redis** (target) on port 6379.

[← Back to main README](../README.md) · [Connection check commands (full detail + real outputs)](../connection-check-commands/README.md) · [RoboShop debugging guide](../roboshop-debugging-guide/README.md)

## Table of Contents

1. [Caller vs target](#1-caller-vs-target)
2. [ss -lntp vs telnet: side by side](#2-ss--lntp-vs-telnet-side-by-side)
3. [ss -lntp vs ss -tnp: open doors vs who came in](#3-ss--lntp-vs-ss--tnp-open-doors-vs-who-came-in)
4. [All commands: where to run them](#4-all-commands-where-to-run-them)
5. [My server's own addresses: ip a, ip r, hostname -I, curl ifconfig.me](#5-my-servers-own-addresses)
6. [Old vs new commands](#6-old-vs-new-commands)
7. [Debug order](#7-debug-order)
8. [Logs: journalctl vs log files](#8-logs-journalctl-vs-log-files)
9. [Interview Questions](#9-interview-questions)

---

## 1. Caller vs target

| Word | Meaning | Example |
|------|---------|---------|
| **Caller** (client) | the server that **starts** the connection | cart |
| **Target** (server) | the server that **receives** the connection | redis |

```
   CALLER: cart                                   TARGET: redis
 ┌─────────────────────┐                      ┌─────────────────────┐
 │ dig    → name → IP? │                      │ systemctl status    │
 │ telnet → port open? │ ──── port 6379 ────▶ │ ss -lntp            │
 │ nc -zv → port open? │   (security group)   │ curl localhost      │
 │ curl -v → app OK?   │                      │ journalctl          │
 └─────────────────────┘                      └─────────────────────┘
   "can I get there?"                            "is my side ready?"
```

> Rule: **the DNS name on the caller**, **localhost on the target**.

---

## 2. ss -lntp vs telnet: side by side

|  | `ss -lntp` | `telnet <host> <port>` |
|--|------------|------------------------|
| **Run on** | **Target** (redis) | **Caller** (cart) |
| **Question** | "Is my service **listening**, and on which address?" | "Can I **reach** that port from here?" |
| **Tests** | only the target itself | DNS + network + security group + port, the whole path |
| **Doesn't test** | whether others can reach it (SG, DNS) | passwords, protected-mode, whether the app works |
| **Example** | `ss -lntp \| grep 6379` | `telnet redis.abhignadevops.store 6379` |

**Same problem, both sides:**

```
[ root@redis ~ ]# ss -lntp | grep 6379
LISTEN  0.0.0.0:6379   users:(("redis-server",pid=987))      ← door open for everyone

[ root@cart ~ ]# telnet redis.abhignadevops.store 6379
Trying 172.31.10.131...
Connected to redis.abhignadevops.store.                      ← cart can reach it
```

**Reading the results together:**

| `ss -lntp` on target | `telnet` from caller | Problem | Fix |
|----------------------|----------------------|---------|-----|
| `0.0.0.0:6379` | Connected | ✅ none at the network level | if the app still fails → password / app config |
| `0.0.0.0:6379` | **timed out** | blocked on the way | **target's security group** inbound rule |
| `127.0.0.1:6379` | **refused** | listening for localhost only | config `bind 0.0.0.0` → `systemctl restart` |
| nothing | **refused** | service not running | `systemctl status redis`, `journalctl -u redis` |
| anything | `Name or service not known` | DNS | Route 53 record / spelling |

> Why both? `ss` alone can't see the security group. `telnet` alone can't tell **why** it failed. Together they point to the exact part.

Telnet looks stuck after `Connected`: that's **success**. Exit: `Ctrl + ]`, then `quit`.

---

## 3. ss -lntp vs ss -tnp: open doors vs who came in

Both run on the **target**.

| Command | Shows | State | Analogy |
|---------|-------|-------|---------|
| `ss -lntp` | ports **waiting** for connections | `LISTEN` | which doors are unlocked |
| `ss -tnp` | connections **happening now** | `ESTAB` | who has walked in |

```
[ root@redis ~ ]# ss -lntp
LISTEN  0.0.0.0:6379                          redis-server   ← ready to accept

[ root@redis ~ ]# ss -tnp
ESTAB   172.31.10.131:6379  172.31.15.50:41234  redis-server
        ↑ me (redis)        ↑ cart, connected to me now
```

| Flag | Meaning |
|------|---------|
| `-l` | **listening** only (drop it → see live connections) |
| `-n` | numbers (`6379`), not names |
| `-t` | TCP |
| `-p` | process name + PID (needs `sudo`) |

> `ss -lntp` does **not** show traffic. It shows which ports are ready to receive it.

---

## 4. All commands: where to run them

| Command | Run on | Answers |
|---------|--------|---------|
| `systemctl status redis` | **target** | Is the service running? |
| `ss -lntp` | **target** | Which ports is it listening on, which address? |
| `ss -tnp` | **target** | Who is connected right now? |
| `lsof -i :6379` | **target** | Which process holds this port? |
| `curl localhost:8080/health` | **target** | Does the app answer on its own server? |
| `journalctl -u redis -f` | **target** | Why did it fail? (live logs) |
| `dig +short redis.abhignadevops.store` | **caller** | Does the name give the right IP? |
| `telnet redis.abhignadevops.store 6379` | **caller** | Can I reach the port? |
| `nc -zv redis.abhignadevops.store 6379` | **caller** | Same, exits by itself (good in scripts) |
| `curl -v http://cart.abhignadevops.store:8080/health` | **caller** | Does the HTTP app answer from outside? |
| `redis-cli -h redis.abhignadevops.store ping` | **caller** | Can I log in and use it? (`PONG`) |
| `ping`, `traceroute` | **caller** | Is the host / path reachable? (ICMP: often blocked in AWS) |

---

## 5. My server's own addresses

| Command | Shows | Example output |
|---------|-------|----------------|
| `ip a` | all network cards and their IPs | `inet 172.31.9.46/20` on `eth0` |
| `ip r` | routing table: the road out | `default via 172.31.0.1 dev eth0` |
| `hostname -I` | **private IP** only | `172.31.9.46` |
| `curl ifconfig.me` | **public IP** (asks an outside site) | `44.203.210.160` |

```
$ ip a
1: lo
    inet 127.0.0.1/8          ← localhost: the server talking to itself
2: eth0
    inet 172.31.9.46/20       ← private IP (inside AWS)

$ ip r
default via 172.31.0.1 dev eth0     ← anything outside my network goes to this gateway
172.31.0.0/20 dev eth0              ← my neighbours (other RoboShop servers): reached directly
```

**Private vs public IP:**

| | Private IP | Public IP |
|--|-----------|-----------|
| Used by | servers inside AWS (cart → redis) | me from my laptop (`ssh`, browser) |
| Seen in `ip a`? | ✅ yes | ❌ **no**: AWS maps it at the edge |
| How to see it | `hostname -I` | `curl ifconfig.me` or the EC2 console |
| After stop/start | stays the same | **changes** |

> `curl ifconfig.me` needs internet access. No public IP / no route out → it hangs.

---

## 6. Old vs new commands

| Old (`net-tools`, often not installed) | New (`iproute2`, always installed) |
|----------------------------------------|------------------------------------|
| `netstat -lntp` | `ss -lntp` |
| `netstat -tnp` | `ss -tnp` |
| `ifconfig` | `ip a` |
| `route -n` | `ip r` |

Same information. Use the new ones. Know the old names for older servers and interviews.

---

## 7. Debug order

"cart can't connect to redis":

```
1. redis: systemctl status redis          → running?
2. redis: ss -lntp | grep 6379            → listening? 0.0.0.0, not 127.0.0.1?
3. cart:  dig +short redis.<domain>       → right IP?
4. cart:  telnet redis.<domain> 6379      → reachable?
            timeout → security group
            refused → service down or 127.0.0.1
5. cart:  redis-cli -h redis.<domain> ping → login works? (PONG)
6. both:  journalctl -u <service>         → the exact error
```

---

## 8. Logs: journalctl vs log files

`journalctl` shows what a service **prints to the screen** (stdout + stderr): normal messages and errors **mixed together**.
Some services write to **their own log files** instead. Those lines are **not** in journalctl.

| Service | `journalctl -u <svc>` shows | Real logs |
|---------|----------------------------|-----------|
| My apps (catalogue, user, cart, shipping, payment) | ✅ **everything**: startup, requests, errors | journal only |
| nginx | ❌ only start / stop / fail | `/var/log/nginx/access.log` + `/var/log/nginx/error.log` |
| MongoDB | ❌ only start / stop | `/var/log/mongodb/mongod.log` |
| MySQL | ❌ only start / stop | `/var/log/mysqld.log` (or `/var/log/mysql/`) |
| Redis | ❌ only start / stop | `/var/log/redis/redis.log` |
| RabbitMQ | ❌ only start / stop | `/var/log/rabbitmq/` |

**Access log vs error log** (web servers like nginx):

| Log | Has | Example line |
|-----|-----|--------------|
| **access.log** | **every request**: who, which URL, status code | `GET /api/catalogue/products 200` |
| **error.log** | **only problems** | `connect() failed (111: Connection refused) while connecting to upstream` |

My apps have **no** separate access / error logs: everything goes to the journal together.

```bash
journalctl -u cart -n 50                # last 50 lines
journalctl -u cart -f                   # follow live (Ctrl+C to stop)
journalctl -u cart --since "10 min ago"
journalctl -u cart | grep -i error      # only error lines

tail -f /var/log/nginx/access.log       # watch requests live
tail -f /var/log/nginx/error.log        # watch nginx errors live
tail -f /var/log/mongodb/mongod.log
```

> `journalctl -p err` often **misses app errors**: most apps print errors as normal output, so systemd doesn't mark them as errors. Use `grep -i error`.

**502 from nginx?** First `/var/log/nginx/error.log` (which backend failed), then that app's `journalctl -u <app>` (why).

```
browser ──▶ nginx ──▶ cart app ──▶ redis
            │          │            │
   access.log +    journalctl    /var/log/redis/
   error.log       -u cart       redis.log
```

---

## 9. Interview Questions

**1. Where do you run `ss -lntp`, and where do you run `telnet`?**
`ss -lntp` on the target, to see that the service is listening. `telnet` on the caller, to see that it can reach the port.

**2. What does `ss -lntp` show?**
Listening TCP ports, the address each is bound to, and the process. It shows open ports, not traffic.

**3. `ss -lntp` vs `ss -tnp`?**
`-lntp` = ports waiting for connections (LISTEN). `-tnp` = active connections now (ESTAB), with the remote IP.

**4. `ss` shows `0.0.0.0:6379`, but telnet from the caller times out. Why?**
The service is fine; something on the path blocks it, usually the target's security group inbound rule.

**5. Telnet says "Connection refused". What do you check?**
On the target: is the service running, and is it bound to `127.0.0.1` instead of `0.0.0.0`?

**6. netstat or ss?**
`ss`: it replaces netstat, is faster, and is installed by default. Same flags, same output.

**7. How do you find a server's private and public IP?**
Private: `hostname -I` or `ip a`. Public on EC2: `curl ifconfig.me` or the console, because it isn't on the network card.

**8. What does `ip r` tell you?**
The routing table. The `default via` line is the gateway for all outside traffic; if it's missing, the server can't reach the internet.

**9. Does `journalctl` show both access and error logs?**
It shows everything a service prints to stdout/stderr, mixed. nginx, MongoDB, MySQL, Redis and RabbitMQ write to their own files under `/var/log/`, so journalctl only shows their start/stop.

**10. nginx access.log vs error.log?**
`access.log` = every request with its status code. `error.log` = only problems, like failing to reach a backend.

**11. Users get a 502. Which logs do you read?**
`/var/log/nginx/error.log` to see which backend failed, then `journalctl -u <app>` on that backend to see why.
