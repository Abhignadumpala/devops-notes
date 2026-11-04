# RoboShop v1 with Ansible: Every File Explained

[← Day 22 notes](../README.md)

> **In short:** RoboShop is an online shop made of **10 servers**: 4 databases (MongoDB, Redis, MySQL, RabbitMQ), 5 backend services (catalogue, user, cart, shipping, payment) and 1 frontend (nginx). In shell-script RoboShop we wrote one script per server. Here we write **one playbook per server** (`01-mongodb.yaml` … `10-frontend.yaml`). Shared settings live in `ansible.cfg`, `inventory.ini` and `group_vars/`, and config files that need server names are **Jinja2 templates** (`*.j2`).

## About this project

| Part | Files | What you learn |
|---|---|---|
| **Part 1: Project setup** | `ansible.cfg`, `inventory.ini`, `group_vars/`, `roboshop.yaml`, `ec2_output.yaml` | How Ansible finds the servers, logs in and gets its variables |
| **Part 2: Modules and templates** | (used by every playbook) | What each module does, with the shell command it replaces; what a `.j2` template is |
| **Part 3: Databases** | `01-mongodb.yaml` · `02-redis.yaml` · `03-mysql.yaml` · `04-rabbitmq.yaml` + `mongo.repo`, `rabbitmq.repo` | Install and open each database |
| **Part 4: Backend services** | `05-catalogue.yaml` · `06-user.yaml` · `07-cart.yaml` · `08-shipping.yaml` · `09-payment.yaml` + their `.service.j2` | The common app pattern, then what's special in each |
| **Part 5: Frontend** | `10-frontend.yaml` + `roboshop.conf.j2` | nginx serves the website and forwards `/api/...` to the services |
| **Part 6: Run it** | | The order to run everything |

## Table of Contents

