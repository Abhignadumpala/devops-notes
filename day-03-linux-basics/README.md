# Day 3 - Linux Basics & Commands

## Table of Contents

1. [Connecting to EC2](#connecting-to-ec2)
2. [Absolute vs Relative Path](#absolute-vs-relative-path)
3. [Command Structure](#command-structure)
4. [User & System Info](#user--system-info)
5. [CRUD on Files & Folders](#crud-on-files--folders)
6. [Listing Files (ls)](#listing-files-ls)
7. [Reading Files](#reading-files)
8. [Downloading Files (wget & curl)](#downloading-files-wget--curl)
9. [Searching (grep)](#searching-grep)
10. [Piping](#piping)
11. [cut & awk](#cut--awk)
12. [/etc/passwd & User Types](#etcpasswd--user-types)
13. [Archives (tar)](#archives-tar)
14. [Vim Editor](#vim-editor)
15. [Command Cheat Sheet](#command-cheat-sheet)
16. [Interview Questions](#interview-questions)

---

## Connecting to EC2

### Security Group Rule

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | My IP |

### Connect

```bash
ssh -i <private-key> ec2-user@<public-ip>
```

```bash
ssh -i devops-key ec2-user@<public-ip>                       # relative path to key
ssh -i /c/devops/practice/devops-key ec2-user@<public-ip>    # absolute path to key
```

- `ec2-user` = default user on Amazon Linux (`ubuntu` on Ubuntu)
- If you see a permissions error on the key: `chmod 400 devops-key`

---

## Absolute vs Relative Path

| Type | Meaning | Example |
|------|---------|---------|
| Absolute | Full path from the beginning (`/`) | `/c/devops/practice` |
| Relative | Path from where you are now | `practice` |

```bash
cd /c/devops/practice     # absolute - works from anywhere
cd /c/devops
cd practice               # relative - works only because I'm in /c/devops
cd ..                     # one step back
cd                        # go to home directory
```

Home directory:

| OS | Home |
|----|------|
| Linux | `/home/ec2-user` |
| Windows (Git Bash) | `/c/Users/<name>` |

---

## Command Structure

**Everything in Linux is a command.**

```text
<command-name> <options> <inputs>
```

```bash
ls -l /home
#  ^   ^   ^
#  |   |   input
#  |   option
#  command
```

> Linux is **case sensitive** - `Devops` and `devops` are different.

---

## User & System Info

```bash
whoami     # current username
pwd        # present working directory
id         # user ID, group ID, groups
uname      # system (kernel) information
uname -a   # all system information
```

```bash
id
# uid=1000(ec2-user) gid=1000(ec2-user) groups=1000(ec2-user),4(adm),10(wheel),190(systemd-journal)
```

`wheel` group = sudo access on RHEL/Amazon Linux.

---

## CRUD on Files & Folders

**CRUD = Create, Read, Update, Delete**

### Create

```bash
touch devops.txt           # create empty file
mkdir aws                  # create folder
```

### Write to a File

```bash
cat > devops.txt           # overwrite
Hi, I am learning DevOps   # type text, press Enter, then Ctrl+D to save

cat >> devops.txt          # append
```

| Symbol | Meaning |
|--------|---------|
| `>` | Overwrite (replace content) |
| `>>` | Append (add to end) |

```bash
echo "Hello" > file.txt     # overwrite
echo "World" >> file.txt    # append
```

### Copy

```bash
cp <source> <destination>
cp devops.txt /tmp/
cp -r aws/ aws-backup/     # -r = recursive (for folders)
```

### Move / Rename

```bash
mv <source> <destination>
mv devops.txt /tmp/        # move (cut & paste)
mv old.txt new.txt         # rename (same folder)
```

### Delete

```bash
rm aiops.txt               # delete file
rm -r aws                  # delete folder (recursive)
```

> There's no recycle bin in Linux. `rm` is permanent.

---

## Listing Files (ls)

| Command | Meaning |
|---------|---------|
| `ls` | List files and folders |
| `ls -l` | Long format (permissions, owner, size, date) |
| `ls -la` | Long format including hidden files (starting with `.`) |
| `ls -lr` | Reverse alphabetical order |
| `ls -lt` | Sort by time, latest first |
| `ls -ltr` | Sort by time, **latest at the bottom** (most used) |

### Reading ls -l Output

```text
-rw-r--r--.  1       ec2-user  ec2-user  0      Sep 23 02:08  devops.txt
<permissions> <links> <owner>   <group>   <size> <date>        <file/folder name>
```

First character: `-` = file, `d` = directory.

---

## Reading Files

```bash
cat devops.txt             # show whole file
head devops.txt            # top 10 lines (default)
tail devops.txt            # bottom 10 lines (default)
head -n 4 devops.txt       # top 4 lines
tail -n 4 devops.txt       # bottom 4 lines
tail -f app.log            # follow a log file live (Ctrl+C to stop)
```

### Print a Range of Lines

Print lines 5 to 13 (9 lines):

```bash
head -n 13 README.md | tail -n 9
```

`head -n 13` takes lines 1-13, `tail -n 9` keeps the last 9 of those → lines 5-13.

---

## Downloading Files (wget & curl)

| Command | Does |
|---------|------|
| `wget <url>` | **Downloads** the file and saves it |
| `curl <url>` | **Shows** the content on screen (doesn't save by default) |

```bash
wget https://raw.githubusercontent.com/Abhignadumpala/devops-notes/refs/heads/main/README.md
curl https://raw.githubusercontent.com/Abhignadumpala/devops-notes/refs/heads/main/README.md
curl -o README.md <url>    # save with curl
```

---

## Searching (grep)

```bash
grep <word> <file>
grep linux README.md
```

| Option | Meaning |
|--------|---------|
| `-i` | Case insensitive |
| `-n` | Show line numbers |
| `-c` | Count matching lines |
| `-v` | Invert - show lines that **don't** match |
| `-r` | Search in all files in a folder |

```bash
grep -i linux README.md       # linux, Linux, LINUX
grep -in linux README.md      # with line numbers
grep -ic linux README.md      # count
grep -inv linux README.md     # lines WITHOUT the word linux
```

---

## Piping

`|` sends the output of one command as input to the next.

```bash
cat README.md | grep linux
cat README.md | grep -inv linux
head -n 13 README.md | tail -n 9
```

---

## cut & awk

### cut - Split Text by a Delimiter

```bash
cut -d "<delimiter>" -f<field-number>
```

- `-d` = delimiter (separator)
- `-f` = field number

```bash
cut -d ":" -f1 /etc/passwd     # all usernames
```

Splitting a URL by `/`:

| Field | Value |
|-------|-------|
| f1 | `https:` |
| f2 | (empty - between `//`) |
| f3 | `raw.githubusercontent.com` |
| f4 | `Abhignadumpala` |
| f5 | `devops-notes` |
| f6 | `refs` |
| f7 | `heads` |
| f8 | `main` |
| f9 | `README.md` |

```bash
echo "https://raw.githubusercontent.com/Abhignadumpala/devops-notes/refs/heads/main/README.md" | cut -d "/" -f9
# README.md
```

### awk - More Powerful Than cut

```bash
awk -F "<delimiter>" '{print $<field-number>}'
```

- `-F` = delimiter
- `$1` = first field, `$NF` = last field

```bash
# Last field of a URL (no need to count fields)
echo "https://raw.githubusercontent.com/Abhignadumpala/devops-notes/refs/heads/main/README.md" | awk -F "/" '{print $NF}'
# README.md

# All usernames
awk -F ":" '{print $1}' /etc/passwd

# Usernames and UIDs of normal users (UID > 999)
awk -F ":" '$3 > 999 {print $1, $3}' /etc/passwd
```

| | cut | awk |
|---|-----|-----|
| Split by delimiter | Yes | Yes |
| Last field (`$NF`) | No | Yes |
| Conditions (`$3 > 999`) | No | Yes |

---

## /etc/passwd & User Types

`/etc/passwd` stores Linux user information.

```text
root:x:0:0:root:/root:/bin/bash
sshd:x:74:74:Privilege-separated SSH:/usr/share/empty.sshd:/usr/sbin/nologin
ec2-user:x:1000:1000:EC2 Default User:/home/ec2-user:/bin/bash
```

| Field | Example | Meaning |
|-------|---------|---------|
| 1 | `ec2-user` | Username |
| 2 | `x` | Password (stored in `/etc/shadow`) |
| 3 | `1000` | UID (user ID) |
| 4 | `1000` | GID (primary group ID) |
| 5 | `EC2 Default User` | Comment |
| 6 | `/home/ec2-user` | Home directory |
| 7 | `/bin/bash` | Login shell |

### User Types by UID

| UID | Type |
|-----|------|
| 0 | root |
| 1 - 999 | System users (for services, e.g. `sshd`, `chrony`) - shell is `/sbin/nologin` |
| 1000+ | Normal users (created manually, e.g. `ec2-user`) |

---

## Archives (tar)

`.tar.gz` = files bundled (tar) and compressed (gzip).

```bash
# Create
tar -czf devops.tar.gz README.md devops.txt

# Extract
tar -xzf devops.tar.gz

# List contents without extracting
tar -tzf devops.tar.gz
```

| Option | Meaning |
|--------|---------|
| `c` | Create |
| `x` | Extract |
| `t` | List contents |
| `z` | gzip (`.gz`) format |
| `f` | File name follows |

---

## Vim Editor

**Vim = Vi IMproved** - text editor available on every Linux server.

```bash
vim devops.txt
```

### Modes

| Mode | Enter With | Used For |
|------|------------|----------|
| Normal (Esc) mode | `Esc` | Default mode - navigate, delete, copy |
| Insert mode | `i` | Type text |
| Command (colon) mode | `:` (from Normal) | Save, quit, search/replace |

```text
Normal ──i──▶ Insert ──Esc──▶ Normal ──:──▶ Command
```

### Essential Commands

| Command | Action |
|---------|--------|
| `i` | Start typing (insert mode) |
| `Esc` | Back to normal mode |
| `:w` | Save |
| `:q` | Quit |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |
| `dd` | Delete current line |
| `yy` | Copy current line |
| `p` | Paste |
| `u` | Undo |
| `/word` | Search for word (`n` = next) |
| `:set nu` | Show line numbers |
| `gg` / `G` | Go to top / bottom |

Other ways to create/edit files: `cat >`, `nano`.

---

## Command Cheat Sheet

| Command | Use |
|---------|-----|
| `whoami` | Current user |
| `pwd` | Current directory |
| `cd` / `cd ..` | Change directory / go back |
| `id` | User and group info |
| `uname` | System info |
| `touch` | Create file |
| `mkdir` | Create folder |
| `ls` | List files |
| `cat` | Show/create file |
| `cp` | Copy |
| `mv` | Move/rename |
| `rm` | Delete |
| `wget` | Download file |
| `curl` | Show URL content |
| `head` / `tail` | Top / bottom lines |
| `\|` | Piping |
| `grep` | Search text |
| `cut` | Split text |
| `awk` | Split and filter text |
| `tar` | Create/extract archives |
| `history` | Previous commands |
| `echo` | Print text |
| `clear` | Clear screen |
| `vim` | Edit files |

---

## Interview Questions

**1. Absolute vs relative path?**

Absolute starts from root `/` and works from anywhere (`/home/ec2-user/app`). Relative starts from the current directory (`app`, `../logs`).

**2. Difference between `>` and `>>`?**

`>` overwrites the file, `>>` appends to the end.

**3. How do you see hidden files? Latest modified files?**

`ls -la` shows hidden files. `ls -ltr` sorts by time with the latest at the bottom.

**4. `cp` vs `mv`? How to rename a file?**

`cp` copies (original stays), `mv` moves (original is gone). Rename = `mv old.txt new.txt`. Use `-r` with `cp` for folders.

**5. `wget` vs `curl`?**

`wget` downloads and saves the file. `curl` prints the response on screen (save with `-o`); also used to test APIs.

**6. Important `grep` options?**

`-i` ignore case, `-n` line numbers, `-c` count, `-v` lines that don't match, `-r` search in a folder.

**7. How to print lines 5 to 13 of a file?**

`head -n 13 file | tail -n 9` or `sed -n '5,13p' file`.

**8. How to watch a log file live?**

`tail -f app.log`.

**9. What is a pipe `|`?**

Sends the output of one command as input to the next: `cat file | grep error`.

**10. `cut` vs `awk`?**

Both split text by a delimiter. `awk` can also print the last field (`$NF`) and filter with conditions (`$3 > 999`).

**11. How to list only normal (human) users?**

`awk -F: '$3 >= 1000 {print $1}' /etc/passwd`.

**12. What are the fields in `/etc/passwd`?**

`username:x:UID:GID:comment:home:shell` - `x` means the password is in `/etc/shadow`.

**13. UID ranges?**

0 = root, 1-999 = system users (for services), 1000+ = normal users.

**14. How to create and extract a `.tar.gz`?**

Create: `tar -czf backup.tar.gz files`. Extract: `tar -xzf backup.tar.gz`. List: `tar -tzf backup.tar.gz`.

**15. Vim modes? How to save and quit, or quit without saving?**

Normal (Esc), Insert (`i`), Command (`:`). `:wq` = save and quit, `:q!` = quit without saving.
