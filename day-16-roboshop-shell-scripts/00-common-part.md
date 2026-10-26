# Common Part of Every Script + Index of Script Notes

[← Back to Day 16 notes](README.md)

Each script has **its own folder** (`01-mongodb/`, `05-catalogue/`, ...) with the script, its config files and its explanation (`README.md`). Each note explains **one script**: what the server does, the full code, every line, how I ran it, how I checked it, and the problems I hit.

| # | Note | Server | Port | Status |
|---|------|--------|------|--------|
| 0 | [roboshop.sh](00-roboshop/README.md) | my laptop | – | ✅ creates EC2 + DNS |
| 1 | [01-mongodb.sh](01-mongodb/README.md) | mongodb | 27017 | ✅ |
| 2 | [02-redis.sh](02-redis/README.md) | redis | 6379 | ✅ 21 s |
| 3 | [03-mysql.sh](03-mysql/README.md) | mysql | 3306 | ✅ 40 s |
| 4 | [04-rabbitmq.sh](04-rabbitmq/README.md) | rabbitmq | 5672 | ✅ 36 s |
| 5 | [05-catalogue.sh](05-catalogue/README.md) | catalogue | 8080 | ✅ 63 s |
| 6 | [06-user.sh](06-user/README.md) | user | 8080 | ✅ 109 s |
| 7 | [07-cart.sh](07-cart/README.md) | cart | 8080 | ✅ 99 s |
| 8 | [08-shipping.sh](08-shipping/README.md) | shipping | 8080 | ✅ 216 s, 948,833 cities |
| 9 | [09-payment.sh](09-payment/README.md) | payment | 8080 | ✅ 18 s, rabbitmq true |
| 10 | [10-frontend.sh](10-frontend/README.md) | frontend | 80 | ✅ shop live, 3 orders placed |
| 11 | dispatch | dispatch | – | next |

---

## The common part (top of every script)

Every component script starts with the same block. It's explained once here, and the server notes only explain what's different.

```bash
user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

timestamp(){
    date +"%F %T"
}

validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}
```

| Line | What it does | Why |
|------|--------------|-----|
| `user_id=$(id -u)` | Saves my user ID. root = `0` | `dnf` and `systemctl` need root |
| `logs_file="${logs_folder}/${0}.log"` | `$0` = script name → `/var/log/roboshop/02-redis.sh.log` | One log file per script |
| `R`, `G`, `Y`, `N` | Colour codes: red, green, yellow, normal | FAILED red, SUCCESS green, SKIPPING yellow |
| `if [ $user_id -ne 0 ]; then ... exit 1` | Stops if not root | Fail early with a clear message |
| `mkdir -p $logs_folder` | Creates the log folder | `-p` = no error if it already exists |
| `timestamp()` | Prints date + time, e.g. `2026-10-22 20:33:29` | Every log line gets a time, like real logs |
| `validate $? "step"` | `$1` = exit code of the last command, `$2` = message | `0` → SUCCESS, else FAILED + `exit 1` (stop at the first failure) |
| `echo -e` | Makes the colour codes work | Without `-e` you see `\e[31m` as text |
| `tee -a $logs_file` | Shows on screen **and** appends to the log | Screen for me, log for later |
| `&>> $logs_file` (on commands) | Sends output **and** errors to the log | Screen stays clean: only SUCCESS / FAILED lines |
| `$SECONDS` (at the end) | Built-in: seconds since the script started | Measures run time. Must be CAPITALS |

> `01-mongodb.sh` was my first script, so it has the older version: no `timestamp()` and no `[INFO]` / `[ERROR]`.

---

## Create the app user (every app script: catalogue, user, cart, shipping, payment ...)

```bash
id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $logs_file
    validate $? "Creating system user"
else
    echo -e "$(timestamp) [INFO] System user roboshop already exist...${Y}SKIPPING${N}"
fi
```

**In one line:** if the `roboshop` user doesn't exist, create it. If it already exists, skip.

| Line | What it does |
|------|--------------|
| `id roboshop &>> $logs_file` | Asks Linux: "does user `roboshop` exist?" Output and errors go to the log, not the screen |
| `if [ $? -ne 0 ]; then` | `$?` = exit code of the last command. **0 = found**, **not 0 = not found**. `-ne 0` = "not equal to 0", so "if NOT found" |
| `useradd ... roboshop` | Creates the user |
| `validate $? "Creating system user"` | Prints SUCCESS or FAILED for `useradd` |
| `else` → `echo ... SKIPPING` | User already exists, so print yellow SKIPPING and do nothing |
| `fi` | End of the `if` (`if` backwards) |

| `useradd` option | Meaning | Why |
|------------------|---------|-----|
| `--system` | A user for a program, not a person | The app runs as it, nobody logs in |
| `--home /app` | Its home folder is `/app` | The app code lives there |
| `--shell /sbin/nologin` | Nobody can log in as it | Security: no shell for an attacker |
| `--comment "..."` | A description | Just a label |
| `roboshop` | The username | |

```
id roboshop
     │
  exit code?
   ┌─┴───────────┐
  0 (exists)    1 (not found)
   │              │
 SKIPPING      useradd → SUCCESS / FAILED
```

**Why check first?** `useradd roboshop` a 2nd time fails with `user 'roboshop' already exists`, so `validate` would stop the script with **FAILED**. The check makes the script **idempotent**: run it many times, same result, no errors.

> **Idempotent** = you can run it many times and get the same result, with no errors and nothing duplicated.
>
> | Run | Not idempotent (`useradd` only) | Idempotent (`id` check first) |
> |-----|----------------------------------|-------------------------------|
> | 1st | user created ✅ | user created ✅ |
> | 2nd | `user already exists` → **FAILED**, script stops ❌ | **SKIPPING**, script continues ✅ |
>
> Idempotent checks in my scripts: `id roboshop` before `useradd` · `mkdir -p` · `rabbitmqctl list_users \| grep -qw` before `add_user` · count check before loading products / cities · `rm -rf /app` before unzip.
>
> Real tools like **Ansible** and **Terraform** are idempotent by design. In Bash I write every check myself.

**Why not run the app as root?** If someone breaks into the app, they only get the limited `roboshop` user, not root. This is called **least privilege**.

**Try it:** `id roboshop; echo $?` → `0` if it exists, `1` if not.

**Interview one-liner:** *"I check `id user` and its exit code `$?` before `useradd`, so the script is idempotent: a re-run skips instead of failing. The app runs as a `--system` user with `/sbin/nologin` for least privilege."*

---

## How I run any script

**On my laptop:**
```bash
bash roboshop.sh <name>          # creates the server + DNS record
git push                         # scripts are on GitHub
```

**On the new server:**
```bash
ssh ec2-user@<public-ip>
sudo su -
dnf install git -y
git clone https://github.com/Abhignadumpala/shellscript-roboshop-v1.git
cd shellscript-roboshop-v1
bash 0N-<name>.sh
```

**Script looks frozen?** Open a 2nd SSH session: `tail -f /var/log/roboshop/0N-<name>.sh.log`
