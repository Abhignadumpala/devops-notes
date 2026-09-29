# Linux File Permissions

## Table of Contents

1. [Reading Permissions](#reading-permissions)
2. [What r, w, x Mean](#what-r-w-x-mean)
3. [chmod - Change Permissions](#chmod---change-permissions)
4. [chown - Change Ownership](#chown---change-ownership)
5. [umask - Default Permissions](#umask---default-permissions)
6. [Special Permissions](#special-permissions)
7. [Common DevOps Scenarios](#common-devops-scenarios)
8. [Quick Reference Commands](#quick-reference-commands)
9. [Common Issues & Solutions](#common-issues--solutions)

---

## Reading Permissions

### View Permissions

```bash
ls -l filename
ls -ld directory/     # the directory itself, not its contents

# Output:
# -rwxr-xr-- 1 alice developers 1024 Sep 27 10:30 deploy.sh
#            owner  group
```

### Permission String Breakdown

```text
-rwxr-xr--
│└┬┘└┬┘└┬┘
│ │  │  └── Others: r-- = read only        (4)
│ │  └───── Group:  r-x = read + execute   (4+1 = 5)
│ └──────── User:   rwx = read+write+exec  (4+2+1 = 7)
└────────── File type: - = file, d = directory, l = link
```

So `-rwxr-xr--` = `754`.

---

## What r, w, x Mean

| Permission | Name | Value | On a File | On a Directory |
|------------|------|-------|-----------|----------------|
| `r` | read | 4 | Read contents | List contents (`ls`) |
| `w` | write | 2 | Modify contents | Create, delete, rename files inside |
| `x` | execute | 1 | Execute (run) as a program | Enter it (`cd`) and access files inside |

---

## chmod - Change Permissions

### Symbolic Mode

```bash
chmod u+x script.sh          # Add execute for user
chmod g-w file.txt           # Remove write from group
chmod o=r file.txt           # Set others to read only
chmod a+r file.txt           # Add read for all
```

| Symbol | Meaning |
|--------|---------|
| `u` | User (owner) |
| `g` | Group |
| `o` | Others |
| `a` | All (u+g+o) |
| `+` | Add permission |
| `-` | Remove permission |
| `=` | Set exactly |

### Numeric Mode

```bash
chmod 755 script.sh
chmod 644 file.txt
chmod 600 ~/.ssh/id_ed25519
```

| Number | Permission |
|--------|------------|
| 7 | `rwx` (4+2+1) |
| 6 | `rw-` (4+2) |
| 5 | `r-x` (4+1) |
| 4 | `r--` |
| 0 | `---` |

### Common Permission Combinations

| chmod | String | Use Case |
|-------|--------|----------|
| 644 | `rw-r--r--` | Regular files, configs |
| 600 | `rw-------` | Private files, SSH keys, `.env` files |
| 755 | `rwxr-xr-x` | Scripts, directories |
| 700 | `rwx------` | Private directories (`~/.ssh`) |
| 775 | `rwxrwxr-x` | Team-shared directories |
| 777 | `rwxrwxrwx` | Avoid - anyone can modify |

### Change Recursively

```bash
chmod -R 755 directory/
```

---

## chown - Change Ownership

Format is `owner:group`.

```bash
sudo chown alice file.txt              # Change owner only
sudo chown alice:developers file.txt   # Change owner and group
sudo chown :developers file.txt        # Change group only
sudo chown -R alice:developers dir/    # Recursive (folder + contents)
```

---

## umask - Default Permissions

`umask` decides the permissions of newly created files and directories.

```bash
umask        # 0022
```

| umask | New File | New Directory |
|-------|----------|---------------|
| 022 | 644 `rw-r--r--` | 755 `rwxr-xr-x` |
| 002 | 664 `rw-rw-r--` | 775 `rwxrwxr-x` |
| 077 | 600 `rw-------` | 700 `rwx------` |

---

## Special Permissions

| Permission | Octal | Where You See It | What It Does |
|------------|-------|------------------|--------------|
| setuid | 4 | `/usr/bin/passwd` → `-rwsr-xr-x` | Program runs as its owner (root) |
| setgid | 2 | Shared folders → `drwxrwsr-x` | New files inherit the folder's group |
| sticky | 1 | `/tmp` → `drwxrwxrwt` | Users can only delete their own files |

```bash
sudo chmod 2775 /srv/project    # setgid on a shared folder
sudo chmod 1777 /shared         # sticky bit like /tmp
```

Security check - list setuid files:

```bash
sudo find / -perm -4000 -type f 2>/dev/null
```

---

## Common DevOps Scenarios

### SSH Key Permissions

SSH refuses keys with loose permissions.

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519          # Private key
chmod 644 ~/.ssh/id_ed25519.pub      # Public key
chmod 600 ~/.ssh/authorized_keys
```

AWS `.pem` files too:

```bash
chmod 400 mykey.pem
```

### Make a Script Executable

```bash
chmod +x deploy.sh
./deploy.sh
```

### Protect Secrets

```bash
chmod 600 .env
```

### Shared Team Directory

```bash
sudo groupadd developers
sudo usermod -aG developers alice

sudo mkdir -p /srv/team
sudo chown root:developers /srv/team
sudo chmod 2775 /srv/team      # group can write, new files stay in developers group
```

### Web Server Files

```bash
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| View permissions | `ls -l file` |
| Make executable | `chmod +x file` |
| Set permissions | `chmod 644 file` |
| Change owner and group | `sudo chown user:group file` |
| Change group only | `sudo chown :group file` |
| Recursive | `chmod -R 755 dir` / `chown -R user:group dir` |
| View umask | `umask` |
| Shared group folder | `sudo chmod 2775 dir` |

---

## Common Issues & Solutions

### Permission Denied Running a Script

```bash
ls -l script.sh      # Check for x
chmod +x script.sh
```

### SSH Key Rejected: "UNPROTECTED PRIVATE KEY FILE"

```bash
chmod 600 ~/.ssh/id_ed25519
```

### Group Change Not Taking Effect

New group membership needs a new login.

```bash
newgrp developers    # Or log out and back in
id
```

### Cannot Write to a Folder

```bash
ls -ld folder/                              # Check owner, group, permissions
sudo chown -R $USER:$USER folder/           # Take ownership
```

---

See also: [User & Password Management](../02-user-password-management/README.md) · [Password Management](../04-password-management/README.md)
