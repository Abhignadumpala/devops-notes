# Day 5 - Key-Based Auth, Offboarding, Packages, Services, Network & Processes

## Table of Contents

1. [Quick Recap - Vim & Users](#quick-recap---vim--users)
2. [Key-Based Authentication Setup](#key-based-authentication-setup)
3. [Employee Offboarding](#employee-offboarding)
4. [find Command](#find-command)
5. [Package Management](#package-management)
6. [Service Management](#service-management)
7. [Network Management](#network-management)
8. [Process Management](#process-management)
9. [Troubleshooting Checklist](#troubleshooting-checklist)
10. [Command Cheat Sheet](#command-cheat-sheet)
11. [Interview Questions](#interview-questions)

---

## Quick Recap - Vim & Users

Full details in [Day 4](../day-04-vim-users-permissions/README.md).

| Vim | Action |
|-----|--------|
| `:wq` / `:q!` | Save & quit / quit without saving |
| `:3` / `:3d` / `:4,5d` / `:%d` | Go to line 3 / delete line 3 / delete 4-5 / delete all |
| `:%s/old/new/g` | Replace in whole file |
| `u` / `Ctrl+r` | Undo / redo |
| `yy` / `dd` / `p` | Copy / cut / paste |
| `gg` / `Shift+g` | Top / bottom |

| User Command | Action |
|--------------|--------|
| `usermod -g devops ramesh` | Set devops as **primary** group |
| `usermod -aG testers ramesh` | **Append** testers as secondary group |
| `gpasswd -d ramesh testers` | Remove from testers |
| `passwd ramesh` | Set password |

---

## Key-Based Authentication Setup

### On ramesh's Laptop

```bash
ssh-keygen -f ramesh
# creates: ramesh (private key) and ramesh.pub (public key)
```

ramesh sends **only `ramesh.pub`** to the admin.

A public key looks like:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@laptop
```

### On the Server (Admin)

```bash
sudo useradd ramesh
sudo mkdir /home/ramesh/.ssh
sudo vim /home/ramesh/.ssh/authorized_keys        # paste ramesh's public key

sudo chown -R ramesh:ramesh /home/ramesh/.ssh     # .ssh must be owned by ramesh
sudo chmod 700 /home/ramesh/.ssh                  # max 700
sudo chmod 600 /home/ramesh/.ssh/authorized_keys  # max 600
```

| Path | Owner | Max Permission |
|------|-------|----------------|
| `/home/ramesh/.ssh` | ramesh | `700` |
| `/home/ramesh/.ssh/authorized_keys` | ramesh | `600` |

> If permissions are looser than this, SSH refuses the key.

### ramesh Logs In

```bash
ssh -i ramesh ramesh@<public-ip>
pwd
# /home/ramesh
```

---

## Employee Offboarding

When an employee leaves the organisation, in this order:

| # | Step | Command |
|---|------|---------|
| 1 | Lock the account immediately | `sudo usermod -e 1 ramesh` |
| 2 | Kill existing sessions | `sudo pkill -u ramesh` |
| 3 | Remove from all groups | `sudo gpasswd -d ramesh wheel`<br>`sudo usermod -g ramesh ramesh` |
| 4 | Backup home folder | `sudo tar -czvf /backup/ramesh-offboarding-backup.tar.gz /home/ramesh/` |
| 5 | Find his other files, back them up | `sudo find / -user ramesh` |
| 6 | Delete the user | `sudo userdel ramesh` |

- `usermod -e 1` sets the account expiry to 1 day after Jan 1, 1970 → account is expired, cannot log in.
- `usermod -g ramesh ramesh` resets his primary group back to his own group.
- `tar -v` = verbose (shows files as they are added).

---

## find Command

```text
find <where-to-search> <options> <what-to-search>
```

`/` = root directory (search the whole system).

```bash
find / -name "*.log"               # all .log files
find / -name "*sswd*"              # names containing "sswd" (passwd, gshadow...)
find / -type d -name "ramesh"      # only directories named ramesh
find / -type f -name "*.conf"      # only files
find / -user ramesh                # files owned by ramesh
```

| Option | Meaning |
|--------|---------|
| `-name` | Match file name (`*` = anything) |
| `-type f` | Files only |
| `-type d` | Directories only |
| `-user` | Owned by a user |

Add `2>/dev/null` to hide "Permission denied" errors: `find / -name "*.log" 2>/dev/null`

---

## Package Management

Linux servers are connected to package repositories (URLs on the internet) to download software and updates.

| OS | Package Manager |
|----|-----------------|
| RHEL 8+ / Amazon Linux 2023 | `dnf` |
| Older RHEL / CentOS 7 | `yum` (now a link to `dnf`) |
| Ubuntu / Debian | `apt` / `apt-get` |

```bash
sudo dnf install nginx -y      # install (-y = don't ask for confirmation)
sudo dnf remove nginx -y       # remove
sudo dnf update nginx -y       # update one package
sudo dnf search nginx          # search
dnf list installed             # list installed packages
```

---

## Service Management

A **service** is a program that runs continuously in the background.

Examples:
- `sshd` - SSH service, always running so we can log in
- `nginx` - web/HTTP server (Apache HTTP is the older one)

> Linux = the **physical** server. Nginx = a **logical** server (service) running inside Linux.

```bash
sudo systemctl start nginx      # start
sudo systemctl stop nginx       # stop
sudo systemctl restart nginx    # restart
sudo systemctl status nginx     # check if running
sudo systemctl enable nginx     # start automatically when server boots
sudo systemctl disable nginx    # don't start on boot
```

| | start | enable |
|---|-------|--------|
| Effect | Runs **now** | Runs **after every reboot** |

---

## Network Management

Ports: `0` to `65535`. Each service listens on a port.

| Service | Port |
|---------|------|
| SSH | 22 |
| SMTP (email) | 25 |
| DNS | 53 |
| HTTP | 80 |
| HTTPS | 443 |
| MySQL | 3306 |
| Backend apps / Jenkins | 8080 |

### Check Open Ports

```bash
sudo netstat -lntp
```

| Option | Meaning |
|--------|---------|
| `-l` | Listening |
| `-n` | Show numbers (not names) |
| `-t` | TCP |
| `-p` | Show process name / PID |

If `netstat` isn't installed: `sudo dnf install net-tools -y`, or use `sudo ss -lntp` (same output, pre-installed).

### Test Nginx

```bash
sudo dnf install nginx -y
sudo systemctl start nginx
```

Open `http://<public-ip>` in a browser. Security group must allow **port 80** inbound.

---

## Process Management

**Everything in Linux is a process.** Running `cat devops.txt` creates a process, runs it, and completes it.

Every process has:
- **PID** - Process ID
- **PPID** - Parent Process ID (the process that started it)

### Parent-Child Analogy

```text
TL (ID 1) → SE (ID 2) → JE (ID 3) → Fresher (ID 4)
```

Fresher (4) is the **child**, JE (3) is its **parent**.

### View Processes

```bash
ps                  # processes started by current user in this terminal
ps -ef              # all running processes on the server
ps -ef | grep nginx # find a specific process
```

### Foreground vs Background

| Type | Behaviour | Example |
|------|-----------|---------|
| Foreground | Terminal is busy until it finishes | `sleep 60` |
| Background | Runs behind; terminal is free | `sleep 60 &` |

```bash
sleep 60 &     # run in background
jobs           # list background jobs
fg             # bring back to foreground
```

### Stop a Process

```bash
kill <PID>        # ask the process to stop
kill -9 <PID>     # force kill
```

---

## Troubleshooting Checklist

App not working? Check in this order:

| # | Check | Command |
|---|-------|---------|
| 1 | Service is running | `systemctl status nginx` |
| 2 | Port is open | `netstat -lntp` |
| 3 | Process is running | `ps -ef \| grep nginx` |
| 4 | Security group allows the port | AWS console |
| 5 | Logs | `journalctl -u nginx` or `/var/log/nginx/` |

---

## Command Cheat Sheet

| Command | Use |
|---------|-----|
| `ssh-keygen -f name` | Generate key pair |
| `usermod -e 1 user` | Expire (lock) account |
| `pkill -u user` | Kill user's processes |
| `tar -czvf` | Backup to archive |
| `find / -user user` | Find user's files |
| `userdel user` | Delete user |
| `dnf install/remove/update/search` | Manage packages |
| `systemctl start/stop/restart/status/enable/disable` | Manage services |
| `netstat -lntp` | Open ports |
| `ps -ef` | All processes |
| `sleep 60 &` | Background process |
| `kill PID` | Stop process |

---

## Interview Questions

**1. How do you set up key-based login for a new user?**

User generates keys and sends the public key → admin creates the user → creates `/home/user/.ssh/authorized_keys` and pastes the key → `chown` to the user → `.ssh` 700, `authorized_keys` 600.

**2. Why must `.ssh` be 700 and `authorized_keys` 600?**

SSH refuses keys if other users could read or change them - it's a security check.

**3. An employee leaves the company. What do you do?**

Lock the account (`usermod -e 1`), kill sessions (`pkill -u`), remove from groups (`gpasswd -d`), back up home folder (`tar`), find other files (`find / -user`), then delete (`userdel`).

**4. How to find files by name, type, owner or size?**

`find / -name "*.log"`, `find / -type d -name app`, `find / -user ramesh`, `find / -size +100M`.

**5. `yum` vs `dnf` vs `apt`?**

`yum` - older RHEL. `dnf` - newer RHEL (yum now points to dnf). `apt` - Ubuntu/Debian.

**6. What is a service?**

A program that runs continuously in the background (daemon), e.g. `sshd`, `nginx`. Managed with `systemctl`.

**7. `systemctl start` vs `enable`?**

`start` runs it now. `enable` makes it start automatically on every boot. Usually do both.

**8. How do you check which ports are open or which process uses port 8080?**

`netstat -lntp` or `ss -lntp`; add `| grep 8080`.

**9. Common ports?**

SSH 22, SMTP 25, DNS 53, HTTP 80, HTTPS 443, MySQL 3306, Jenkins/backend apps 8080.

**10. What is a process, PID and PPID?**

A process is a running program. PID = its ID, PPID = the ID of the parent process that started it.

**11. How to see all running processes?**

`ps -ef` (filter with `| grep nginx`).

**12. Foreground vs background process?**

Foreground blocks the terminal until done. Background runs behind with `&` (`sleep 60 &`); see with `jobs`, bring back with `fg`.

**13. `kill` vs `kill -9`?**

`kill PID` asks the process to stop gracefully. `kill -9 PID` force-kills it immediately.

**14. Application is not accessible. How do you troubleshoot?**

Check service status → port listening → process running → security group allows the port → logs (`journalctl -u <service>`).
