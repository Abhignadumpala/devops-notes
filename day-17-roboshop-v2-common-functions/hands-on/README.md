# Day 17 - Hands-On: Building RoboShop v2 (MySQL → Payment)

[← Back to Day 17 notes](../README.md) · [Troubleshooting](../troubleshooting/README.md)

**Definition:** *hands-on* = what I actually ran, in order, with screenshots of the real output.

Day 2 of RoboShop v2 (2026-10-28). I started the stopped servers, then built **mysql, rabbitmq, catalogue, user, cart, shipping, payment and frontend** with my v2 scripts, and placed a real order through `abhignadevops.store`. Each server: `git clone` → `bash 0X-<name>.sh` → check.

## Table of Contents

1. [Result](#result)
2. [03 - MySQL](#03---mysql)
3. [04 - RabbitMQ: missing repo file](#04---rabbitmq-missing-repo-file)
4. [05-07 - Catalogue, User, Cart: missing service files](#05-07---catalogue-user-cart-missing-service-files)
5. [08 - Shipping: the long one](#08---shipping-the-long-one)
6. [09 - Payment](#09---payment)
7. [10 - Frontend](#10---frontend)
8. [End-to-end order](#end-to-end-order)
9. [What I learned](#what-i-learned)

---

## Result

| # | Server | Script time | Problems on the way | Check |
|---|---|---|---|---|
| 03 | mysql | **25 s** | `systemctl status mysql` → wrong name (`mysqld`) | `*:3306` mysqld |
| 04 | rabbitmq | **181 s** | `rabbitmq.repo` not pushed | 5 steps SUCCESS |
| 05 | catalogue | **58 s** | `catalogue.service` not pushed | products loaded |
| 06 | user | **26 s** | `user.service` not pushed | SUCCESS |
| 07 | cart | **29 s** | - | `*:8080`, → redis:6379 |
| 08 | shipping | **33 s** (final run) | Maven TLS error, app TLS error, MySQL blocked host | `/actuator/health` → `UP`, db `UP` |
| 09 | payment | **94 s** | - | `{"app":"OK","rabbitmq":true}` |
| 10 | frontend | **94 s** | - | all 5 `/api/*/health` → 200 through Nginx |
| - | **order** | - | order without an account → empty history (`/check` 404) | order `#a2a4de95` in history ✅ |

## 03 - MySQL

```bash
bash 03-mysql.sh      # 3 steps SUCCESS, 25 seconds
```
![03-mysql.sh success](images/03-mysql-script-success.png)

`systemctl status mysql` → `Unit mysql.service could not be found`. The service is **`mysqld`**; `mysql` is the client.

![mysqld running and listening on 3306](images/03-mysql-mysqld-status-ss.png)

## 04 - RabbitMQ: missing repo file

First run stopped at step 1: `cp: cannot stat 'rabbitmq.repo'`. My `validate` printed FAILED and ran `exit 1`, so nothing else ran.

![rabbitmq cannot stat repo](images/04-rabbitmq-cannot-stat-repo-failed.png)

Fix: add `rabbitmq.repo` on the laptop → push → `git pull` on the server → run again. All SUCCESS in **181 s**.

![rabbitmq fixed](images/04-rabbitmq-pull-fix-success.png)

Details: [troubleshooting #1-3](../troubleshooting/README.md#1-cannot-stat-rabbitmqrepo-validate-stopped-the-script)

## 05-07 - Catalogue, User, Cart: missing service files

Created three servers in one command (laptop). `roboshop.sh` also updates each DNS record:
```bash
bash roboshop.sh catalogue user cart
```
![roboshop.sh catalogue user cart](images/05-07-roboshop-sh-catalogue-user-cart.png)

**Same mistake again:** I pushed the scripts but not the `.service` files (still red under *Untracked files*).

![git push without service files](images/05-08-git-push-without-service-files.png)

Catalogue and user stopped at `copying ... service..FAILED`:

![catalogue cannot stat service](images/05-catalogue-cannot-stat-service-failed.png)
![user cannot stat service](images/06-user-cannot-stat-service-failed.png)

Fix: push all four `.service` files, `git pull`, run again:

![push service files](images/05-08-git-push-service-files.png)
![catalogue fixed](images/05-catalogue-pull-fix-success.png)
![user fixed](images/06-user-pull-fix-success.png)

On the rerun: `system user roboshop already exist...SKIPPING`, which is the idempotent check in `app_setup`.

Cart had the files from the start (cloned after the push): all SUCCESS in **29 s**, listening on `*:8080`.

![cart success](images/07-cart-success-ss.png)

**Lesson:** before every push, `git status` → nothing my scripts use may be red.

## 08 - Shipping: the long one

![Shipping error chain](../images/01-shipping-error-chain.svg)

**Step 1: MySQL part added.** My first `08-shipping.sh` didn't load the database. I added: install MySQL client → load `master-data.sql` (only if `cities` is empty) → `app-user.sql`.

**Step 2: Maven failed.**

![mvn failed](images/08-shipping-mvn-failed.png)

The screen only says FAILED, so I read the log:
```bash
tail -50 /var/log/roboshop/08-shipping.sh.log
```
![X25519MLKEM768 in the Maven log](images/08-shipping-mvn-x25519mlkem768-log.png)

`Could not generate keypair for algorithm: X25519MLKEM768`: Java couldn't finish the HTTPS handshake, so Maven couldn't download Spring Boot.

**Step 3: fix for Maven** in `08-shipping.sh` (not in `common.sh`):

![MAVEN_OPTS line](images/08-shipping-mysql-part-maven-opts.png)
![push MAVEN_OPTS fix](images/08-shipping-maven-opts-push.png)

Build passed. The service started… but port 8080 never opened, and `curl` gave `Connection refused`.

**Step 4: the app had the same TLS error** (to MySQL). systemd kept restarting it every 5 s; the log stopped at `HikariPool-1 - Starting...` each time:

![shipping restart loop](images/08-shipping-app-restart-loop-hikari.png)

Fix for the running app: the flag goes **before `-jar`** in `shipping.service`:

![ExecStart fix](images/08-shipping-service-execstart-fix.png)
![push service fix](images/08-shipping-service-fix-push.png)

**Step 5: MySQL had blocked shipping.** All those failed restarts → `ERROR 1129: Host '172.31.14.32' is blocked`. Unblocking on the mysql server: local root has **no password** (`-p<mysql-root-password>` → Access denied, plain `mysql -uroot` → works):

![root no password, unblock](images/08-mysql-root-no-password-unblock.png)

**Step 6: final run.** `systemctl stop shipping` → `bash 08-shipping.sh`: `Master data already loaded...SKIPPING`, all SUCCESS in **33 s**:

![blocked, then success](images/08-shipping-blocked-then-success.png)
![shipping health UP](images/08-shipping-health-up.png)

`/actuator/health` → `"db":{"status":"UP"}`, `"status":"UP"`.

Details: [troubleshooting #7, #9, #10, #11](../troubleshooting/README.md#7-shipping-mvn-fails-x25519mlkem768-keypair-not-available)

## 09 - Payment

Python 3.14 + venv + gunicorn. All SUCCESS in **94 s**, listening on `0.0.0.0:8080` (two gunicorn PIDs = master + worker):

![payment success](images/09-payment-success-ss.png)

`curl localhost:8080/health` → `{"app":"OK","rabbitmq":true}`, and the log shows `connected to broker`:

![payment health](images/09-payment-health-rabbitmq.png)

## 10 - Frontend

```bash
bash roboshop.sh frontend      # laptop: frontend gets the PUBLIC IP → root record abhignadevops.store
bash 10-frontend.sh            # on frontend: Nginx + frontend code + roboshop.conf, 94 s
```
![frontend script](images/10-frontend-script-success.png)

**Checks, layer by layer** (on frontend):

| Layer | Command | Proves |
|---|---|---|
| TCP | `telnet catalogue.abhignadevops.store 8080` → `Connected` | DNS + SG + listening |
| HTTP | `curl -v http://cart.abhignadevops.store:8080/health` | the app answers: `200`, `{"app":"OK","redis":true}` |
| Through Nginx | `curl localhost/api/cart/health` | Nginx `proxy_pass` → cart works |

![curl -v cart](images/10-frontend-curl-v-cart.png)

Reading `curl -v`: `*` = curl info (`Trying` = DNS done, `Connected` = TCP done), `>` = request sent, `<` = response (`200 OK`), then the body.

From my laptop all `/api/{catalogue,user,cart,shipping}/health` → 200 at once; payment gave **one 503**, then 5/5 × 200 (RabbitMQ check briefly false, same as in v1).

## End-to-end order

![home page](images/web-01-home.png)

Shipping: Portugal → Lamego, **1,597 km → €79.85** (shipping → MySQL cities):

![shipping](images/web-02-shipping-portugal.png)

**First order: confirmed, but history empty.**

![order confirmed, no account](images/web-03-order-confirmed-no-account.png)
![history empty](images/web-04-history-empty-no-account.png)

Debugged hop by hop with the order id and `requestId`:
```bash
# payment
journalctl -u payment | grep bf86d10b
#  → "order ... queued", "order ... placed", requestId c6143973...

# user: follow the same requestId
journalctl -u user | grep c6143973be706228a567f5e4270470c5
#  → GET /check/abhigna 404
```
`404` = **user doesn't exist**. I hadn't registered in v2 (new MongoDB); the browser still showed my name from the v1 site on the same domain. Payment treats an unknown user as a guest: it queues the order but never calls `POST /order/<user>`, so nothing is saved. Details: [troubleshooting #12](../troubleshooting/README.md#12-order-confirmed-but-order-history-empty-check-404).

**Fix:** sign out → register → order again. Order `a2a4de95`, €379.85, now in history:

![order confirmed](images/web-05-order-confirmed.png)
![order history](images/web-06-order-history.png)

**The whole chain works:** Route 53 → frontend (Nginx) → user (MongoDB + Redis) → catalogue (MongoDB) → cart (Redis) → shipping (MySQL) → payment → user (save order) + RabbitMQ.

Not built in v2: **dispatch**, so paid orders stay in the RabbitMQ `orders` queue (`rabbitmqctl list_queues`).

## What I learned

- **Same script, new packages, new errors:** v1 shipping built fine two weeks ago; v2 broke on a fresh server because `dnf` installed newer RHEL 9.8 crypto packages.
- **Read the log, not the screen.** `FAILED` only tells me *where*; `/var/log/roboshop/<script>.log` and `journalctl -u <app>` tell me *why*.
- **One root cause can fail in two places:** Maven's Java (build) and the app's Java (run) are separate processes, so each needs its own flag.
- **Restart loops have side effects:** `Restart=on-failure` + a failing DB connection → MySQL blocked the host.
- **Three kinds of problems:** network (SG/DNS → timeout, NXDOMAIN), service (down → refused, 5xx), **data** (`404` user not found). All looked like "it doesn't work" in the browser.
- **`requestId` is a tracking number across services:** grep it in each service's log to follow one click hop by hop.
- **`git status` before push.** I forgot files twice (`rabbitmq.repo`, the `.service` files); `validate` caught it both times.
