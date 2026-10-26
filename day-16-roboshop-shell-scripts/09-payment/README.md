# 09-payment.sh: Payment Server

[← Day 16 notes](../README.md) · [Common part of every script](../00-common-part.md)

## What this server does

**Payment** is a Python (Flask) app run by **gunicorn**. When I click "Pay", it reads my cart from **cart**, checks me in **user**, and puts the order on the **RabbitMQ** queue. Then it saves the order in my order history (user) and empties my cart (cart).

| Fact | Value |
|------|-------|
| Server | `roboshop-payment` (RHEL 9) |
| Software | Python 3.14 + virtual env + gunicorn |
| Port | 8080 |
| Called by | frontend (`/api/payment/`) |
| Calls | cart (`CART_HOST`), user (`USER_HOST`), rabbitmq (`AMQP_HOST`) |
| SG inbound | 8080 from `roboshop-frontend` |
| Other SGs must allow | cart 8080 + user 8080 + rabbitmq 5672 from `roboshop-payment` |
| Config file I add | `/etc/systemd/system/payment.service` |
| Files used | `09-payment.sh`, `payment.service` |
| Run time | **18 s** (Python install 10 s, venv + `pip install` 7 s) |
| Result | `/health` → `{"app":"OK","rabbitmq":true}`, 3 orders placed from the browser |

```
frontend ──/api/payment/──► PAYMENT :8080
                              ├──► cart:8080      read the cart, then empty it
                              ├──► user:8080      check the user, save the order history
                              └──► rabbitmq:5672  put the order on the "orders" queue ──► dispatch (next)
```

---

## Steps the script does

1. Common part: root check, log file, `timestamp`, `validate`
2. Install **Python 3.14** + pip
3. Create the `roboshop` user (skip if it exists)
4. Clean `/app`, download and unzip the code
5. Create a **virtual environment** in `/app/.venv`
6. `pip install` the libraries into it
7. Copy `payment.service` and put in my domain
8. Start (restart) payment

---

## The code, block by block

### 1. The common part

Same as every script: [00-common-part.md](../00-common-part.md). `scripts_dir` is saved **before** `cd /app`, so `payment.service` is still found later.

### 2. Install Python 3.14

```bash
dnf install python3.14 python3.14-pip -y &>> $logs_file
validate $? "Installing Python 3.14"
```

**Why not the normal `python3`?** RHEL 9's `python3` is **3.9**. The payment app (v4) uses **gunicorn 26**, which needs **Python 3.10 or newer**. RHEL 9 has newer Pythons as separate packages (`python3.12`, `python3.14`...), installed **next to** 3.9 without replacing it.

