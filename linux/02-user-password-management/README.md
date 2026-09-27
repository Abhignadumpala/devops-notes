# Linux User Management & Password Management

## Table of Contents

1. [User Management](#user-management)
2. [Group Management](#group-management)
3. [Password Management](#password-management)
4. [User Permissions](#user-permissions)
5. [Sudo Configuration](#sudo-configuration)
6. [File Ownership](#file-ownership)
7. [User Account Security](#user-account-security)
8. [User Information Files](#user-information-files)
9. [Best Practices](#best-practices)

---

## User Management

### Create User

#### Basic User Creation

```bash
sudo useradd username
```

Creates user with default settings.

#### Create User with Home Directory

```bash
sudo useradd -m username
```

- `-m` = Create home directory

#### Create User with Specific Shell

```bash
sudo useradd -m -s /bin/bash username
```

- `-s` = Specify shell (default: /bin/sh)

#### Create User with Home Directory and Comment

```bash
sudo useradd -m -s /bin/bash -c "Full Name" username
```

- `-c` = Add comment (full name)

#### Create User with Specific UID and GID

```bash
sudo useradd -m -u 1500 -g developers username
```

- `-u` = User ID
- `-g` = Primary group

#### Complete User Creation Example

```bash
sudo useradd -m -s /bin/bash -c "John Developer" -u 1005 -g developers john
```

---

### View Users

#### List All Users

```bash
cat /etc/passwd
```

#### Show Only Usernames

```bash
cut -d: -f1 /etc/passwd
```

#### View Specific User

```bash
grep username /etc/passwd
```

#### Get User Information

```bash
id username

# Output:
# uid=1000(username) gid=1000(username) groups=1000(username),27(sudo)
```

#### View Current User

```bash
whoami
```

#### View All Logged-in Users

```bash
who

# Output:
# sri-abhi   tty2  2026-09-27 10:30
# john       tty1  2026-09-27 09:15
```

---

### Modify User

#### Change User's Shell

```bash
sudo usermod -s /bin/bash username
```

#### Add User to Group

```bash
sudo usermod -aG groupname username
```

- `-a` = Append (keep existing groups)
- `-G` = Specify groups

#### Add User to Multiple Groups

```bash
sudo usermod -aG sudo,docker,wheel username
```

#### Change User's Home Directory

```bash
sudo usermod -d /new/home/path username
```

#### Move User's Home Directory

```bash
sudo usermod -d /new/home/path -m username
```

- `-m` = Move contents to new location

#### Change Username

```bash
sudo usermod -l newname oldname
```

#### Disable User Login

```bash
sudo usermod -s /usr/sbin/nologin username
```

#### Re-enable User Login

```bash
sudo usermod -s /bin/bash username
```

#### Change User's Comment/Real Name

```bash
sudo usermod -c "New Full Name" username
```

---

### Delete User

#### Delete User Only

```bash
sudo userdel username
```

#### Delete User and Home Directory

```bash
sudo userdel -r username
```

- `-r` = Remove home directory

#### Delete User and Home + Mail Spool

```bash
sudo userdel -r -f username
```

- `-f` = Force removal

---

## Group Management

### Create Group

#### Basic Group Creation

```bash
sudo groupadd groupname
```

#### Create Group with Specific GID

```bash
sudo groupadd -g 1500 groupname
```

#### Create System Group

```bash
sudo groupadd -r systemgroup
```

- `-r` = System group (GID < 1000)

---

### View Groups

#### List All Groups

```bash
cat /etc/group
```

#### Show Only Group Names

```bash
cut -d: -f1 /etc/group
```

#### View Specific Group

```bash
grep groupname /etc/group
```

#### View User's Groups

```bash
groups username

# Output: username : username sudo docker
```

---

### Modify Group

#### Add User to Group

```bash
sudo usermod -aG groupname username
```

#### Remove User from Group

```bash
sudo deluser username groupname
```

Or:

```bash
sudo gpasswd -d username groupname
```

#### Change Group Name

```bash
sudo groupmod -n newname oldname
```

#### Change Group ID

```bash
sudo groupmod -g 2000 groupname
```

---

### Delete Group

#### Delete Group

```bash
sudo groupdel groupname
```

---

## Password Management

### Set or Change Password

#### Set Password for User

```bash
sudo passwd username
```

Prompts to enter new password twice.

#### Set Password for Current User

```bash
passwd
```

#### Set Password Without Prompt (Script)

```bash
echo "password123" | sudo passwd --stdin username
```

#### Force User to Change Password at Next Login

```bash
sudo passwd -e username
```

#### Disable Password Login (require SSH key)

```bash
sudo passwd -l username
```

- `-l` = Lock account

#### Unlock Account

```bash
sudo passwd -u username
```

- `-u` = Unlock account

---

### Password Expiration

#### View Password Expiration Info

```bash
sudo chage -l username

# Output:
# Last password change: Sep 25, 2026
# Password expires: Dec 24, 2026
# Password inactive: Jan 23, 2027
```

#### Set Password Expiration (Days)

```bash
sudo chage -M 90 username
```

- `-M 90` = Password expires in 90 days

#### Set Password Minimum Age (Can't change before N days)

```bash
sudo chage -m 1 username
```

- `-m 1` = Must wait 1 day before changing password

#### Set Inactive Days (Account disabled after password expires)

```bash
sudo chage -I 30 username
```

- `-I 30` = Account locked 30 days after password expires

#### Set Expiration Date

```bash
sudo chage -E 2027-12-31 username
```

- `-E` = Set expiration date (YYYY-MM-DD)

#### Set Warning Days (Warn before password expires)

```bash
sudo chage -W 14 username
```

- `-W 14` = Warn 14 days before expiration

#### Force Password Change at Next Login

```bash
sudo chage -d 0 username
```

---

### Password Quality

#### Check Password Policy

```bash
cat /etc/login.defs | grep PASS
```

#### Install Password Validator

```bash
sudo apt install libpam-pwquality
```

#### Configure Password Requirements

```bash
sudo nano /etc/security/pwquality.conf
```

Common settings:

```
minlen = 12              # Minimum 12 characters
dcredit = -1            # At least 1 digit
ucredit = -1            # At least 1 uppercase
lcredit = -1            # At least 1 lowercase
ocredit = -1            # At least 1 special character
```

---

## User Permissions

### Understanding Permissions

```
-rwxrw-r--
| ||| || |
| ||| || +-- Others: read (4)
| ||| |+---- Others: write (2)
| ||| +------- Others: execute (1)
| ||+--------- Group: read (4)
| |+---------- Group: write (2)
| +----------- Group: execute (1)
| +----------- User: read (4)
| +----------- User: write (2)
| +----------- User: execute (1)
```

### View Permissions

```bash
ls -l filename

# Output:
# -rw-r--r-- 1 user group 1024 Sep 27 10:30 filename
```

### Change Permissions

#### Add Permission

```bash
chmod +x script.sh
```

- `+x` = Add execute for all

#### Remove Permission

```bash
chmod -w file.txt
```

- `-w` = Remove write for all

#### Set Specific Permissions

```bash
chmod u+rwx,g+rx,o-rwx file.txt
```

- `u` = User/Owner
- `g` = Group
- `o` = Others
- `+` = Add
- `-` = Remove

#### Numeric Permissions

```bash
chmod 755 script.sh
```

Breakdown:
- `7` = User (rwx = 4+2+1)
- `5` = Group (r-x = 4+1)
- `5` = Others (r-x = 4+1)

#### Common Permission Combinations

| chmod | User | Group | Others | Use Case |
|-------|------|-------|--------|----------|
| 644 | rw- | r-- | r-- | Files |
| 755 | rwx | r-x | r-x | Scripts/Directories |
| 750 | rwx | r-x | --- | Private directories |
| 700 | rwx | --- | --- | Very private |
| 600 | rw- | --- | --- | Sensitive files |

#### Change Permissions Recursively

```bash
chmod -R 755 directory/
```

- `-R` = Recursive

---

## File Ownership

### View Ownership

```bash
ls -l filename

# Output: -rw-r--r-- 1 user group 1024 filename
#         ownership: user = user, group = group
```

### Change Owner

```bash
sudo chown user filename
```

### Change Group

```bash
sudo chown :group filename
```

### Change Both Owner and Group

```bash
sudo chown user:group filename
```

### Change Recursively

```bash
sudo chown -R user:group directory/
```

---

## Sudo Configuration

### View Sudo Config

```bash
sudo visudo
```

Best way to edit sudoers file (checks syntax before saving).

### Check if User Has Sudo Access

```bash
sudo -l

# Output shows sudo permissions
```

### Add User to Sudo Group

#### Ubuntu/Debian

```bash
sudo usermod -aG sudo username
```

#### RedHat/CentOS

```bash
sudo usermod -aG wheel username
```

### Grant Sudo Without Password (Dangerous - Use Carefully)

```bash
sudo visudo
```

Add line:

```
username ALL=(ALL) NOPASSWD:ALL
```

### Grant Specific Sudo Commands Only

```bash
visudo
```

Add:

```
username ALL=(ALL) /usr/bin/systemctl, /usr/bin/apt
```

Now user can only run systemctl and apt with sudo.

### Restrict Sudo to Specific Host

```
username host1=(ALL) ALL
```

User can only use sudo on host1.

---

## User Account Security

### Lock Account

```bash
sudo passwd -l username
```

### Unlock Account

```bash
sudo passwd -u username
```

### Check if Account is Locked

```bash
sudo passwd -S username

# Output: username L 09/25/2026 1 30 30 7
#         L = Locked
#         P = Password set
```

### Disable Login Shell

```bash
sudo usermod -s /usr/sbin/nologin username
```

User cannot login, but system processes can still run.

### Force Password Change at Next Login

```bash
sudo chage -d 0 username
```

### Set Account Expiration Date

```bash
sudo chage -E 2027-12-31 username
```

After this date, user cannot login.

### View Account Expiration

```bash
sudo chage -l username
```

---

## User Information Files

### /etc/passwd - All Users

```
username:x:uid:gid:comment:/home/username:/bin/bash
```

| Field | Meaning |
|-------|---------|
| username | User login name |
| x | Password (in /etc/shadow) |
| uid | User ID |
| gid | Group ID |
| comment | Real name/description |
| /home/username | Home directory |
| /bin/bash | Default shell |

### /etc/shadow - Password Hashes (root only)

```
username:$6$hash:18500:0:99999:7:::
```

Stores encrypted passwords. Only root can read.

### /etc/group - All Groups

```
groupname:x:gid:members
```

### /etc/gshadow - Group Passwords (root only)

Stores group password hashes (rarely used).

### /etc/sudoers - Sudo Configuration

```bash
# Edit safely
sudo visudo
```

Never edit directly - use visudo!

---

## User Account Limits

### View User Limits

```bash
ulimit -a

# Output:
# core file size: 0
# max locked memory: 64 kB
# max memory size: unlimited
# open files: 1024
```

### Set Open Files Limit

```bash
ulimit -n 2048
```

### Set Limits Permanently

Edit `/etc/security/limits.conf`:

```bash
sudo nano /etc/security/limits.conf
```

Add:

```
username soft nofile 2048
username hard nofile 4096
```

---

## Sudo Usage Examples

### Run Command as Specific User

```bash
sudo -u username command
```

### Run Command as Specific User and Group

```bash
sudo -u username -g groupname command
```

### Run Command Without Password Prompt

```bash
sudo -n command
```

### Run Previous Command with Sudo

```bash
sudo !!
```

### List What User Can Do with Sudo

```bash
sudo -l
```

### Run Interactive Shell as Another User

```bash
sudo -s
```

---

## User Management Workflows

### Create Complete User

```bash
# 1. Create user with home directory
sudo useradd -m -s /bin/bash -c "John Developer" john

# 2. Set password
sudo passwd john

# 3. Add to sudo group
sudo usermod -aG sudo john

# 4. Verify
id john
groups john
```

### Temporarily Disable User

```bash
# Lock password
sudo passwd -l username

# Or disable login shell
sudo usermod -s /usr/sbin/nologin username

# Verify
sudo passwd -S username
```

### Re-enable User

```bash
# Unlock password
sudo passwd -u username

# Or re-enable shell
sudo usermod -s /bin/bash username
```

### Remove User Completely

```bash
# Remove user and home directory
sudo userdel -r username

# Remove user group
sudo groupdel username
```

---

## Best Practices

### 1. Use Strong Passwords

```bash
# Install password quality checker
sudo apt install libpam-pwquality

# Enforce in /etc/security/pwquality.conf
minlen = 12
dcredit = -1
```

### 2. Implement Password Expiration

```bash
# Set password expiration policy
sudo chage -M 90 username    # Expire every 90 days
sudo chage -W 14 username    # Warn 14 days before
sudo chage -I 7 username     # Lock after 7 days inactive
```

### 3. Monitor User Activity

```bash
# View recent logins
lastlog

# View failed login attempts
sudo grep "Failed password" /var/log/auth.log
```

### 4. Limit Sudo Access

```bash
# Only grant necessary sudo permissions
# Edit with: sudo visudo

# Specific commands only
username ALL=(ALL) /usr/bin/systemctl, /usr/bin/apt

# Not: username ALL=(ALL) ALL
```

### 5. Disable Root Login

```bash
# Via SSH
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no

# Restart SSH
sudo systemctl restart ssh
```

### 6. Use SSH Keys Instead of Passwords

```bash
# Generate key pair
ssh-keygen -t rsa -b 4096

# Copy to server
ssh-copy-id -i ~/.ssh/id_rsa.pub user@host

# Disable password login
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
```

### 7. Regular Audit of Users

```bash
# List all users
cut -d: -f1 /etc/passwd

# Check for inactive users
sudo lastlog -t 90

# Remove unused accounts
sudo userdel -r username
```

### 8. Backup User Configuration

```bash
# Backup passwd, shadow, group files
sudo cp /etc/passwd /backup/passwd.bak
sudo cp /etc/shadow /backup/shadow.bak
sudo cp /etc/group /backup/group.bak
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Create user | `sudo useradd -m -s /bin/bash username` |
| Set password | `sudo passwd username` |
| Add to sudo | `sudo usermod -aG sudo username` |
| Change shell | `sudo usermod -s /bin/bash username` |
| Add to group | `sudo usermod -aG groupname username` |
| List users | `cut -d: -f1 /etc/passwd` |
| List groups | `cut -d: -f1 /etc/group` |
| View user info | `id username` |
| Lock user | `sudo passwd -l username` |
| Delete user | `sudo userdel -r username` |
| Change permissions | `chmod 755 filename` |
| Change owner | `sudo chown user:group filename` |
| Edit sudoers | `sudo visudo` |
| View sudo access | `sudo -l` |

---

## Common Issues & Solutions

### User Cannot Login

```bash
# Check if user exists
id username

# Check if account is locked
sudo passwd -S username

# Check shell
grep username /etc/passwd

# Reset shell
sudo usermod -s /bin/bash username
```

### Permission Denied on File

```bash
# Check ownership
ls -l filename

# Change owner
sudo chown user:group filename

# Change permissions
chmod 755 filename
```

### Sudo Not Working

```bash
# Check if user in sudo group
id username

# Add to sudo group
sudo usermod -aG sudo username

# Must logout and login for changes to take effect
```

### Cannot Remove User

```bash
# Kill user's processes
sudo pkill -u username

# Remove user
sudo userdel -r username
```
