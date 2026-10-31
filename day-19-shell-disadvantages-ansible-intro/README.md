# Day 19 - Shell Script Disadvantages & Ansible Introduction

> **In short:** Shell scripts work, but they have limits: no idempotency, no built-in error handling, commands must run in order, they don't scale to many servers, they work only on one Linux family, and they can't keep secrets safely. **Ansible** is a **configuration management** tool that fixes these. It turns a plain server into one that's ready to host an application. It **pushes** changes over SSH (no agent on the servers), reads the server list from an **inventory**, uses **modules** instead of Linux commands, and keeps repeated work in **playbooks** written in **YAML** (key: value).

**More in this folder:** [Interview questions](interview-questions/README.md)

## Table of Contents

1. [Shell script disadvantages](#shell-script-disadvantages)
2. [Non-interactive SSH: run one command on a server](#non-interactive-ssh-run-one-command-on-a-server)
3. [What is configuration management?](#what-is-configuration-management)
   - [Configuration: plain server → ready to host the app](#configuration-plain-server--ready-to-host-the-app)
   - [CRUD of configuration](#crud-of-configuration)
4. [Push vs Pull](#push-vs-pull)
5. [Ansible basics](#ansible-basics)
   - [Inventory](#inventory)
   - [Module = Linux command](#module--linux-command)
   - [Ad-hoc command](#ad-hoc-command)
   - [Playbook](#playbook)
6. [Markup languages: YAML, HTML, XML, JSON](#markup-languages-yaml-html-xml-json)
   - [Why key: value? (the bank form example)](#why-key-value-the-bank-form-example)
7. [What I learned](#what-i-learned)
8. [Interview Questions](#interview-questions)

---

## Shell script disadvantages

**Definition:** **Disadvantages** = the limits of shell scripts that make them hard to use for managing many servers.

| # | Disadvantage | What it means | Example |
|---|---|---|---|
| 1 | **No idempotency** | Running the script **again** can fail or do the work twice. We have to write the "is it already done?" checks ourselves. | `useradd roboshop` 2nd time → `user 'roboshop' already exists` |
| 2 | **No error handling** | Shell **keeps going** after a failed command. We check `$?` and `exit 1` ourselves. | `dnf install` fails, script still starts the service |
| 3 | **Imperative**: commands must be in **order** | We say **how** to do it, step by step. Wrong order = failure. | starting a service **before** creating its service file |
| 4 | **Can't handle scale** | One script, one server. For 100 servers: loop + SSH, one by one, slow and hard to track. | RoboShop: 10 servers, ssh into each and run the script |
| 5 | **Homogeneous**: works only on a specific distro | Commands differ between Linux families. | `dnf` works on RHEL/Amazon Linux, **not** on Ubuntu (`apt`) |
| 6 | **Can't store secrets securely** | Passwords sit in plain text in the script or Git. | MySQL root password inside `03-mysql.sh` |

**Definitions:**

| Term | Definition |
|---|---|
| **Idempotency** | running the same thing many times gives the **same result** as running it once (no errors, no duplicates) |
| **Imperative** | you write **how** to do it, step by step, in order (shell) |
| **Declarative** | you write **what** you want (the final state); the tool works out how (Ansible: `state=installed`) |
| **Homogeneous** | everything is the **same kind**: here, the script only works on one OS family |

> These are exactly the problems I hit in RoboShop with shell scripts ([Day 16](../day-16-roboshop-shell-scripts/README.md), [Day 17](../day-17-roboshop-v2-common-functions/README.md)): re-runs failing, ssh into 10 servers one by one, passwords in scripts.

## Non-interactive SSH: run one command on a server

**Definition:** **Non-interactive login** = SSH runs **one command** on the remote server and comes back, without opening a shell where you type.

```bash
ssh ec2-user@172.31.31.45 -C "touch /tmp/devops.txt"
```

| Part | Means |
|---|---|
| `ec2-user@172.31.31.45` | user @ server (private IP) |
| `"touch /tmp/devops.txt"` | the command to run **on that server** |
| `-C` | **C**ompression (not "command"); the command works without it, because ssh runs whatever comes after the host |

| Interactive | Non-interactive |
|---|---|
| `ssh ec2-user@<ip>` → you get a prompt and type | `ssh ec2-user@<ip> "<command>"` → runs and exits |
| for a human | for **scripts and tools** |

**This is how Ansible works:** it connects with SSH **non-interactively** and runs its work on each server.

## What is configuration management?

**Definition:** **Configuration management** = tools that set up and keep servers in the **desired state** (packages, users, files, services) automatically and the same way on every server. **Ansible** is one of them.

### Configuration: plain server → ready to host the app

**Definition:** **Configuration** = all the steps that turn a **plain server** into one **ready to host the application**.

```
Plain server ──────────────────────────────────────────► Ready to host app
   1. install programming language   (nodejs, java, python)
   2. create system user              (roboshop)
   3. create app directory            (/app)
   4. download code                   (curl -o /tmp/app.zip ...)
   5. unzip code                      (unzip /tmp/app.zip -d /app)
   6. install dependencies            (npm install / mvn package / pip install)
   7. create systemctl service file   (/etc/systemd/system/<app>.service)
   8. load data if necessary          (mongo / mysql schema)
   9. start the server                (systemctl enable --now <app>)
```

These are the same steps as our RoboShop scripts (`app_setup`, `nodejs_setup`, `systemd_setup` in `common.sh`). Ansible does them **idempotently**, on **many servers**, in **parallel**.

### CRUD of configuration

**Definition:** **CRUD** = **C**reate, **R**ead, **U**pdate, **D**elete: the 4 basic operations on anything.

| Operation | On a server's configuration | With a script |
|---|---|---|
| **Create** | set up the server | write the script and run it |
| **Read** | see what is there inside the server | check commands (`dnf list installed`, `id roboshop`) |
| **Update** | change the configuration | update the script and run it again |
| **Delete** | remove the configuration | write a (removal) script and run it |

## Push vs Pull

**Definition:**
- **Pull (poll)** = the server **keeps asking** the central system "anything new for me?" on a schedule.
- **Push** = the central system **sends** the change to the server **only when** there is one.

**Courier example (HYD → Delhi):**

| | You (in Delhi) | Like |
|---|---|---|
| **Pull / poll** | go to the DTDC office **every day** to check if the courier arrived | an agent on each server asking the master every few minutes |
| **Push** | stay home; when the courier arrives, it's **delivered** to you | Ansible connects and applies the change only when you run it |

**Problems with pull:**
1. **Unnecessary traffic**: most checks find nothing new.
2. **Waste of resources**: the agent runs and uses CPU/RAM/network all the time.

| | Push | Pull |
|---|---|---|
| Who starts | central/control server | each managed server (agent) |
| Agent on servers | ❌ not needed (Ansible uses SSH) | ✅ needed |
| Tools | **Ansible** | Chef, Puppet |

## Ansible basics

**Definition:** **Ansible** = an **agentless**, **push-based** configuration management tool. From one **control server**, it connects to many servers over **SSH** and configures them.

```
Ansible control server
   │  reads inventory (which servers)
   │  ssh (non-interactive), in parallel
   ├──► server 1   ─┐
   ├──► server 2    ├─ install / configure (modules)
   └──► server 3   ─┘
```

### Inventory

**Definition:** **Inventory** = the **list of items**: in Ansible, the list of **servers** (IPs or hostnames) to manage.

```bash
-i 172.31.31.45,              # inline: one server; the trailing comma tells Ansible "this is a list, not a file"
-i inventory.ini              # or a file with many servers
```

### Module = Linux command

**Definition:** **Module** = Ansible's ready-made unit of work, like a Linux command. A **collection** = a package of modules.

| Linux command | Ansible module |
|---|---|
| `dnf install nginx` | `dnf` (or `package`, works on any distro) |
| `useradd roboshop` | `user` |
| `mkdir /app` | `file` |
| `curl -o file URL` | `get_url` |
| `unzip` | `unarchive` |
| `systemctl start nginx` | `service` / `systemd` |

Modules are **idempotent**: if nginx is already installed, the `dnf` module says `ok` and changes nothing.

### Ad-hoc command

**Definition:** **Ad-hoc command** = a one-line Ansible command for an **emergency** or **one-time simple task** (not saved for reuse).

```bash
ansible all -i 172.31.31.45, -e ansible_user=ec2-user -e ansible_password=<password> -b -m dnf -a "name=nginx state=installed"
```

| Part | Means |
|---|---|
| `ansible` | run an ad-hoc command |
| `all` | target **all** servers in the inventory |
| `-i 172.31.31.45,` | **i**nventory: this one server (note the comma) |
| `-e ansible_user=ec2-user` | **e**xtra variable: SSH user |
| `-e ansible_password=<password>` | SSH password (needs `sshpass` installed on the control server) |
| `-b` | **b**ecome root (like `sudo`) |
| `-m dnf` | **m**odule to use: `dnf` |
| `-a "name=nginx state=installed"` | **a**rguments: package `nginx` should be **installed** |

`state=installed` is **declarative**: I say **what** I want, not how. Run it twice → 2nd time nothing changes (idempotent).

### Playbook

**Definition:** **Playbook** = a **YAML file** that keeps all the modules (tasks) for **repetitive** work, so it can be run again and again.

| Ad-hoc command | Playbook |
|---|---|
| one module, one line | many tasks in a file |
| emergency / one-time | repetitive, saved in Git |
| `ansible ...` | `ansible-playbook <file>.yaml` |

Small example (same task as the ad-hoc command):

```yaml
- name: install nginx
  hosts: all
  become: yes
  tasks:
    - name: install nginx
      ansible.builtin.dnf:
        name: nginx
        state: installed
```

## Markup languages: YAML, HTML, XML, JSON

**Definition:** **Markup / data languages** = ways to write data or documents in a **structured** format that both humans and programs can read.

| Short | Full form | Used for | Example |
|---|---|---|---|
| **YAML** | Yet Another Markup Language (now "YAML Ain't Markup Language") | config files, **Ansible playbooks**, Kubernetes, GitHub Actions | `name: nginx` |
| **HTML** | HyperText Markup Language | web pages, **HTML emails** (Day 18) | `<h1>Title</h1>` |
| **XML** | eXtensible Markup Language | older configs/APIs (Maven `pom.xml`) | `<name>nginx</name>` |
| **JSON** | JavaScript Object Notation | **APIs**, Terraform state | `{"name": "nginx"}` |

**HTML example:** tags give the text its **meaning**:

```html
<h1>Your Name</h1>          <!-- biggest heading -->
<h2>DevOps Engineer</h2>    <!-- smaller heading -->
```

**Definition:** **DTO (Data Transfer Object)** = an object used only to **carry data** between systems or programs (e.g. the JSON an API sends back). JSON, YAML and XML are formats to send DTOs.

### Why key: value? (the bank form example)

**Definition:** **Key-value pair** = data stored as **name → value** (`firstname = john`). The **key** tells what the value is.

Two banks ask for the same details, but in a **different order**:

| Bank A form | Bank B form |
|---|---|
| date | acc number |
| acc number | denomination |
| denomination | date |
| name | name |
| branch | sign |
| sign | branch |

If we just wrote values in a row (`01-01-2026, 12345, 500, ...`), Bank B would read them in the wrong place. A **form** fixes this: each box has a **label** (key), so the **order doesn't matter**.

That's a **template**: fixed keys, you fill the values.

```
firstname = john          # key = value
lastname  = doe
skill     = devops
dob       = 01-01-01
```

Same data in each format:

```yaml
# YAML
firstname: john
lastname: doe
skill: devops
dob: 01-01-01
```
```json
{ "firstname": "john", "lastname": "doe", "skill": "devops", "dob": "01-01-01" }
```
```xml
<person>
  <firstname>john</firstname>
  <lastname>doe</lastname>
  <skill>devops</skill>
  <dob>01-01-01</dob>
</person>
```

> Ansible playbooks are **YAML**, so everything in them is **key: value** (and lists of them).

## What I learned

### Class summary

- Shell scripts have **6 disadvantages**: no idempotency, no error handling, imperative (order matters), can't scale, work on one distro only, can't store secrets securely.
- `ssh user@ip "command"` = **non-interactive** login: runs one command remotely. Ansible works this way.
- **Configuration management** turns a plain server into one ready to host the app (language, user, directory, code, dependencies, service, data, start) and supports CRUD.
- **Push** (Ansible) vs **pull/poll** (agents asking all the time → unnecessary traffic, wasted resources).
- Ansible: **inventory** = list of servers, **module** = Linux command, **ad-hoc** = one-time/emergency task, **playbook** = repetitive tasks in a **YAML** file.
- YAML, HTML, XML, JSON: structured formats; **key: value** means the order doesn't matter, like a filled-in form.

```
Shell limits ──► Configuration management ──► Ansible (push, SSH, agentless)
                                                 ├─ inventory  (which servers)
                                                 ├─ modules    (what to do)
                                                 ├─ ad-hoc     (one-time)
                                                 └─ playbook   (YAML, repeatable)
```

## Interview Questions

See [interview-questions/README.md](interview-questions/README.md).
