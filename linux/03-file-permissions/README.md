# Linux File Permissions

## Table of Contents

1. [Reading Permissions](#reading-permissions)
2. [What r, w, x Mean](#what-r-w-x-mean)
3. [chmod - Change Permissions](#chmod---change-permissions)
4. [chown & chgrp - Change Ownership](#chown--chgrp---change-ownership)
5. [umask - Default Permissions](#umask---default-permissions)
6. [Special Permissions](#special-permissions)
7. [ACLs - Access Control Lists](#acls---access-control-lists)
8. [File Attributes (chattr)](#file-attributes-chattr)
9. [Finding Files by Permission](#finding-files-by-permission)
10. [Common Scenarios](#common-scenarios)
11. [Quick Reference Commands](#quick-reference-commands)
12. [Common Issues & Solutions](#common-issues--solutions)

---

## Reading Permissions

### View Permissions

```bash
ls -l filename
ls -ld directory/     # the directory itself, not its contents

# Output:
# -rwxr-xr-- 1 alice developers 1024 Sep 27 10:30 deploy.sh
```

### Permission String Breakdown

```text
-rwxr-xr--
│└┬┘└┬┘└┬┘
│ │  │  └── Others: r-- = read only        (4)
│ │  └───── Group:  r-x = read + execute   (4+1 = 5)
│ └──────── User:   rwx = read+write+exec  (4+2+1 = 7)
└────────── File type
```

So `-rwxr-xr--` = `754`.

### File Type Character

| Char | Type |
|------|------|
| `-` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |
| `c` | Character device (e.g. `/dev/tty`) |
| `b` | Block device (e.g. `/dev/sda`) |
| `s` | Socket |
| `p` | Named pipe (FIFO) |

### View Numeric Permissions

```bash
stat -c '%a %U:%G %n' filename

# Output: 754 alice:developers deploy.sh
```

---

## What r, w, x Mean

Permissions mean different things on files and directories.

| Permission | Name | Value | On a File | On a Directory |
|------------|------|-------|-----------|----------------|
| `r` | read | 4 | Read contents | List contents (`ls`) |
| `w` | write | 2 | Modify contents | Create, delete, rename files inside |
| `x` | execute | 1 | Execute (run) as a program | Enter it (`cd`) and access files inside |

Key points:

- Deleting a file needs `w` on the **directory**, not on the file.
- A directory with `r` but no `x` lets you see names but not open anything.
- A directory with `x` but no `r` lets you open files if you know their exact names.

---

## chmod - Change Permissions

### Symbolic Mode

```bash
chmod u+x script.sh          # Add execute for user
chmod g-w file.txt           # Remove write from group
chmod o=r file.txt           # Set others to read only
chmod a+r file.txt           # Add read for all
chmod u=rwx,g=rx,o= file.txt # Set all at once
```

| Symbol | Meaning |
|--------|---------|
| `u` | User (owner) |
| `g` | Group |
| `o` | Others |
| `a` | All (u+g+o) |
| `+` | Add permission |
| `-` | Remove permission |
| `=` | Set exactly (removes anything not listed) |

### Numeric (Octal) Mode

```bash
chmod 755 script.sh
chmod 644 file.txt
chmod 600 ~/.ssh/id_ed25519
```

| Number | Permission | Meaning |
|--------|------------|---------|
| 0 | `---` | None |
| 1 | `--x` | Execute |
| 2 | `-w-` | Write |
| 3 | `-wx` | Write + execute |
| 4 | `r--` | Read |
| 5 | `r-x` | Read + execute |
| 6 | `rw-` | Read + write |
| 7 | `rwx` | Read + write + execute |

### Common Permission Combinations

| chmod | String | Use Case |
|-------|--------|----------|
| 644 | `rw-r--r--` | Regular files |
| 600 | `rw-------` | Private files, SSH private keys |
| 755 | `rwxr-xr-x` | Scripts, public directories |
| 750 | `rwxr-x---` | Group-shared directories |
| 700 | `rwx------` | Private directories (`~/.ssh`) |
| 775 | `rwxrwxr-x` | Team-writable directories |
| 777 | `rwxrwxrwx` | Avoid - anyone can modify |

### Change Recursively

```bash
chmod -R 755 directory/
```

Setting the same mode on files and directories is usually wrong (it makes every file executable). Set them separately:

```bash
find directory/ -type d -exec chmod 755 {} +
find directory/ -type f -exec chmod 644 {} +
```

Or use capital `X`, which adds execute only to directories and files that are already executable:

```bash
chmod -R u=rwX,g=rX,o=rX directory/
```

### Copy Permissions from Another File

```bash
chmod --reference=source.txt target.txt
```

---

## chown & chgrp - Change Ownership

Only root can change a file's owner. The owner can change the group to any group they belong to.

```bash
sudo chown alice file.txt              # Change owner
sudo chown alice:developers file.txt   # Change owner and group
sudo chown :developers file.txt        # Change group only
sudo chgrp developers file.txt         # Change group only
sudo chown -R alice:developers dir/    # Recursive
```

### Copy Ownership from Another File

```bash
sudo chown --reference=source.txt target.txt
```

---

## umask - Default Permissions

`umask` removes permissions from newly created files and directories.

- New files start from `666` (no execute by default)
- New directories start from `777`

### View Current umask

```bash
umask        # 0022
umask -S     # u=rwx,g=rx,o=rx
```

### How It Works

| umask | New File | New Directory | Use Case |
|-------|----------|---------------|----------|
| 022 | 644 `rw-r--r--` | 755 `rwxr-xr-x` | Default on most systems |
| 002 | 664 `rw-rw-r--` | 775 `rwxrwxr-x` | Team collaboration |
| 027 | 640 `rw-r-----` | 750 `rwxr-x---` | Servers, more private |
| 077 | 600 `rw-------` | 700 `rwx------` | Very private |

### Set umask

```bash
# Current shell only
umask 027

# Permanently for your user
echo "umask 027" >> ~/.bashrc
```

System-wide default is set by `UMASK` in `/etc/login.defs`.

---

## Special Permissions

| Permission | Octal | Symbolic | On a File | On a Directory |
|------------|-------|----------|-----------|----------------|
| setuid | 4000 | `u+s` | Runs as the file's owner | No effect |
| setgid | 2000 | `g+s` | Runs as the file's group | New files inherit the directory's group |
| sticky | 1000 | `+t` | No effect | Only the file's owner can delete it |

### setuid (SUID)

```bash
ls -l /usr/bin/passwd

# Output: -rwsr-xr-x 1 root root ... /usr/bin/passwd
#            ^ s = setuid
```

`passwd` runs as root so normal users can update `/etc/shadow`.

```bash
sudo chmod u+s program
sudo chmod 4755 program
```

> setuid on a root-owned program is a security risk. Never set it on scripts or programs you didn't write.

### setgid (SGID) - Shared Team Directories

```bash
sudo mkdir /srv/project
sudo chown :developers /srv/project
sudo chmod 2775 /srv/project

ls -ld /srv/project
# Output: drwxrwsr-x 2 root developers ... /srv/project
#               ^ s = setgid
```

Every file created inside now belongs to the `developers` group, not the creator's primary group.

### Sticky Bit

```bash
ls -ld /tmp

# Output: drwxrwxrwt 10 root root ... /tmp
#                  ^ t = sticky
```

Everyone can write to `/tmp`, but users can only delete their own files.

```bash
sudo chmod +t /shared
sudo chmod 1777 /shared
```

### Lowercase vs Uppercase

| Shown | Meaning |
|-------|---------|
| `s` / `t` | Special bit set **and** execute set |
| `S` / `T` | Special bit set but execute **missing** (usually a mistake) |

---

## ACLs - Access Control Lists

Use ACLs when you need permissions for more than one user or group on the same file.

### Install

```bash
sudo apt install acl       # Ubuntu/Debian
sudo dnf install acl       # RedHat/CentOS
```

### View ACLs

```bash
getfacl file.txt

# Output:
# # file: file.txt
# # owner: alice
# # group: developers
# user::rw-
# user:bob:rw-
# group::r--
# mask::rw-
# other::r--
```

A `+` at the end of the `ls -l` permissions means the file has an ACL:

```text
-rw-rw-r--+ 1 alice developers 1024 Sep 27 10:30 file.txt
```

### Set ACLs

```bash
setfacl -m u:bob:rw file.txt          # Give user bob read/write
setfacl -m g:qa:r file.txt            # Give group qa read
setfacl -R -m u:bob:rwX project/      # Recursive
```

### Default ACLs (Inherited by New Files)

```bash
setfacl -d -m g:developers:rwX project/
```

### Remove ACLs

```bash
setfacl -x u:bob file.txt    # Remove one entry
setfacl -b file.txt          # Remove all ACLs
```

### Backup and Restore ACLs

```bash
getfacl -R project/ > acls.txt
setfacl --restore=acls.txt
```

---

## File Attributes (chattr)

Attributes apply even to root.

```bash
sudo chattr +i file.txt     # Immutable: cannot modify, delete, or rename
sudo chattr -i file.txt     # Remove immutable
sudo chattr +a app.log      # Append-only: can only add to the end
lsattr file.txt             # View attributes

# Output: ----i---------e------- file.txt
```

Useful for protecting config files like `/etc/resolv.conf` from being overwritten.

---

## Finding Files by Permission

```bash
# setuid files (security audit)
sudo find / -perm -4000 -type f 2>/dev/null

# setgid files
sudo find / -perm -2000 -type f 2>/dev/null

# World-writable files
sudo find / -xdev -type f -perm -0002 2>/dev/null

# Files with exactly 777
find . -perm 777

# Files with no valid owner (e.g. after deleting a user)
sudo find / -xdev \( -nouser -o -nogroup \) 2>/dev/null

# Files owned by a user
sudo find / -xdev -user alice 2>/dev/null
```

| `-perm` form | Meaning |
|--------------|---------|
| `-perm 644` | Exactly 644 |
| `-perm -644` | At least these bits set |
| `-perm /022` | Any of these bits set |

---

## Common Scenarios

### SSH Key Permissions

SSH refuses keys with loose permissions.

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519          # Private key
chmod 644 ~/.ssh/id_ed25519.pub      # Public key
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/config
```

### Make a Script Executable

```bash
chmod +x deploy.sh
./deploy.sh
```

### Shared Team Directory

```bash
sudo groupadd developers
sudo usermod -aG developers alice
sudo usermod -aG developers bob

sudo mkdir -p /srv/team
sudo chown root:developers /srv/team
sudo chmod 2770 /srv/team                        # setgid + group rwx
sudo setfacl -d -m g:developers:rwX /srv/team    # New files group-writable
```

### Web Server Files

```bash
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} +
sudo find /var/www/html -type f -exec chmod 644 {} +
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| View permissions | `ls -l file` |
| View numeric permissions | `stat -c '%a' file` |
| Make executable | `chmod +x file` |
| Set permissions | `chmod 644 file` |
| Change owner and group | `sudo chown user:group file` |
| Recursive dirs only | `find dir -type d -exec chmod 755 {} +` |
| View umask | `umask` |
| Shared group directory | `chmod 2775 dir` |
| Sticky bit | `chmod +t dir` |
| Give one user access | `setfacl -m u:bob:rw file` |
| View ACLs | `getfacl file` |
| Make immutable | `sudo chattr +i file` |
| Find setuid files | `sudo find / -perm -4000 -type f 2>/dev/null` |

---

## Common Issues & Solutions

### Permission Denied Running a Script

```bash
ls -l script.sh      # Check for x
chmod +x script.sh

# Still denied? The filesystem may be mounted noexec
mount | grep noexec
bash script.sh       # Run through the interpreter instead
```

### Permission Denied Entering a Directory

```bash
# Every parent directory needs x
namei -l /path/to/dir
```

### Cannot Delete a File You Own

```bash
# Need w on the parent directory
ls -ld parent_dir/

# Check for immutable attribute or sticky bit
lsattr file.txt
ls -ld parent_dir/
```

### Group Change Not Taking Effect

```bash
# New group membership needs a new login
newgrp developers    # Or log out and back in
id
```

### SSH Key Rejected: "UNPROTECTED PRIVATE KEY FILE"

```bash
chmod 600 ~/.ssh/id_ed25519
```

---

See also: [User & Password Management](../02-user-password-management/README.md) · [Password Management](../04-password-management/README.md)
