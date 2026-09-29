# Linux Password Management

## Table of Contents

1. [Where Passwords Are Stored](#where-passwords-are-stored)
2. [Setting & Changing Passwords](#setting--changing-passwords)
3. [Lock, Unlock & Status](#lock-unlock--status)
4. [Password Expiry (chage)](#password-expiry-chage)
5. [Password Rules](#password-rules)
6. [Generate a Random Password](#generate-a-random-password)
7. [Best Practices for DevOps](#best-practices-for-devops)
8. [Quick Reference Commands](#quick-reference-commands)
9. [Common Issues & Solutions](#common-issues--solutions)

---

## Where Passwords Are Stored

| File | Contains | Who Can Read |
|------|----------|--------------|
| `/etc/passwd` | User list (`x` = password is in shadow) | Everyone |
| `/etc/shadow` | Hashed passwords + expiry info | Root only |

```text
# /etc/passwd
alice:x:1001:1001:Alice Dev:/home/alice:/bin/bash

# /etc/shadow
alice:$y$j9T$abc...:20000:1:90:14:30::
```

In `/etc/shadow`, a `!` at the start of the hash means the password is locked.

---

## Setting & Changing Passwords

```bash
passwd                      # Change your own password
sudo passwd username        # Set another user's password
```

### Set Password in a Script

```bash
echo "username:NewPassw0rd!" | sudo chpasswd
```

### Force Change at Next Login

```bash
sudo chage -d 0 username
```

Use this for new users so they choose their own password.

---

## Lock, Unlock & Status

```bash
sudo passwd -l username    # Lock password
sudo passwd -u username    # Unlock
sudo passwd -S username    # Check status
```

Status output:

```text
username P 2026-09-25 1 90 14 30
         ^ P = password set, L = locked, NP = no password
```

> `passwd -l` only blocks password login. SSH key login still works.

---

## Password Expiry (chage)

### View Expiry Info

```bash
sudo chage -l username
```

### Common Options

| Option | Meaning | Example |
|--------|---------|---------|
| `-M` | Password expires after N days | `sudo chage -M 90 username` |
| `-W` | Warn N days before expiry | `sudo chage -W 14 username` |
| `-E` | Account expires on a date | `sudo chage -E 2027-12-31 username` |
| `-d 0` | Force change at next login | `sudo chage -d 0 username` |

### Defaults for New Users

Set in `/etc/login.defs`:

```text
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
```

> Only applies to users created after the change. Use `chage` for existing users.

---

## Password Rules

```bash
sudo apt install libpam-pwquality
sudo nano /etc/security/pwquality.conf
```

```ini
# Minimum 12 characters
minlen = 12
# At least 1 digit, 1 uppercase, 1 lowercase, 1 special character
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
```

---

## Generate a Random Password

```bash
openssl rand -base64 16
```

---

## Best Practices for DevOps

1. **Use SSH keys for servers**, not passwords. Disable password login in `/etc/ssh/sshd_config`:

   ```text
   PasswordAuthentication no
   PermitRootLogin no
   ```

   ```bash
   sudo systemctl restart ssh
   ```

2. **Never put passwords in scripts or Git.** Use environment variables, `.env` files (`chmod 600`, added to `.gitignore`), or a secrets manager (AWS Secrets Manager, HashiCorp Vault).
3. **Use `sudo` instead of logging in as root.**
4. **Force new users to change their password** on first login: `sudo chage -d 0 username`.
5. **Set expiry for temporary accounts**: `sudo chage -E 2026-12-31 contractor`.

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Change own password | `passwd` |
| Set user's password | `sudo passwd username` |
| Set password in script | `echo "user:pass" \| sudo chpasswd` |
| Force change at next login | `sudo chage -d 0 username` |
| Lock / unlock | `sudo passwd -l username` / `sudo passwd -u username` |
| Check status | `sudo passwd -S username` |
| View expiry | `sudo chage -l username` |
| Expire every 90 days | `sudo chage -M 90 username` |
| Generate password | `openssl rand -base64 16` |

---

## Common Issues & Solutions

### "BAD PASSWORD: The password is shorter than N characters"

Password doesn't meet the rules in `/etc/security/pwquality.conf`. Choose a longer or stronger password.

### "Your account has expired"

```bash
sudo chage -l username       # Check expiry
sudo chage -E -1 username    # Remove account expiry
```

### "Authentication token manipulation error"

```bash
# Usually a read-only filesystem
sudo mount -o remount,rw /
```

---

See also: [User & Password Management](../02-user-password-management/README.md) · [File Permissions](../03-file-permissions/README.md)
