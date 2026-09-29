# Day 4 - Vim, User Management, Permissions & Sudo

## Table of Contents

1. [Vim Editor](#vim-editor)
2. [Users & Groups](#users--groups)
3. [Authentication vs Authorization](#authentication-vs-authorization)
4. [Creating & Managing Users](#creating--managing-users)
5. [Important Files](#important-files)
6. [Permissions](#permissions)
7. [Ownership](#ownership)
8. [Admin (Sudo) Access](#admin-sudo-access)
9. [SSH Password Login](#ssh-password-login)
10. [Key-Based Authentication](#key-based-authentication)
11. [Command Cheat Sheet](#command-cheat-sheet)
12. [Interview Questions](#interview-questions)

---

## Vim Editor

Vim has 3 modes:

| Mode | How to Enter | Used For |
|------|--------------|----------|
| Esc (Normal) mode | Press `Esc` | Navigate, copy, paste, undo |
| Insert mode | Press `i` | Type text |
| Colon (Command) mode | Press `:` from Esc mode | Save, quit, search, replace, delete lines |

### Colon Mode

| Command | Action |
|---------|--------|
| `:w` | Save (write) |
| `:q` | Quit |
| `:wq` | Save and quit |
| `:q!` | Force quit without saving |
| `:set nu` | Show line numbers |
| `:set nonu` | Hide line numbers |
| `:<line-number>` | Go to that line (e.g. `:10`) |
| `:noh` | Remove search highlighting |

### Search

| Command | Action |
|---------|--------|
| `/word` | Search forward (`n` = next match) |
| `?word` | Search backward |

### Delete Lines

| Command | Action |
|---------|--------|
| `:2d` | Delete line 2 |
| `:5,10d` | Delete lines 5 to 10 |
| `:%d` | Delete entire content |

### Find & Replace

```text
:<range>s/<find>/<replace>/<flags>
```

| Command | Action |
|---------|--------|
| `:3s/sbin/SBIN` | Line 3, **first** match only |
| `:3s/sbin/SBIN/g` | Line 3, **all** matches |
| `:%s/sbin/SBIN` | Every line, first match in each line |
| `:%s/sbin/SBIN/g` | Every line, all matches (whole file) |

- `%` = all lines
- `g` = global (all matches in the line)

### Esc Mode

| Command | Action |
|---------|--------|
| `gg` | Go to top of file |
| `Shift+g` (`G`) | Go to bottom of file |
| `u` | Undo |
| `Ctrl+r` | Redo |
| `yy` | Copy current line |
| `p` | Paste |
| `10p` | Paste 10 times |
| `dd` | Cut (delete) current line |

---

## Users & Groups

### Prompt Symbol

| Symbol | User |
|--------|------|
| `$` | Normal user |
| `#` | Root user |

### Home Folders

| User | Home |
|------|------|
| root | `/root` |
| Normal user | `/home/<user-name>` (e.g. `/home/ec2-user`) |

### User vs Group

- **User** = one human (or application)
- **Group** = a list of users. One group can have many users.

---

## Authentication vs Authorization

| | Question | Example |
|---|----------|---------|
| **Authentication** | Who are you? (prove yourself) | Username + password / SSH key |
| **Authorization** | Do you have access to this resource? | Can you delete this file? |

### Role-Based Access

Permissions are given to **roles** (groups), and users are added to groups.

| Role | Group | Permissions |
|------|-------|-------------|
| Trainee | `devops-trainees` | Read |
| Junior | `devops-juniors` | Read, Write |
| Senior | `devops-seniors` | Read, Write, Update |
| Team Lead | `devops-lead` | Read, Write, Update, Delete |

When `ramesh` joins as a trainee → add him to `devops-trainees`. When promoted → move him to the next group. No need to change permissions one by one.

---

## Creating & Managing Users

### Create a User

```bash
sudo useradd ramesh
id ramesh

# uid=1001(ramesh) gid=1001(ramesh) groups=1001(ramesh)
```

- Linux automatically creates a **group with the same name** as the user.
- UID `0` = root user.

### Primary vs Secondary Groups

A user has **exactly 1 primary group** and **0 or more secondary groups**.

```bash
sudo groupadd devops
sudo groupadd sre

sudo usermod -g devops ramesh      # set devops as PRIMARY group
sudo usermod -aG sre ramesh        # add sre as SECONDARY group

id ramesh
# uid=1001(ramesh) gid=1002(devops) groups=1002(devops),1003(sre)
```

| Option | Meaning |
|--------|---------|
| `-g` (small) | Set primary group |
| `-G` (capital) | Secondary groups |
| `-a` | Append - keep existing secondary groups |

> Always use `-aG` together. `-G` without `-a` removes the user from all other secondary groups.

### Remove User from a Group

```bash
sudo gpasswd -d ramesh devops
```

### Set Password

```bash
sudo passwd ramesh
```

---

## Important Files

| File | Stores |
|------|--------|
| `/etc/passwd` | User info |
| `/etc/group` | Group info |
| `/etc/ssh/sshd_config` | SSH configuration |
| `/etc/sudoers` | Main sudo configuration |
| `/etc/sudoers.d/<user>` | Extra sudo configuration per user (e.g. `/etc/sudoers.d/ramesh`) |

---

## Permissions

| Permission | Letter | Value |
|------------|--------|-------|
| Read | `r` | 4 |
| Write | `w` | 2 |
| Execute | `x` | 1 |

```text
-rw-r--r--
│└┬┘└┬┘└┬┘
│ │  │  └── o = Others: r--
│ │  └───── g = Group:  r--
│ └──────── u = Owner:  rw-
└────────── - = file (d = directory)
```

> Only the **owner** of the file or **root** can change its permissions.

### Symbolic

```bash
chmod u+x devops.txt      # add execute for owner
chmod g-w devops.txt      # remove write from group
chmod o+r devops.txt      # add read for others
```

### Numeric

Example: owner = rwx, group = r-x, others = --x

| | Owner | Group | Others |
|---|-------|-------|--------|
| Permission | rwx | r-x | --x |
| Value | 4+2+1 = **7** | 4+1 = **5** | 1 = **1** |

```bash
chmod 751 devops.txt
```

---

## Ownership

> Only **root** can change the owner of a file - not even the file's owner.

```bash
sudo chown ramesh:devops devops.txt       # file
sudo chown -R ramesh:devops /app          # folder and everything inside
```

---

## Admin (Sudo) Access

### Option 1: Add to wheel Group

On RHEL / Amazon Linux, the `wheel` group has sudo access.

```bash
sudo usermod -aG wheel ramesh         # give admin access
sudo gpasswd -d ramesh wheel          # remove admin access
```

### Option 2: /etc/sudoers.d File (Recommended)

Don't edit the main `/etc/sudoers`. Create a separate file per user:

```bash
sudo vim /etc/sudoers.d/ramesh
```

Pick one:

```text
# Full sudo access (same as adding to wheel group)
ramesh  ALL=(ALL:ALL) ALL

# Full sudo access, don't ask for password
ramesh  ALL=(ALL:ALL) NOPASSWD:ALL

# Only specific commands, no password
ramesh  ALL=(ALL:ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/usermod
```

Check the syntax (a broken sudoers file can block all sudo access):

```bash
sudo visudo -c
```

### Reading a Sudoers Line

```text
ramesh   ALL  =  (ALL:ALL)  NOPASSWD:  ALL
  │       │        │            │        │
 user   hosts  run as user:group │     commands
                          no password
```

---

## SSH Password Login

By default, cloud servers allow only key login. To allow password login:

```bash
sudo vim /etc/ssh/sshd_config
```

```text
PasswordAuthentication yes
```

```bash
sudo sshd -t                     # check syntax (no output = OK)
sudo systemctl restart sshd      # apply
```

Now: `ssh ramesh@<public-ip>` asks for ramesh's password.

---

## Key-Based Authentication

Steps (details in [Day 5](../day-05-users-packages-services-processes/README.md#key-based-authentication-setup)):

1. **ramesh** generates a key pair on his laptop.
2. ramesh sends his **public key** to the admin.
3. Admin adds the public key into ramesh's home folder on the server (`/home/ramesh/.ssh/authorized_keys`).
4. ramesh logs in:

```bash
ssh -i ramesh-private-key ramesh@<public-ip>
```

---

## Command Cheat Sheet

| Command | Use |
|---------|-----|
| `useradd ramesh` | Create user |
| `id ramesh` | User's UID, GID and groups |
| `usermod -g devops ramesh` | Set primary group |
| `usermod -aG sre ramesh` | Add secondary group |
| `gpasswd -d ramesh devops` | Remove from group |
| `passwd ramesh` | Set password |
| `chmod 751 file` | Change permissions |
| `chown user:group file` | Change ownership |
| `usermod -aG wheel ramesh` | Give sudo access |
| `visudo -c` | Check sudoers syntax |
| `sshd -t` | Check SSH config syntax |
| `systemctl restart sshd` | Restart SSH |

---

## Interview Questions

**1. Authentication vs Authorization?**

Authentication = who are you (password/key). Authorization = what are you allowed to do (permissions/roles).

**2. What happens when you run `useradd ramesh`?**

Creates the user with a new UID, a group with the same name (primary group), an entry in `/etc/passwd`, `/etc/shadow` and `/etc/group`, and (on RHEL) a home folder `/home/ramesh`.

**3. Primary vs secondary group?**

Every user has exactly **one** primary group (owns new files the user creates) and **zero or more** secondary groups (give extra access).

**4. `usermod -g` vs `-G` vs `-aG`?**

`-g` sets the primary group. `-G` sets secondary groups and **removes** all others. `-aG` **appends** a secondary group and keeps existing ones - always use `-aG`.

**5. How to remove a user from a group?**

`gpasswd -d ramesh devops`.

**6. What does `chmod 751` mean?**

Owner `rwx` (7), group `r-x` (5), others `--x` (1). r=4, w=2, x=1.

**7. Common permissions - 644, 755, 600, 700?**

644 = files, 755 = scripts/folders, 600 = private files/SSH keys, 700 = private folders like `~/.ssh`.

**8. Who can change permissions and who can change ownership?**

Permissions (`chmod`) - the file owner or root. Ownership (`chown`) - only root.

**9. How do you give a user sudo access?**

Add to the `wheel` group (RHEL) / `sudo` group (Ubuntu): `usermod -aG wheel ramesh`. Or create `/etc/sudoers.d/ramesh` with `ramesh ALL=(ALL:ALL) ALL`.

**10. Why use `/etc/sudoers.d/` instead of editing `/etc/sudoers`?**

Main file stays untouched, access is easy to remove per user (delete one file), and it's easy to automate with tools like Ansible.

**11. How to allow a user to run only specific commands with sudo?**

`ramesh ALL=(ALL:ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/usermod` in `/etc/sudoers.d/ramesh`.

**12. How do you check sudoers and SSH config syntax?**

`visudo -c` for sudoers, `sshd -t` for SSH. Always check before restarting - a broken file can lock you out.

**13. How to enable password login over SSH?**

Set `PasswordAuthentication yes` in `/etc/ssh/sshd_config`, run `sshd -t`, then `systemctl restart sshd`.

**14. In vim, replace a word everywhere and delete lines 5-10?**

`:%s/old/new/g` and `:5,10d`.