| Command | Version |
|---------|---------|
| `python3` | 3.9 (system Python, `dnf` itself uses it, don't touch) |
| `python3.14` | 3.14 (the one I install for the app) |

### 3. Create the app user (only if missing)

Same block as catalogue, user, cart, shipping. Explained line by line: [Create the app user](../00-common-part.md#create-the-app-user-every-app-script-catalogue-user-cart-shipping-payment-).

### 4. Fresh app folder + download + unzip

```bash
rm -rf /app
validate $? "Removing old code"

mkdir -p /app
validate $? "creating app directory"

curl -L -o /tmp/payment.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/payment-v4.zip &>> $logs_file
validate $? "Downloading payment"

cd /app
unzip /tmp/payment.zip &>> $logs_file
validate $? "Unzipping payment"
```

**What's in the zip:** `payment.py` (the Flask app), `rabbitmq.py` (sends orders to the queue), `gunicorn.conf.py` (port 8080, 1 worker, 4 threads), `requirements.txt` (the libraries).

### 5. Virtual environment + libraries

```bash
python3.14 -m venv /app/.venv &>> $logs_file
validate $? "Creating virtual environment"

/app/.venv/bin/pip install -r requirements.txt &>> $logs_file
validate $? "Installing dependencies"
```

**Virtual env (venv)** = a private folder with its own Python and its own libraries, just for this app.

| Without venv | With venv (`/app/.venv`) |
|--------------|--------------------------|
| `pip install` puts libraries into the system Python | Libraries stay inside `/app/.venv` |
| Can break `dnf` and other system tools | System Python untouched |
| Two apps needing different versions clash | Each app has its own versions |

`/app/.venv/bin/pip` = the venv's own pip. Using the full path means no `source activate` is needed in a script.

`requirements.txt` = the list of libraries with exact versions: Flask, gunicorn, requests, pika (RabbitMQ), prometheus-client. Like `package.json` for Node or `pom.xml` for Java.

| App | Library list | Install command |
|-----|--------------|-----------------|
| Node.js (catalogue, user, cart) | `package.json` | `npm install` |
| Java (shipping) | `pom.xml` | `mvn clean package` |
| Python (payment) | `requirements.txt` | `pip install -r requirements.txt` |

### 6. Install the service file with my domain

```bash
cp $scripts_dir/payment.service /etc/systemd/system/payment.service
validate $? "Copying payment service"

sed -i "s/DOMAIN_NAME/$domain_name/g" /etc/systemd/system/payment.service
validate $? "Updating domain name in payment service"
```

**Copy first, then `sed` the copy:** the repo file keeps `DOMAIN_NAME`, so `git pull` on the server never conflicts.

### 7. Start payment

```bash
systemctl daemon-reload &>> $logs_file
systemctl enable payment &>> $logs_file
systemctl restart payment &>> $logs_file
validate $? "Starting/Restaring payment"
```

`daemon-reload` reads the new file, `enable` starts it on every boot, `restart` loads the latest code and config.

---

## payment.service, line by line

```ini
[Unit]
Description=Payment Service
After=network-online.target

[Service]
User=roboshop
WorkingDirectory=/app
Environment=CART_HOST=cart.DOMAIN_NAME
Environment=CART_PORT=8080
Environment=USER_HOST=user.DOMAIN_NAME
Environment=USER_PORT=8080
Environment=AMQP_HOST=rabbitmq.DOMAIN_NAME
Environment=AMQP_USER=roboshop
Environment=AMQP_PASS=<password>
ExecStart=/app/.venv/bin/gunicorn --config gunicorn.conf.py --no-control-socket payment:app
SyslogIdentifier=payment
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

| Line | Meaning |
|------|---------|
| `After=network-online.target` | start after the network is up (payment calls 3 servers) |
| `User=roboshop` | run as the app user, not root |
| `WorkingDirectory=/app` | gunicorn looks for `gunicorn.conf.py` and `payment.py` here |
| `CART_HOST` / `CART_PORT` | **outgoing**: where cart is |
| `USER_HOST` / `USER_PORT` | **outgoing**: where user is |
| `AMQP_HOST` | **outgoing**: where RabbitMQ is (AMQP = the protocol RabbitMQ speaks) |
| `AMQP_USER` / `AMQP_PASS` | the RabbitMQ user from `04-rabbitmq.sh` |
| `ExecStart=/app/.venv/bin/gunicorn` | gunicorn **from the venv** (same path as step 5) |
| `--config gunicorn.conf.py` | port 8080, 1 worker, 4 threads |
| `--no-control-socket` | turn off gunicorn's control socket (see below) |
| `payment:app` | file `payment.py`, variable `app = Flask(...)` inside it |
| `Restart=on-failure` + `RestartSec=5` | crashed? systemd restarts it after 5 s |

**Why `--no-control-socket`:** new gunicorn versions open a control socket at `/run/user/<uid>/gunicorn.ctl` (checked in gunicorn 26.2.0 `--help`: *"Disable control socket"*). `roboshop` is a `--system` user with no login session, so that folder may not exist. Payment doesn't need the socket, so I turn it off.

**gunicorn** = the server that runs a Python web app. Flask's own server is for development only; gunicorn handles many requests at once (here 4 threads).

---

## How I ran it

```bash
# laptop
bash roboshop.sh payment
```
```
Creating instance: payment
payment ID: i-089ab4e49b2eb2503
payment IP: 172.31.9.46
DNS updated: payment.abhignadevops.store -> 172.31.9.46
```
`roboshop.sh` uses UPSERT, so the old `payment` record (from an earlier build, pointing to a server that no longer existed) was **updated** to the new IP.

```bash
git add 09-payment.sh payment.service
git commit -m "Add: payment script and service"
git push

# payment server
ssh ec2-user@<payment-public-ip>
sudo su -
dnf install git -y
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v1.git
cd shellscript-roboshop-v1
bash 09-payment.sh
```

## Run + result

```
2026-10-26 13:35:20 [INFO] ==== Script started execution ======
2026-10-26 13:35:30 [INFO] Installing Python 3.14..SUCCESS             ← 10 s
2026-10-26 13:35:30 [INFO] Creating system user..SUCCESS
2026-10-26 13:35:30 [INFO] Removing old code..SUCCESS
2026-10-26 13:35:30 [INFO] creating app directory..SUCCESS
2026-10-26 13:35:30 [INFO] Downloading payment..SUCCESS
2026-10-26 13:35:30 [INFO] Unzipping payment..SUCCESS
2026-10-26 13:35:34 [INFO] Creating virtual environment..SUCCESS
2026-10-26 13:35:37 [INFO] Installing dependencies..SUCCESS            ← venv + pip: 7 s
2026-10-26 13:35:37 [INFO] Copying payment service..SUCCESS
2026-10-26 13:35:37 [INFO] Updating domain name in payment service..SUCCESS
2026-10-26 13:35:38 [INFO] Starting/Restaring payment..SUCCESS
2026-10-26 13:35:38 [INFO] Script completed in 18 seconds
```

**18 s: my fastest app script.** No build step (shipping: Maven 26 s) and no data to load.

```
$ curl http://abhignadevops.store/api/payment/health        # through the frontend
{"app":"OK","rabbitmq":true}
```

**End-to-end test:** placed 3 orders from the browser (2:30:44 PM, 2:31:18 PM, 3:00:15 PM). All 3 show in **Order history**, so payment → cart, user and RabbitMQ all worked.

## Verify

```bash
systemctl status payment --no-pager                 # active (running)
curl localhost:8080/health; echo                    # {"app":"OK","rabbitmq":true}
grep HOST /etc/systemd/system/payment.service       # real domain, no DOMAIN_NAME left
journalctl -u payment -n 30 --no-pager              # app log
```

| `/health` answer | Meaning |
|------------------|---------|
| `200 {"app":"OK","rabbitmq":true}` | app up, RabbitMQ login works |
| `503 {"app":"OK","rabbitmq":false}` | app up, but can't reach or log in to RabbitMQ right now |

---

## Problems I hit

| Problem | Cause | Fix |
|---------|-------|-----|
| Which Python? | RHEL 9 `python3` = 3.9; gunicorn 26 needs ≥ 3.10 | Install `python3.14` next to it + venv |
| Renamed `payment.sh` → `09-payment.sh`, old file still on GitHub | Plain `mv` + `git add 09-payment.sh`: the **delete** was never staged | `git rm payment.sh` → commit → push. Next time `git mv` |
| `bash 09-payment.sh` → "Please run this script with sudo access.." | Ran it on my **laptop**, not the server | SSH to the payment server first. Never `sudo` it on the laptop (`rm -rf /app`, `useradd`) |
| Nearly ran `roboshop.sh payment` a 2nd time | Server already existed | Check first: `aws ec2 describe-instances --filters Name=tag:Name,Values=roboshop-payment`. A 2nd run = a 2nd server (extra cost) |
| `dnf list ... \| grep -E 'python3\.1[0-9] '` printed nothing | Package names are `python3.12.x86_64`: a **dot** after the version, not a space | `grep -E '^python3\.1[0-9]\.'` |
| `/health` once said `"rabbitmq":false` (503), then `true` | The idle RabbitMQ connection had dropped. `healthy()` notices it, answers `false` once and resets; the next call reconnects | Check twice before debugging. Orders were never lost: `publish()` also reconnects |
| Typo `Restaring` in the log | Typo in the `validate` message | Cosmetic, fix to `Restarting` |

---

## Interview questions

**1. Why a virtual environment for a Python app?**
It keeps the app's libraries in its own folder (`/app/.venv`), so they don't change the system Python that `dnf` needs, and each app can have its own versions.

**2. Why not use the default `python3` on RHEL 9?**
It's 3.9. The app's gunicorn 26 needs 3.10+. I install `python3.14` next to it; the system Python stays as it is.

**3. What is gunicorn?**
A production server for Python web apps. Flask's built-in server is for development; gunicorn runs the app with workers and threads. `payment:app` = file `payment.py`, object `app`.

**4. What does `requirements.txt` do?**
Lists the libraries with exact versions. `pip install -r requirements.txt` installs exactly those, so every server gets the same versions.

**5. Payment health said `rabbitmq:false`, then `true`. What happened?**
The idle connection to RabbitMQ had dropped. The health check found the dead connection, answered `false` once and reset it; the next check reconnected. One-off = transient; it stays `false` = real problem (RabbitMQ down, wrong login, SG 5672).

**6. Which security groups must allow payment?**
cart 8080, user 8080 and rabbitmq 5672 must allow inbound from `roboshop-payment`. Payment's own SG allows 8080 from frontend.