**Part 1: Project setup**
1. [Project structure](#1-project-structure)
2. [ansible.cfg](#2-ansiblecfg)
3. [inventory.ini](#3-inventoryini)
4. [group_vars](#4-group_vars)
5. [roboshop.yaml and ec2_output.yaml](#5-roboshopyaml-and-ec2_outputyaml)

**Part 2: Modules and templates**
6. [Modules used in this project](#6-modules-used-in-this-project)
7. [Templates (.j2)](#7-templates-j2)

**Part 3: Databases**
8. [01-mongodb.yaml](#8-01-mongodbyaml)
9. [02-redis.yaml](#9-02-redisyaml)
10. [03-mysql.yaml](#10-03-mysqlyaml)
11. [04-rabbitmq.yaml](#11-04-rabbitmqyaml)

**Part 4: Backend services**
12. [The common pattern for every app server](#12-the-common-pattern-for-every-app-server)
13. [05-catalogue.yaml](#13-05-catalogueyaml)
14. [06-user.yaml](#14-06-useryaml)
15. [07-cart.yaml](#15-07-cartyaml)
16. [08-shipping.yaml](#16-08-shippingyaml)
17. [09-payment.yaml](#17-09-paymentyaml)

**Part 5: Frontend**
18. [10-frontend.yaml](#18-10-frontendyaml)

**Part 6: Run it**
19. [Run order](#19-run-order)

**Wrap-up**
20. [What I learned](#20-what-i-learned)
21. [Interview one-liners](#21-interview-one-liners)

---

# Part 1: Project setup

## 1. Project structure

**Definition:** an Ansible **project** is one folder that holds everything Ansible needs: the **config** (`ansible.cfg`), the **list of servers** (`inventory.ini`), the **variables** (`group_vars/`), the **playbooks** (`*.yaml`) and the **files and templates** the playbooks copy to the servers. We run every command from inside this folder, so Ansible finds all of them automatically.

```
 roboshop-ansible-v1/
 ├── ansible.cfg              ← Ansible settings (which inventory, output style, log file)
 ├── ansible.cfg.full         ← reference: every possible setting (not used)
 ├── inventory.ini            ← the 10 servers, one group each
 ├── group_vars/
 │   ├── all.yaml             ← variables for every server (login, hostnames, passwords)
 │   ├── cart.yaml            ← only for the cart group
 │   ├── mongodb.yaml         ← only for the mongodb group
 │   └── mysql.yaml           ← only for the mysql group
 ├── roboshop.yaml            ← creates / deletes the 10 EC2 servers + DNS records
 ├── ec2_output.yaml          ← saved sample output of roboshop.yaml
 ├── 01-mongodb.yaml … 10-frontend.yaml   ← one playbook per server
 ├── mongo.repo, rabbitmq.repo            ← repo files copied as they are
 └── catalogue.service.j2 … roboshop.conf.j2   ← templates (filled with variables)
```

| File type | Copied how | Module |
|---|---|---|
| `.repo` | **As it is** (no variables inside) | `copy` |
| `.j2` | **Filled with variables first**, then copied | `template` |

---

## 2. ansible.cfg

**Definition:** `ansible.cfg` is Ansible's **settings file**. When it's in the folder we run commands from, Ansible reads it first, so we don't have to type options like `-i inventory.ini` on every command.

```ini
[defaults]
stdout_callback=yaml
inventory=inventory.ini
log_path = /home/ec2-user/roboshop-logs/ansible.log
```

The rest of the file is empty section headers (`[privilege_escalation]`, `[connection]`…), places where more settings could go.

| Line | What it does |
|---|---|
| `inventory=inventory.ini` | Use this inventory by default, so `ansible-playbook 01-mongodb.yaml` works without `-i` |
| `stdout_callback=yaml` | Print task results as readable YAML instead of one long JSON line |
| `log_path = …/ansible.log` | Also save every run's output to this log file |

> ⚠️ Create the log folder first (`mkdir -p /home/ec2-user/roboshop-logs`), or Ansible warns it can't write the log.

> ⚠️ On newer Ansible versions, `stdout_callback=yaml` fails with **"Invalid callback for stdout specified: yaml"**. Use `callback_result_format = yaml` under `[defaults]` instead; it does the same thing.

**`ansible.cfg.full`** is a reference copy with **every** setting Ansible has, all commented out. It's created with `ansible-config init --disabled > ansible.cfg.full`. Ansible doesn't read it; we look in it to find setting names.

---

## 3. inventory.ini

**Definition:** the **inventory** is the list of servers Ansible manages, grouped by name. A playbook's `hosts:` line picks a **group**, and Ansible runs the tasks on every server in it. Here each RoboShop server has **its own group**, and servers are listed by their **DNS name** (created by `roboshop.yaml`), not by IP, so the inventory never changes when IPs change.

```ini
[local]
localhost

[mongodb]
mongodb.abhignadevops.store

[redis]
redis.abhignadevops.store

[mysql]
mysql.abhignadevops.store

[rabbitmq]
rabbitmq.abhignadevops.store

[catalogue]
catalogue.abhignadevops.store

[user]
user.abhignadevops.store

[cart]
cart.abhignadevops.store

[shipping]
shipping.abhignadevops.store

[payment]
payment.abhignadevops.store

[frontend]
frontend.abhignadevops.store

; variables for all the servers
; [all:vars]
; ansible_user=ec2-user
; ansible_password=<ssh-password>
```

| Part | What it means |
|---|---|
| `[local]` + `localhost` | The Ansible server itself; used by `roboshop.yaml` to call AWS |
| `[mongodb]` + `mongodb.abhignadevops.store` | Group `mongodb` has one server. `hosts: mongodb` in `01-mongodb.yaml` targets it |
| `; [all:vars] …` | Commented out (`;` = comment in `.ini`). The login moved to `group_vars/all.yaml`, the cleaner place |

---

## 4. group_vars

**Definition:** `group_vars/` holds **variables in YAML files named after inventory groups**. Ansible loads them automatically: `all.yaml` applies to **every** server, and `cart.yaml` applies only to servers in the `[cart]` group. Playbooks and templates read them with `{{ name }}`, so a hostname or password is written **once** and used everywhere.

**`group_vars/all.yaml`** (every server):

```yaml
ansible_user: ec2-user
ansible_password: <ssh-password>
mongodb_host: mongodb.abhignadevops.store
redis_host: redis.abhignadevops.store
mysql_host: mysql.abhignadevops.store
rabbitmq_host: rabbitmq.abhignadevops.store
catalogue_host: catalogue.abhignadevops.store
user_host: user.abhignadevops.store
cart_host: cart.abhignadevops.store
shipping_host: shipping.abhignadevops.store
payment_host: payment.abhignadevops.store
mysql_root_password: <mysql-root-password>
shipping_db_user: shipping
shipping_db_password: <mysql-root-password>
rabbitmq_user: roboshop
rabbitmq_password: <rabbitmq-password>
```

| Variable(s) | Used for |
|---|---|
| `ansible_user`, `ansible_password` | **Special Ansible variables**: how to SSH into every server (user + password) |
| `*_host` | Server names, filled into the `.service.j2` and `roboshop.conf.j2` templates |
| `mysql_root_password`, `shipping_db_*` | MySQL root password and shipping's DB login |
| `rabbitmq_user`, `rabbitmq_password` | RabbitMQ login for payment |

> Password login needs the **`sshpass`** package on the Ansible server (`sudo dnf install sshpass -y`).

**Group-only files:**

| File | Content | Used by |
|---|---|---|
| `group_vars/cart.yaml` | `app_version: v4` | `07-cart.yaml` downloads `cart-{{ app_version }}.zip` = `cart-v4.zip` |
| `group_vars/mongodb.yaml` | `app_name: mongodb` | A commented-out test task in `01-mongodb.yaml` (proves group vars load) |
| `group_vars/mysql.yaml` | `mysql_root_password: <mysql-root-password>` | `03-mysql.yaml`. A group file **wins over** `all.yaml` for that group |

---

## 5. roboshop.yaml and ec2_output.yaml

**`roboshop.yaml`** creates (or deletes) the 10 EC2 servers and their Route 53 records. It's explained task by task in [Day 22, section 7](../README.md#7-lab-create-roboshop-servers--dns-records-with-ansible). Run it **first**, because every other playbook needs the servers and their DNS names.

**`ec2_output.yaml`** is a **saved copy of what `register: ec2_output` holds** after the create task: for each server, a long list of details (instance ID, AMI, private and public IP, security groups…).

| Why it's kept | How it helps |
|---|---|
| To see the **structure** | Shows `results` → `item` → `instances[0]` → `private_ip_address`, so we know the exact path to write in the Route 53 task |

---

# Part 2: Modules and templates

## 6. Modules used in this project

**Definition:** a **module** is a ready-made Ansible command for one job (install a package, create a user, copy a file). Each module **checks first** and only changes what's needed, which makes the playbook **idempotent**. Below are all the modules these playbooks use, with the shell command each one replaces.

| Module | What it does | Shell equivalent |
|---|---|---|
| `copy` | Copies a file from the Ansible server to the target, **as it is** | `scp` / `cp` |
| `template` | Fills `{{ variables }}` in a `.j2` file, then copies it | `sed` + `cp` |
| `package` / `dnf` | Installs (`present`) or removes (`absent`) packages | `dnf install -y` |
| `service` | Starts, stops, restarts, enables a service | `systemctl start / restart / enable` |
| `systemd_service` (`daemon_reload: true`) | Makes systemd re-read service files | `systemctl daemon-reload` |
| `replace` | Replaces **every** match of a pattern in a file | `sed -i 's/old/new/g'` |
| `lineinfile` | Makes sure **one line** in a file is exactly as given | `sed -i` on one line |
| `user` | Creates a Linux user | `useradd` |
| `file` | Creates a directory (`directory`) or deletes a file/folder (`absent`) | `mkdir -p`, `rm -rf` |
| `get_url` | Downloads a file from a URL | `curl -o` |
| `unarchive` (`remote_src: yes`) | Unzips a file that's **already on the target** | `unzip` |
| `community.general.npm` | Installs Node.js dependencies | `npm install` |
| `ansible.builtin.pip` | Installs Python dependencies (into a virtual env) | `pip install -r requirements.txt` |
| `community.rabbitmq.rabbitmq_user` | Creates a RabbitMQ user with permissions | `rabbitmqctl add_user` + `set_permissions` |
| `find` | Lists files in a folder | `find` |
| `command` / `shell` | Runs a Linux command when there's **no module** for it | the command itself |
| `debug` | Prints a message or variable | `echo` |

---

## 7. Templates (.j2)

**Definition:** a **template** is a file with `{{ variable }}` placeholders, written in the **Jinja2** format (hence `.j2`). The `template` module **replaces each placeholder with the variable's value** and copies the finished file to the server. We use it for any file that needs a server name or password, so the same file works for any domain.

```
 catalogue.service.j2                          on the catalogue server
 MONGO_URL="mongodb://{{ mongodb_host }}…"  ──►  MONGO_URL="mongodb://mongodb.abhignadevops.store…"
                         ▲
              group_vars/all.yaml: mongodb_host
```

A **`.service` file** tells **systemd** how to run an app as a background service: which Linux user runs it, its environment variables (where the databases are), the start command, and to restart it if it crashes.

---

# Part 3: Databases

## 8. 01-mongodb.yaml

**Definition:** **MongoDB** is a NoSQL database that stores data as JSON-like documents. In RoboShop it holds the **product catalogue** and the **users**. This playbook adds MongoDB's package repo, installs it, and makes it accept connections from the other servers.

```yaml
- name: configure mongodb server
  hosts: mongodb
  become: yes
  tasks:
  - name: copy mongo repo
    copy:
      src: mongo.repo
      dest: /etc/yum.repos.d/mongo.repo

  # - name: test the inventory variable
  #   debug:
  #     msg: "{{ app_name }}"

  - name: install mongodb server
    package:
      name: mongodb-org
      state: present

  - name: start and enable mongodb
    service:
      name: mongod
      state: started
      enabled: yes

  - name: allow remote connections
    replace:
      path: /etc/mongod.conf
      regexp: '127.0.0.1'
      replace: '0.0.0.0'

  - name: restart mongod
    service:
      name: mongod
      state: restarted
```

| Task | What it does | Why |
|---|---|---|
| `hosts: mongodb` + `become: yes` | Run on the mongodb server, as root (`sudo`) | Installing software needs root |
| `copy mongo repo` | Puts `mongo.repo` in `/etc/yum.repos.d/` | RHEL doesn't have MongoDB; the repo file tells `dnf` where to download it |
| `install mongodb server` | Installs `mongodb-org` | |
| `start and enable mongodb` | Starts `mongod` now and at every boot | |
| `allow remote connections` | Changes `127.0.0.1` → `0.0.0.0` in `/etc/mongod.conf` | By default MongoDB listens **only to itself**; `0.0.0.0` = listen on all network cards, so catalogue and user can connect |
| `restart mongod` | Restarts MongoDB | A config change is only read on restart |

**`mongo.repo`**, the file being copied:

```ini
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
enabled=1
gpgcheck=0
```

| Line | Means |
|---|---|
| `[mongodb-org-7.0]` | Repo ID |
| `baseurl=…` | Where `dnf` downloads MongoDB 7.0 for RHEL 9 |
| `enabled=1` | Use this repo |
| `gpgcheck=0` | Don't check package signatures (fine for a lab) |

---

## 9. 02-redis.yaml

**Definition:** **Redis** is an **in-memory** key-value database: very fast because data lives in RAM. In RoboShop it stores **shopping carts** and **user sessions**. This playbook installs Redis 7 and opens it to the other servers.

```yaml
- name: configure redis server
  hosts: redis
  become: yes
  tasks:
  - name: enable redis 7
    command: dnf module enable redis:7 -y

  - name: install redis
    package:
      name: redis
      state: present

  - name: allow remote connections
    replace:
      path: /etc/redis/redis.conf
      regexp: '127.0.0.1'
      replace: '0.0.0.0'

  - name: disable protected mode
    lineinfile:
      path: /etc/redis/redis.conf
      regexp: '^#?protected-mode yes'
      line: 'protected-mode no'

  - name: enable and start redis
    service:
      name: redis
      state: restarted
      enabled: yes
```

| Task | What it does | Why |
|---|---|---|
| `enable redis 7` | `dnf module enable redis:7` | RHEL has several Redis versions as **modules**; this picks version 7. There's no Ansible module for it, so we use `command` |
| `install redis` | Installs Redis 7 | |
| `allow remote connections` | `127.0.0.1` → `0.0.0.0` in `redis.conf` | Listen on all network cards |
| `disable protected mode` | Finds the line `protected-mode yes` (or `#protected-mode yes`) and makes it `protected-mode no` | Protected mode **rejects remote clients** even when listening on `0.0.0.0`. `^#?` = line starts with an optional `#` |
| `enable and start redis` | `restarted` + `enabled` | Restart so it reads the new config, and start at boot |

> We use `replace` for the IP (change **every** `127.0.0.1`) and `lineinfile` for protected mode (make sure **one exact line** exists).

---

## 10. 03-mysql.yaml

**Definition:** **MySQL** is a relational (SQL) database that stores data in tables. In RoboShop it holds the **cities/shipping data**. This playbook installs MySQL 8.4 and sets the root password.

```yaml
- name: configure mysql server
  hosts: mysql
  become: yes
  tasks:
  - name: enable mysql 8.4
    command: dnf module enable mysql:8.4 -y

  - name: install mysql server
    package:
      name: mysql-server
      state: present

  - name: enable and start mysql
    service:
      name: mysqld
      state: started
      enabled: yes

  # - name: setup mysql root password
  #   ansible.mysql.mysql_user:
  #     name: root
  #     host: localhost
  #     password: "{{ mysql_root_password }}"
  #     check_implicit_admin: true
  #     state: present

  - name: setup mysql root password
    command: mysql_secure_installation --set-root-pass "{{ mysql_root_password }}"
```

| Task | What it does | Why |
|---|---|---|
| `enable mysql 8.4` | Picks MySQL 8.4 from the dnf modules | |
| `install mysql server` | Installs `mysql-server` | |
| `enable and start mysql` | Starts `mysqld` now and at boot | |
| Commented-out `mysql_user` task | The **module** way to set the password | Needs extra Python libraries (PyMySQL) on the server, so the class used the command below |
| `setup mysql root password` | Sets the root password from `group_vars` | `command` because there's no simpler module; the password comes from `{{ mysql_root_password }}` |

> ⚠️ This last task isn't idempotent: on a 2nd run the root password is already set, so it may fail. That's the trade-off of using `command` instead of a module.

---

## 11. 04-rabbitmq.yaml

**Definition:** **RabbitMQ** is a **message queue**: one service drops a message in a queue and another picks it up later. In RoboShop, **payment** puts finished orders in RabbitMQ for the dispatch service. This playbook adds RabbitMQ's repos, installs it with **Erlang** (the language RabbitMQ runs on), and creates the app's user.

```yaml
- name: configure rabbitmq server
  hosts: rabbitmq
  become: yes
  tasks:
  - name: copy rabbitmq repo
    copy:
      src: rabbitmq.repo
      dest: /etc/yum.repos.d/rabbitmq.repo

  - name: install rabbitmq server
    dnf:
      name:
      - erlang
      - rabbitmq-server
      state: present

  - name: start and enable rabbitmq server
    service:
      name: rabbitmq-server
      state: started
      enabled: yes

  - name: create rabbitmq user
    community.rabbitmq.rabbitmq_user:
      user: roboshop
      password: <rabbitmq-password>
      vhost: /
      configure_priv: .*
      read_priv: .*
      write_priv: .*
      state: present
```

| Task | What it does | Why |
|---|---|---|
| `copy rabbitmq repo` | Adds RabbitMQ's package repos | RHEL doesn't ship RabbitMQ or a new enough Erlang |
| `install rabbitmq server` | Installs `erlang` and `rabbitmq-server` **in one task** | `name:` accepts a **list** |
| `start and enable` | Starts RabbitMQ now and at boot | |
| `create rabbitmq user` | Creates user `roboshop` with full rights on vhost `/` | The default `guest` user only works from the same server; payment connects remotely |

| Option | Means |
|---|---|
| `vhost: /` | The **virtual host** (like a separate namespace inside RabbitMQ); `/` is the default |
| `configure_priv / read_priv / write_priv: .*` | Allowed to create, read and write **all** queues (`.*` = everything) |

**`rabbitmq.repo`** defines 4 repos: `modern-erlang` + `modern-erlang-noarch` (Erlang) and `rabbitmq-el9` + `rabbitmq-el9-noarch` (RabbitMQ), each with two download mirrors (`yum1`, `yum2`). Unlike `mongo.repo`, it checks signatures:

| Line | Means |
|---|---|
| `baseurl=` (2 URLs) | Main + backup download server |
| `gpgcheck=1`, `repo_gpgcheck=1` | Verify packages and repo data are signed |
| `gpgkey=…` | Where to get the public keys for that check |
| `$basearch` | Replaced by the CPU type, e.g. `x86_64` |

---

# Part 4: Backend services

## 12. The common pattern for every app server

**Definition:** every RoboShop **app server** (catalogue, user, cart, shipping, payment) follows the **same steps**: install the language runtime, create a user to run the app, download the app code into `/app`, install its dependencies, write its systemd service file and start it. Only the runtime and a few extra steps differ, so we explain the pattern once here.

```yaml
  - name: create roboshop system user
    user:
      name: roboshop
      create_home: false
      home: /app
      system: true
      shell: /sbin/nologin
      comment: "roboshop system user"
```

| Option | Means | Why |
|---|---|---|
| `system: true` | A **system user** (for services, not people) | |
| `shell: /sbin/nologin` | Nobody can log in as this user | Security: if the app is hacked, the attacker gets no shell |
| `home: /app` + `create_home: false` | Its home is `/app`, but don't create it now | We create `/app` ourselves next |

**The steps, in order:**

| # | Task | Module | Shell equivalent | Why |
|---|---|---|---|---|
| 1 | Install runtime (Node.js / Java / Python) | `command` + `dnf` | `dnf module enable …` + `dnf install` | The app's language |
| 2 | Create `roboshop` user | `user` | `useradd --system …` | Run the app as a non-root user |
| 3 | Remove old `/app` | `file: state: absent` | `rm -rf /app` | Start clean, no files from an old version |
| 4 | Remove old zip | `file: state: absent` | `rm -f /tmp/<app>.zip` | So `get_url` always downloads the new one |
| 5 | Create `/app` | `file: state: directory` | `mkdir -p /app` | |
| 6 | Download the code | `get_url` | `curl -o /tmp/<app>.zip <url>` | |
| 7 | Unzip into `/app` | `unarchive` + `remote_src: yes` | `cd /app; unzip /tmp/<app>.zip` | `remote_src: yes` = the zip is **already on the target**, don't look for it on the Ansible server |
| 8 | Install dependencies | `npm` / `pip` / `mvn` | `npm install` … | Libraries the app needs |
| 9 | Copy the service file | `template` | `cp` + `sed` | Fills in the database hostnames |
| 10 | `daemon_reload` | `systemd_service` | `systemctl daemon-reload` | systemd must re-read a new/changed service file |
| 11 | Start and enable | `service: state: restarted, enabled: yes` | `systemctl enable --now` | `restarted` so a re-run loads the new code |

> Steps 3 and 4 delete and re-download every run, so these tasks always show `changed`. That's on purpose: every run deploys a fresh copy.

---

## 13. 05-catalogue.yaml

**Definition:** **catalogue** is the Node.js service that serves the **product list** to the website. It reads products from **MongoDB**. Besides the common pattern, it **loads the product data into MongoDB once**.

```yaml
- name: configure catalogue server
  hosts: catalogue
  become: yes
  tasks:
  - name: disable default nodejs
    command: dnf module disable nodejs -y

  - name: enable nodejs24
    command: dnf module enable nodejs:24 -y

  - name: install nodejs
    dnf:
      name: nodejs
      state: present

  - name: create roboshop system user
    user:
      name: roboshop
      create_home: false
      home: /app
      system: true
      shell: /sbin/nologin
      comment: "roboshop system user"

  - name: remove existing app directory
    file:
      path: /app
      state: absent

  - name: remove catalogue.zip
    file:
      path: /tmp/catalogue.zip
      state: absent

  - name: create app directory
    file:
      path: /app
      state: directory

  - name: download catalogue application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/catalogue-v4.zip
      dest: /tmp/catalogue.zip

  - name: unzip catalogue
    unarchive:
      src: /tmp/catalogue.zip
      dest: /app
      remote_src: yes

  - name: install dependencies
    community.general.npm:
      path: /app

  - name: copy catalogue service
    template:
      src: catalogue.service.j2
      dest: /etc/systemd/system/catalogue.service

  - name: copy mongo repo
    copy:
      src: mongo.repo
      dest: /etc/yum.repos.d/mongo.repo

  - name: install mongodb client
    dnf:
      name: mongodb-mongosh
      state: present

  - name: check products loaded or not
    command: mongosh --host "{{ mongodb_host }}" --quiet --eval 'db.getSiblingDB("catalogue").products.countDocuments()'
    register: product_count

  - name: print product_count
    debug:
      msg: "{{ product_count }}"

  - name: load the products
    shell: mongosh --host "{{ mongodb_host }}" < /app/db/master-data.js
    when: product_count.stdout | int == 0

  - name: daemon reload
    systemd_service:
      daemon_reload: true

  - name: start and enable catalogue
    service:
      name: catalogue
      state: restarted
      enabled: yes
```

**Runtime:** disable the default Node.js module, enable **Node.js 24**, install it. Dependencies with `community.general.npm` (`npm install` in `/app`).

**What's special: load products only once**

| Task | What it does |
|---|---|
| `copy mongo repo` + `install mongodb client` | Installs `mongosh`, the MongoDB **client**, so this server can talk to the MongoDB server |
| `check products loaded or not` | Counts documents in `catalogue.products`; `register: product_count` saves the answer |
| `print product_count` | Shows it (debugging) |
| `load the products` | Runs `master-data.js` into MongoDB **only when** the count is `0` |

| Expression | Means |
|---|---|
| `product_count.stdout` | The command's output, e.g. `"0"` or `"12"` (always **text**) |
| `\| int` | **Filter**: turn the text into a number |
| `when: … == 0` | Load only if there are no products yet. This is our own **idempotency check**, because `shell` has none |
| `shell` (not `command`) | Needed for the **`<` redirection** |

**`catalogue.service.j2`:**

```ini
[Unit]
Description=Catalogue Service
After=network-online.target

[Service]
User=roboshop
Environment=MONGO_URL="mongodb://{{ mongodb_host }}:27017/catalogue"
ExecStart=/bin/node /app/server.js
SyslogIdentifier=catalogue
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

| Line | Means |
|---|---|
| `After=network-online.target` | Start only after the network is up |
| `User=roboshop` | Run as the non-root user |
| `Environment=MONGO_URL=…` | Where MongoDB is: database `catalogue` on port `27017` |
| `ExecStart=/bin/node /app/server.js` | The start command |
| `SyslogIdentifier=catalogue` | Name in the logs (`journalctl -u catalogue`) |
| `Restart=on-failure` + `RestartSec=5` | If it crashes, restart it after 5 seconds |
| `WantedBy=multi-user.target` | Start at boot (this is what `enabled: yes` uses) |

---

## 14. 06-user.yaml

**Definition:** **user** is the Node.js service for **login and registration**. It stores users in **MongoDB** and sessions in **Redis**. The playbook is **exactly the common pattern** (Node.js 24, `user-v4.zip`, `npm`), with no extra steps.

```yaml
- name: configure user server
  hosts: user
  become: yes
  tasks:
  - name: disable default nodejs
    command: dnf module disable nodejs -y

  - name: enable nodejs24
    command: dnf module enable nodejs:24 -y

  - name: install nodejs
    dnf:
      name: nodejs
      state: present

  - name: create roboshop system user
    user:
      name: roboshop
      create_home: false
      home: /app
      system: true
      shell: /sbin/nologin
      comment: "roboshop system user"

  - name: remove existing app directory
    file:
      path: /app
      state: absent

  - name: remove user.zip
    file:
      path: /tmp/user.zip
      state: absent

  - name: create app directory
    file:
      path: /app
      state: directory

  - name: download user application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/user-v4.zip
      dest: /tmp/user.zip

  - name: unzip user
    unarchive:
      src: /tmp/user.zip
      dest: /app
      remote_src: yes

  - name: install dependencies
    community.general.npm:
      path: /app

  - name: copy user service
    template:
      src: user.service.j2
      dest: /etc/systemd/system/user.service

  - name: daemon reload
    systemd_service:
      daemon_reload: true

  - name: start and enable user
    service:
      name: user
      state: restarted
      enabled: yes
```

**`user.service.j2`**, only the environment lines differ from catalogue's:

```ini
Environment=REDIS_URL="redis://{{ redis_host }}:6379"
Environment=MONGO_URL="mongodb://{{ mongodb_host }}:27017/users"
```

| Line | Means |
|---|---|
| `REDIS_URL` | Redis on port `6379`, for sessions |
| `MONGO_URL` | MongoDB database `users` |

---

## 15. 07-cart.yaml

**Definition:** **cart** is the Node.js service that manages each user's **shopping cart**. It keeps carts in **Redis** and asks **catalogue** for product details. The playbook is the common pattern; the only difference is that the **download URL uses a variable** for the version.

```yaml
  - name: download cart application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/cart-{{ app_version }}.zip
      dest: /tmp/cart.zip
```

The other tasks are the same as `06-user.yaml`, with `user` replaced by `cart` (`/tmp/cart.zip`, `cart.service.j2`, service `cart`).

| What | Why |
|---|---|
| `cart-{{ app_version }}.zip` | `app_version: v4` comes from **`group_vars/cart.yaml`** → `cart-v4.zip`. To deploy a new version we change one variable, not the playbook |

**`cart.service.j2`** environment lines:

```ini
Environment=REDIS_HOST={{ redis_host }}
Environment=CATALOGUE_HOST={{ catalogue_host }}
Environment=CATALOGUE_PORT=8080
```

| Line | Means |
|---|---|
| `REDIS_HOST` | Where carts are stored |
| `CATALOGUE_HOST` + `CATALOGUE_PORT` | Where to ask for product details (port `8080`) |

---

## 16. 08-shipping.yaml

**Definition:** **shipping** is the **Java** service that calculates shipping cost by city. It's built with **Maven** (Java's build tool) into a `.jar` file and reads city data from **MySQL**. Besides the common pattern, the playbook **builds the app** and **loads the database once**.

```yaml
- name: configure shipping server
  hosts: shipping
  become: yes
  tasks:
  - name: enable maven 3.9
    command: dnf module enable maven:3.9 -y

  - name: install maven and java25
    dnf:
      name:
      - maven
      - java-25-openjdk-devel
      - maven-openjdk25 # installing this so that we no need to set JAVA_HOME again
      - mysql
      state: present

  - name: create roboshop system user
    user:
      name: roboshop
      create_home: false
      home: /app
      system: true
      shell: /sbin/nologin
      comment: "roboshop system user"

  - name: remove existing app directory
    file:
      path: /app
      state: absent

  - name: remove shipping.zip
    file:
      path: /tmp/shipping.zip
      state: absent

  - name: create app directory
    file:
      path: /app
      state: directory

  - name: download shipping application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/shipping-v4.zip
      dest: /tmp/shipping.zip

  - name: unzip shipping
    unarchive:
      src: /tmp/shipping.zip
      dest: /app
      remote_src: yes

  - name: mvn version without JAVA_HOME
    command: mvn --version
    args:
      chdir: /app
    register: mvn_default

  - name: print mvn version without JAVA_HOME
    debug:
      msg: "{{ mvn_default.stdout_lines }}"

  - name: build shipping
    command: mvn clean package
    args:
     chdir: /app

  - name: move shipping jar file
    command: mv target/shipping.jar shipping.jar
    args:
     chdir: /app

  - name: check cities data exist or not
    command: mysql -h "{{ mysql_host }}" -u root -p{{ mysql_root_password }} -N -B -e "SELECT COUNT(*) FROM cities.cities;"
    register: cities_count
    ignore_errors: true
    tags:
    - mysql

  - name: print cities_count
    debug:
      msg: "{{ cities_count }}"
    tags:
    - mysql

  - name: load cities data into mysql
    shell: mysql -h "{{ mysql_host }}" -u root -p{{ mysql_root_password }} < /app/db/master-data.sql
    when: cities_count.rc != 0 or cities_count.stdout | int == 0
    tags:
    - mysql

  - name: create app user in mysql
    shell: mysql -h "{{ mysql_host }}" -u root -p{{ mysql_root_password }} < /app/db/app-user.sql
    tags:
    - mysql

  - name: copy shipping service
    template:
      src: shipping.service.j2
      dest: /etc/systemd/system/shipping.service

  - name: daemon reload
    systemd_service:
      daemon_reload: true

  - name: start and enable shipping
    service:
      name: shipping
      state: restarted
      enabled: yes
```

The class file also has commented-out tasks that found the Java 25 path and set `JAVA_HOME` by hand. They're not needed, because `maven-openjdk25` makes Maven use Java 25 automatically.

**Runtime and build:**

| Task | What it does | Why |
|---|---|---|
| `enable maven 3.9` | Picks Maven 3.9 | |
| `install maven and java25` | Installs Maven, **Java 25**, `maven-openjdk25` and the `mysql` **client** | `maven-openjdk25` makes Maven use Java 25, so no `JAVA_HOME` setup is needed; the `mysql` client is for loading data |
| `mvn version …` + print | Shows which Java Maven uses (check) | `args: chdir: /app` = run inside `/app` (like `cd /app`) |
| `build shipping` | `mvn clean package` builds the app | Creates `target/shipping.jar` |
| `move shipping jar file` | `mv target/shipping.jar shipping.jar` | The service runs `/app/shipping.jar` |

**Load MySQL data only once:**

| Task | What it does |
|---|---|
| `check cities data exist or not` | Counts rows in `cities.cities`. `-N -B` = print only the number. `ignore_errors: true` because the **first** time the database doesn't exist and the command **fails** |
| `load cities data into mysql` | Loads `master-data.sql` **only if** the check failed (`rc != 0`, no database) **or** the count is `0` |
| `create app user in mysql` | Runs `app-user.sql`: creates the `shipping` DB user the app logs in with |

| Keyword | Means |
|---|---|
| `tags: - mysql` | A **label** on a task. `ansible-playbook 08-shipping.yaml --tags mysql` runs **only** the 4 MySQL tasks (handy to re-load data without rebuilding) |
| `cities_count.rc` | The **return code**: `0` = success, anything else = failed |

**`shipping.service.j2`** environment lines:

```ini
Environment=CART_ENDPOINT={{ cart_host }}:8080
Environment=DB_HOST={{ mysql_host }}
Environment=DB_USER={{ shipping_db_user }}
Environment=DB_PASSWORD={{ shipping_db_password }}
ExecStart=/bin/java -jar /app/shipping.jar
```

| Line | Means |
|---|---|
| `CART_ENDPOINT` | Where cart is |
| `DB_HOST`, `DB_USER`, `DB_PASSWORD` | MySQL login for the app |
| `ExecStart=/bin/java -jar …` | Run the jar with Java |

---

## 17. 09-payment.yaml

**Definition:** **payment** is the **Python** service that processes the checkout. It checks the **cart** and **user**, then sends the order to **RabbitMQ**. Its dependencies are installed into a **virtual environment** (a private folder of Python libraries just for this app).

```yaml
- name: configure payment server
  hosts: payment
  become: yes
  tasks:
  - name: install python3.14
    dnf:
      name:
      - python3.14
      - python3.14-pip
      state: present

  - name: create roboshop system user
    user:
      name: roboshop
      create_home: false
      home: /app
      system: true
      shell: /sbin/nologin
      comment: "roboshop system user"

  - name: remove existing app directory
    file:
      path: /app
      state: absent

  - name: remove payment.zip
    file:
      path: /tmp/payment.zip
      state: absent

  - name: create app directory
    file:
      path: /app
      state: directory

  - name: download payment application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/payment-v4.zip
      dest: /tmp/payment.zip

  - name: unzip payment
    unarchive:
      src: /tmp/payment.zip
      dest: /app
      remote_src: yes

  - name: install dependencies in virtual environment
    ansible.builtin.pip:
      requirements: /app/requirements.txt
      virtualenv: /app/.venv
      virtualenv_command: python3.14 -m venv

  - name: copy payment service
    template:
      src: payment.service.j2
      dest: /etc/systemd/system/payment.service

  - name: daemon reload
    systemd_service:
      daemon_reload: true

  - name: start and enable payment
    service:
      name: payment
      state: restarted
      enabled: yes
```

| Task | What it does | Why |
|---|---|---|
| `install python3.14` | Installs Python 3.14 and its `pip` | The app's runtime |
| `install dependencies in virtual environment` | Creates `/app/.venv` with `python3.14 -m venv`, then installs everything in `requirements.txt` into it | Keeps the app's libraries separate from the system Python |

**`payment.service.j2`:**

```ini
WorkingDirectory=/app
Environment=CART_HOST={{ cart_host }}
Environment=CART_PORT=8080
Environment=USER_HOST={{ user_host }}
Environment=USER_PORT=8080
Environment=AMQP_HOST={{ rabbitmq_host }}
Environment=AMQP_USER={{ rabbitmq_user }}
Environment=AMQP_PASS={{ rabbitmq_password }}
ExecStart=/app/.venv/bin/gunicorn --config gunicorn.conf.py --no-control-socket payment:app
```

| Line | Means |
|---|---|
| `WorkingDirectory=/app` | Run from `/app`, where `gunicorn.conf.py` is |
| `CART_*`, `USER_*` | Where cart and user are |
| `AMQP_*` | RabbitMQ host and login (AMQP = RabbitMQ's protocol) |
| `ExecStart=…/gunicorn … payment:app` | **gunicorn** = the web server that runs Python apps; `payment:app` = the `app` object in `payment.py`. It runs from the venv |

---

# Part 5: Frontend

## 18. 10-frontend.yaml

**Definition:** **frontend** is the **nginx** web server users open in the browser. It serves the website files (HTML, JS, images) and **forwards** every `/api/...` request to the right backend service (a **reverse proxy**). This playbook installs nginx, replaces its default page with the RoboShop site, and adds the proxy config.

```yaml
- name: configure frontend server
  hosts: frontend
  become: yes
  tasks:
  - name: enable nginx 1.26
    command: dnf module enable nginx:1.26 -y

  - name: install nginx
    dnf:
      name: nginx
      state: present

  - name: start and enable nginx
    service:
      name: nginx
      state: started
      enabled: yes

  - name: Find all contents inside the directory
    ansible.builtin.find:
      paths: /usr/share/nginx/html/
      recurse: true
      hidden: true
      file_type: any
    register: directory_contents

  - name: print directory content
    debug:
      msg: "{{ directory_contents }}"

  - name: Delete the discovered contents
    ansible.builtin.file:
      path: "{{ item.path }}"
      state: absent
    loop: "{{ directory_contents.files }}"

  - name: download frontend application
    get_url:
      url: https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip
      dest: /tmp/frontend.zip

  - name: unzip frontend
    unarchive:
      src: /tmp/frontend.zip
      dest: /usr/share/nginx/html/
      remote_src: yes

  - name: copy roboshop config
    template:
      src: roboshop.conf.j2
      dest: /etc/nginx/default.d/roboshop.conf

  - name: restart frontend
    service:
      name: nginx
      state: restarted
```

| Task | What it does | Why |
|---|---|---|
| `enable nginx 1.26` + install + start | Installs and starts nginx 1.26 | |
| `Find all contents` | Lists **everything** in `/usr/share/nginx/html/` (`recurse` = sub-folders too, `hidden` = dot files too, `file_type: any` = files and folders) and registers it | We want to empty the folder but keep the folder itself |
| `Delete the discovered contents` | **Loops** over `directory_contents.files` and deletes each `item.path` | Same as `rm -rf /usr/share/nginx/html/*`, done with modules |
| `download` + `unzip frontend` | Puts the RoboShop website into `/usr/share/nginx/html/` | nginx serves files from there |
| `copy roboshop config` | Fills `roboshop.conf.j2` and saves it in `/etc/nginx/default.d/` | nginx's default server loads every `.conf` in that folder |
| `restart frontend` | Restarts nginx | Load the new config |

**`roboshop.conf.j2`** (the important parts):

```nginx
location /api/catalogue/ { proxy_pass http://{{ catalogue_host }}:8080/; }
location /api/user/      { proxy_pass http://{{ user_host }}:8080/; }
location /api/cart/      { proxy_pass http://{{ cart_host }}:8080/; }
location /api/shipping/  { proxy_pass http://{{ shipping_host }}:8080/; }
location /api/payment/   { proxy_pass http://{{ payment_host }}:8080/; }

location / {
    expires -1;
    try_files $uri $uri/ /index.html;
}
```

| Part | Means |
|---|---|
| `location /api/catalogue/ { proxy_pass http://…:8080/; }` | A request to `/api/catalogue/products` goes to `catalogue:8080/products`. The **trailing `/`** removes `/api/catalogue` from the path |
| `location / { try_files … /index.html; }` | Any other path (`/cart`, `/product/RMC`) returns `index.html`; the React app in the browser shows the right page |

**The rest of the file, in short:**

| Block | What it does |
|---|---|
| `server_tokens off` + `add_header …` | Hides the nginx version and adds security headers |
| `add_header X-Request-Id $request_id` | Gives each request a unique ID, sent to the services too, to trace one click across servers |
| `gzip on` … | Compresses CSS/JS/JSON so pages load faster |
| `proxy_set_header …`, `proxy_*_timeout` | Passes the real client IP and request ID to the services; gives up after 5 s to connect / 30 s to answer |
| `error_page 502 / 504` + `@bad_gateway` / `@gateway_timeout` | If a service is down or too slow, answer with a clear **JSON** error |
| `location = /health { stub_status on; }` | `/health` shows nginx's connection counters |
| `location /images/` | Caches images for 1 hour; a missing image shows `placeholder.jpg` |
| `location /assets/` | JS/CSS files never change name, so the browser caches them forever |

---

# Part 6: Run it

## 19. Run order

**Definition:** the **run order** is the sequence that respects **dependencies**: servers must exist before we configure them, and databases must be ready before the apps that load data into them or connect to them.

```bash
ansible-playbook roboshop.yaml
```

```bash
ansible-playbook 01-mongodb.yaml
```

```bash
ansible-playbook 02-redis.yaml
```

```bash
ansible-playbook 03-mysql.yaml
```

```bash
ansible-playbook 04-rabbitmq.yaml
```

```bash
ansible-playbook 05-catalogue.yaml
```

```bash
ansible-playbook 06-user.yaml
```

```bash
ansible-playbook 07-cart.yaml
```

```bash
ansible-playbook 08-shipping.yaml
```

```bash
ansible-playbook 09-payment.yaml
```

```bash
ansible-playbook 10-frontend.yaml
```

| Order | Why |
|---|---|
| `roboshop.yaml` first | Creates the servers and the DNS names the inventory uses |
| Databases (01–04) before apps | catalogue loads products into MongoDB, shipping loads cities into MySQL |
| Frontend last | It proxies to all the services |

Then open `http://abhignadevops.store`. When you're done:

```bash
ansible-playbook roboshop.yaml -e "action=delete"
```

---

# Wrap-up

## 20. What I learned

- One **playbook per server**; `hosts:` picks the inventory **group** with the same name.
- **`group_vars/all.yaml`** holds the login and every hostname and password once; group files (`cart.yaml`) hold group-only values and win over `all.yaml`.
- **`copy`** sends files as they are (`.repo`); **`template`** fills `{{ }}` first (`.service.j2`, `roboshop.conf.j2`).
- Every app server follows the same pattern: runtime → user → fresh `/app` → download → unzip → dependencies → service file → `daemon_reload` → restart.
- Where we must use `command` / `shell`, we add our own check: `register` + `when` (load products / cities only if empty).
- `tags` let us run part of a playbook; `ignore_errors` handles a failure we expect.

```
 roboshop.yaml (servers + DNS) ──► 01–04 databases ──► 05–09 services ──► 10 frontend ──► open the site
```

## 21. Interview one-liners

| Question | Answer |
|---|---|
| `copy` vs `template`? | `copy` copies a file as it is; `template` fills Jinja2 `{{ }}` variables first |
| What is `remote_src: yes` in `unarchive`? | The zip is already on the target server, not on the Ansible server |
| `replace` vs `lineinfile`? | `replace` changes every match of a pattern; `lineinfile` makes sure one exact line exists |
| Why `daemon_reload` after copying a service file? | systemd only sees new or changed `.service` files after a reload |
| How do you make a `shell` task run only once? | Check first with `register`, then `when:` on the result (e.g. count is 0) |
| What are `tags`? | Labels on tasks; `--tags mysql` runs only the tasks with that tag |
| Why a `roboshop` user with `/sbin/nologin`? | Run the app as a non-root user nobody can log in as |
| Where do group_vars apply? | `all.yaml` to every host; `<group>.yaml` only to that group, and it wins over `all.yaml` |
