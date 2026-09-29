# Linux Password Management

## Table of Contents

1. [Where Passwords Are Stored](#where-passwords-are-stored)
2. [Setting & Changing Passwords](#setting--changing-passwords)
3. [Account Status & Locking](#account-status--locking)
4. [Generating Passwords & Hashes](#generating-passwords--hashes)
5. [Password Aging (chage)](#password-aging-chage)
6. [System-Wide Defaults (login.defs)](#system-wide-defaults-logindefs)
7. [Password Complexity (pwquality)](#password-complexity-pwquality)
8. [Password History](#password-history)
9. [Lockout After Failed Logins (faillock)](#lockout-after-failed-logins-faillock)
10. [Root Password](#root-password)
11. [Best Practices](#best-practices)
12. [Quick Reference Commands](#quick-reference-commands)
13. [Common Issues & Solutions](#common-issues--solutions)

---

## Where Passwords Are Stored

### /etc/passwd

```text
alice:x:1001:1001:Alice Dev:/home/alice:/bin/bash
```

The `x` means the password hash is stored in `/etc/shadow`. This file is readable by everyone.

### /etc/shadow

Readable only by root.

```bash
sudo grep "^alice:" /etc/shadow

# Output:
# alice:$y$j9T$abc...$xyz...:20000:1:90:14:30::
```

| # | Field | Example | Meaning |
|---|-------|---------|---------|
| 1 | Username | `alice` | Login name |
| 2 | Password hash | `$y$j9T$...` | Hashed password |
| 3 | Last change | `20000` | Days since Jan 1, 1970 |
| 4 | Min age | `1` | Days before password can be changed again |
| 5 | Max age | `90` | Days before password must be changed |
| 6 | Warning | `14` | Days of warning before expiry |
| 7 | Inactive | `30` | Days after expiry before account is disabled |
| 8 | Expire date | (empty) | Account expiry, days since Jan 1, 1970 |
| 9 | Reserved | (empty) | Unused |

### Hash Types

| Prefix | Algorithm | Notes |
|--------|-----------|-------|
| `$1$` | MD5 | Insecure, don't use |
| `$5$` | SHA-256 | |
| `$6$` | SHA-512 | Default on RedHat/CentOS |
| `$y$` | yescrypt | Default on Ubuntu 22.04+ and Debian 11+ |

### Special Values in the Hash Field

| Value | Meaning |
|-------|---------|
| `!` or `!!` at start | Password locked |
| `*` | No password login allowed (system accounts) |
| empty | No password needed (dangerous) |

---

## Setting & Changing Passwords

### Change Your Own Password

```bash
passwd
```

### Set Another User's Password

```bash
sudo passwd username
```

### Set Passwords from a Script

```bash
# One user
echo "username:NewPassw0rd!" | sudo chpasswd

# Many users from a file (format: user:password per line)
sudo chpasswd < users.txt
```

> Passwords typed on the command line end up in shell history. Use a file with `chmod 600` and delete it afterwards, or prefix the command with a space if `HISTCONTROL=ignorespace` is set.

### Set a Pre-Hashed Password

```bash
HASH=$(openssl passwd -6)          # Prompts for password
sudo usermod -p "$HASH" username
```

### Force Change at Next Login

```bash
sudo passwd -e username
# or
sudo chage -d 0 username
```

### Remove a Password (Dangerous)

```bash
sudo passwd -d username
```

User can log in with no password on local consoles. Avoid.

---

## Account Status & Locking

### Check Password Status

```bash
sudo passwd -S username

# Output: username P 2026-09-25 1 90 14 30
```

| Field | Meaning |
|-------|---------|
| `P` | Usable password |
| `L` | Locked |
| `NP` | No password |
| `2026-09-25` | Last change date |
| `1 90 14 30` | Min age, max age, warning, inactive |

### Lock and Unlock

```bash
sudo passwd -l username    # Lock password (adds ! to hash)
sudo passwd -u username    # Unlock
```

> `passwd -l` only blocks password logins. SSH key logins still work. To fully disable an account, also expire it:

```bash
sudo usermod -L -e 1 username   # Lock and expire account
sudo usermod -U -e "" username  # Undo
```

### Status of All Users

```bash
sudo passwd -Sa    # Ubuntu/Debian only
```

---

## Generating Passwords & Hashes

### Generate a Random Password

```bash
openssl rand -base64 18

# Or
pwgen -s 20 1              # sudo apt install pwgen

# Or
tr -dc 'A-Za-z0-9!@#%^&*' < /dev/urandom | head -c 20; echo
```

### Generate a Password Hash

```bash
openssl passwd -6                  # SHA-512, prompts for password
mkpasswd -m yescrypt               # yescrypt (sudo apt install whois)
mkpasswd -m sha-512
```

Useful for cloud-init, Ansible, or kickstart files that need a hashed password.

### Check Password Strength

```bash
echo 'MyPassw0rd!' | pwscore       # sudo apt install libpwquality-tools
```

---

## Password Aging (chage)

### View Aging Info

```bash
sudo chage -l username

# Output:
# Last password change                              : Sep 25, 2026
# Password expires                                  : Dec 24, 2026
# Password inactive                                 : Jan 23, 2027
# Account expires                                   : never
# Minimum number of days between password change    : 1
# Maximum number of days between password change    : 90
# Number of days of warning before password expires : 14
```

### chage Options

| Option | Meaning | Example |
|--------|---------|---------|
| `-M` | Max days before password must change | `chage -M 90 user` |
| `-m` | Min days between changes | `chage -m 1 user` |
| `-W` | Warning days before expiry | `chage -W 14 user` |
| `-I` | Days after expiry before account is disabled | `chage -I 30 user` |
| `-E` | Account expiry date | `chage -E 2027-12-31 user` |
| `-d` | Set last change date (`0` = force change) | `chage -d 0 user` |
| `-l` | List aging info | `chage -l user` |

### Set a Full Policy at Once

```bash
sudo chage -m 1 -M 90 -W 14 -I 30 username
```

### Remove Expiry

```bash
sudo chage -M 99999 -E -1 username
```

### Interactive Mode

```bash
sudo chage username
```

---

## System-Wide Defaults (login.defs)

```bash
grep -E "^(PASS_|ENCRYPT_METHOD|UMASK)" /etc/login.defs
```

```text
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
ENCRYPT_METHOD  YESCRYPT
```

> These only apply to users created **after** the change. Use `chage` for existing users.

### Apply Policy to All Existing Human Users

```bash
for user in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
  sudo chage -m 1 -M 90 -W 14 "$user"
done
```

---

## Password Complexity (pwquality)

### Install

```bash
sudo apt install libpam-pwquality     # Ubuntu/Debian
sudo dnf install libpwquality         # RedHat/CentOS (usually installed)
```

### Configure

```bash
sudo nano /etc/security/pwquality.conf
```

```ini
# Minimum length
minlen = 12
# Require at least 1 digit, 1 uppercase, 1 lowercase, 1 special
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
# Require at least 3 character classes
minclass = 3
# No more than 3 identical characters in a row
maxrepeat = 3
# Reject dictionary words
dictcheck = 1
# Reject passwords containing the username
usercheck = 1
# Apply the rules to root too
enforce_for_root
```

> Keep comments on their own line - pwquality.conf does not support comments after a value.

### Credit Values Explained

| Value | Meaning |
|-------|---------|
| `dcredit = -1` | **Require** at least 1 digit |
| `dcredit = 1` | Each digit counts as 1 extra length toward `minlen` |
| `dcredit = 0` | Digits not required, no bonus |

---

## Password History

Prevents reusing recent passwords.

### RedHat/CentOS 9+

```bash
sudo nano /etc/security/pwhistory.conf
```

```ini
remember = 5
enforce_for_root
```

### Ubuntu/Debian

Add `pam_pwhistory` before `pam_unix` in `/etc/pam.d/common-password`:

```text
password  required  pam_pwhistory.so remember=5 use_authtok
```

> Keep a root shell open in another terminal while editing PAM files. A mistake can lock everyone out.

---

## Lockout After Failed Logins (faillock)

### Configure

```bash
sudo nano /etc/security/faillock.conf
```

```ini
# Lock after 5 failed attempts
deny = 5
# Count failures within 15 minutes
fail_interval = 900
# Unlock automatically after 10 minutes
unlock_time = 600
```

### Enable

```bash
# RedHat/CentOS
sudo authselect enable-feature with-faillock
```

On Ubuntu/Debian, `pam_faillock` must be added to `/etc/pam.d/common-auth` manually. Test in a second session before logging out.

### View and Reset Failures

```bash
sudo faillock --user username            # View failed attempts
sudo faillock --user username --reset    # Unlock user
```

### Check Failed Logins in Logs

```bash
sudo grep "Failed password" /var/log/auth.log    # Ubuntu/Debian
sudo grep "Failed password" /var/log/secure      # RedHat/CentOS
sudo lastb                                        # Bad login attempts
```

---

## Root Password

### Ubuntu: Root Is Locked by Default

```bash
sudo passwd -S root      # Shows L
```

Use `sudo` instead of logging in as root. To enable root login (not recommended):

```bash
sudo passwd root
```

### Lock Root Again

```bash
sudo passwd -l root
```

### Reset a Forgotten Root Password (Physical/Console Access)

1. Reboot and hold `Shift` (BIOS) or press `Esc` (UEFI) to open the GRUB menu.
2. Press `e` on the boot entry.
3. At the end of the line starting with `linux`, add `init=/bin/bash`.
4. Press `Ctrl+X` to boot.
5. Run:

```bash
mount -o remount,rw /
passwd root
sync
exec /sbin/init
```

> On RedHat with SELinux, run `touch /.autorelabel` before `exec /sbin/init`.

---

## Best Practices

1. **Use SSH keys for servers** and set `PasswordAuthentication no` in `/etc/ssh/sshd_config`.
2. **Enforce complexity** with pwquality: minimum 12 characters.
3. **Lock out brute force** with faillock or fail2ban.
4. **Use sudo, not root.** Keep root locked on Ubuntu.
5. **Never store plain-text passwords** in scripts or Git. Use a secrets manager (Vault, AWS Secrets Manager) or Ansible Vault.
6. **Force a change on first login** for new accounts: `sudo chage -d 0 username`.
7. **Expire temporary accounts**: `sudo chage -E 2026-12-31 contractor`.
8. **Audit regularly:**

```bash
# Accounts with empty passwords
sudo awk -F: '$2 == "" {print $1}' /etc/shadow

# Accounts with UID 0 (should only be root)
awk -F: '$3 == 0 {print $1}' /etc/passwd

# Password status of all users
sudo passwd -Sa    # Ubuntu/Debian only
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Change own password | `passwd` |
| Set user's password | `sudo passwd username` |
| Set password in script | `echo "user:pass" \| sudo chpasswd` |
| Force change at next login | `sudo chage -d 0 username` |
| Lock password | `sudo passwd -l username` |
| Unlock password | `sudo passwd -u username` |
| Check status | `sudo passwd -S username` |
| View aging | `sudo chage -l username` |
| Expire every 90 days | `sudo chage -M 90 username` |
| Account expiry date | `sudo chage -E 2027-12-31 username` |
| Generate password | `openssl rand -base64 18` |
| Generate hash | `openssl passwd -6` |
| Reset failed logins | `sudo faillock --user username --reset` |

---

## Common Issues & Solutions

### "Authentication token manipulation error"

```bash
# Root filesystem may be read-only
sudo mount -o remount,rw /

# Check /etc/shadow permissions
ls -l /etc/shadow    # Should be root:shadow 640 (Debian) or root:root 000 (RedHat)
```

### "BAD PASSWORD: The password is shorter than N characters"

The password fails pwquality rules. Choose a stronger password, or check the rules:

```bash
grep -v "^#" /etc/security/pwquality.conf | grep -v "^$"
```

### "You must wait longer to change your password"

The minimum age (`-m`) hasn't passed. As root:

```bash
sudo passwd username
# or
sudo chage -m 0 username
```

### "Your account has expired; please contact your system administrator"

```bash
sudo chage -l username            # Check expiry
sudo chage -E -1 username         # Remove account expiry
sudo chage -d $(date +%F) username  # Reset last-change date if password expired
```

### User Locked Out After Failed Attempts

```bash
sudo faillock --user username --reset
```

---

See also: [User & Password Management](../02-user-password-management/README.md) · [File Permissions](../03-file-permissions/README.md)
