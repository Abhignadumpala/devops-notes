# Send Gmail from Linux (msmtp)

[← Back to Day 18 notes](../README.md#step-5-set-up-msmtp-email-sender) · used by [mail.sh](mail.sh)

> **In short:** Install **msmtp**, turn on Google **2-Step Verification**, create a Gmail **app password**, put it in `/etc/msmtprc`, and then any script on the server can send email with `... | msmtp <to-address>`. This is what `mail.sh` uses to send the disk usage alert.

```
script (mail.sh) ──► msmtp ──► smtp.gmail.com:587 (TLS) ──► 📧 team inbox
                       │
                 reads /etc/msmtprc (Gmail address + app password)
```

| Term | Definition |
|---|---|
| **SMTP** | the protocol used to **send** email (Simple Mail Transfer Protocol) |
| **msmtp** | a small Linux program that sends email through an SMTP server, like Gmail's |
| **App password** | a 16-character password Google creates **only for one app** (here: msmtp). Not your normal Gmail password |
| **TLS** | encrypts the connection, so the password isn't sent in plain text |

## Step 1: Install msmtp

```bash
sudo dnf install msmtp -y
```

## Step 2: Turn on 2-Step Verification

Google allows app passwords **only if 2-Step Verification is on**.

Google Account → **Security** → **2-Step Verification** → turn it on.

## Step 3: Create an app password

Open:
```
https://myaccount.google.com/apppasswords
```
- Give it a name (e.g. `msmtp-server`) → **Create**.
- Copy the 16-character password. Google shows it **only once**.

## Step 4: Create the global config file

**Definition:** **Global config** = `/etc/msmtprc`, used by **every user** on the server. (A personal one, `~/.msmtprc`, is used only by that user.)

```bash
sudo vi /etc/msmtprc
```
```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-bundle.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           your_email@gmail.com
user           your_email@gmail.com
password       your_app_password

account default : gmail
```

| Line | Means |
|---|---|
| `auth on` | log in to Gmail with user + password |
| `tls on` | encrypt the connection |
| `tls_trust_file` | the certificates file used to trust Gmail (RHEL path; Ubuntu: `/etc/ssl/certs/ca-certificates.crt`) |
| `logfile` | where msmtp writes what it sent (and errors) |
| `account gmail` | a named account block |
| `host` / `port` | Gmail's SMTP server, port **587** |
| `from` / `user` | your Gmail address |
| `password` | the **app password** from Step 3 |
| `account default : gmail` | use the `gmail` account when no account is given |

## Step 5: Set permissions

```bash
sudo chmod 644 /etc/msmtprc
```
`644` = owner can read/write, **everyone can read**. So any user (and any script) on the server can send email.

> ⚠️ **Security:** world-readable also means **any user on the server can read the app password**. Fine for a practice server. On real servers: use a separate Gmail account only for alerts, or `chmod 600` and send only from root (cron jobs run as root). If the password leaks, delete it at the app passwords page and create a new one.

## Step 6: Create the log file

```bash
sudo touch /var/log/msmtp.log
sudo chmod 666 /var/log/msmtp.log
```
`666` = everyone can read and write, so msmtp can write the log **whichever user** sends the email.

## Step 7: Test as any user

```bash
TO_ADDRESS="your_email@gmail.com"
SUBJECT="Test from Linux"
EMAIL_BODY="<h3>Hello</h3><p>msmtp works ✅</p>"

{
echo "To: $TO_ADDRESS"
echo "Subject: $SUBJECT"
echo "Content-Type: text/html"
echo ""
echo "$EMAIL_BODY"
} | msmtp "$TO_ADDRESS"
```

| Line | Means |
|---|---|
| `{ ... }` | group all echos into **one** output |
| `To:` / `Subject:` | email headers |
| `Content-Type: text/html` | the body is HTML (`<h3>`, `<br>` work) |
| `echo ""` | **empty line** = headers end, body starts |
| `\| msmtp "$TO_ADDRESS"` | send it |

Check: the email is in the inbox (or Spam), and the log has a line for it:
```bash
tail /var/log/msmtp.log
```

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `535 ... Username and Password not accepted` | normal Gmail password used, or wrong app password | use the **app password**; check 2-Step Verification is on |
| `TLS certificate verification failed` | wrong `tls_trust_file` path | RHEL: `/etc/ssl/certs/ca-bundle.crt`; Ubuntu: `/etc/ssl/certs/ca-certificates.crt` |
| `cannot log to /var/log/msmtp.log` | log file missing or not writable | Step 6 |
| `msmtp: command not found` | not installed (or cron's PATH) | Step 1; in cron use `/usr/bin/msmtp` |

> 🔒 Never push `/etc/msmtprc` or the app password to GitHub. In notes, keep `your_app_password`.

## Interview one-liners

- **msmtp** sends email from the command line through an SMTP server (Gmail: `smtp.gmail.com:587`, TLS).
- Gmail needs an **app password** (2-Step Verification on), not the normal password.
- `/etc/msmtprc` = global config for all users; `~/.msmtprc` = only one user.
- An email = **headers** (`To`, `Subject`, `Content-Type`) + **empty line** + **body**.
