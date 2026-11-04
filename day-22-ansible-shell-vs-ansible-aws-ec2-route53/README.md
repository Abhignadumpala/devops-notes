# Day 22 - Ansible vs Shell Script, command vs shell, and Creating EC2 + Route 53 Records with Ansible

[← All notes](../README.md)

> **In short:** everything we did in shell scripts (variables, conditions, loops, functions, error handling) has the **same idea with a different name** in Ansible. Ansible is **idempotent** only when we use its **modules**; when no module exists we fall back to the `command` or `shell` module. Ansible can also talk to **AWS**: with the `amazon.aws` collection and the `boto3` Python library, one playbook creates all RoboShop EC2 servers and their **Route 53** DNS records. Shared values go in **`group_vars`**.

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | Shell vs Ansible words · idempotency · command vs shell · Ansible + AWS (boto3) · `register` with loops (`results`) · `group_vars` | What each one is and why we need it |
| **Part 2: Lab** | `roboshop.yaml`: create and delete all 10 RoboShop servers + Route 53 records with one playbook | Install boto3, create servers in a loop, read their IPs, create DNS records, override values with `-e`, delete everything |

**Before this:** [Day 21 - Facts, Conditions, Loops, Filters & Error Handling](../day-21-ansible-facts-conditions-loops-filters/README.md)

## Table of Contents

**Part 1: Concepts**
1. [Shell script vs Ansible: same ideas, different words](#1-shell-script-vs-ansible-same-ideas-different-words)
2. [Idempotency: only with modules](#2-idempotency-only-with-modules)
3. [command vs shell module](#3-command-vs-shell-module)
4. [How Ansible talks to AWS (boto3)](#4-how-ansible-talks-to-aws-boto3)
5. [register with a loop: the `results` list](#5-register-with-a-loop-the-results-list)
6. [group_vars](#6-group_vars)

**Part 2: Lab**
7. [Lab: create RoboShop servers + DNS records with Ansible](#7-lab-create-roboshop-servers--dns-records-with-ansible)

**Wrap-up**
8. [What I learned](#8-what-i-learned)
9. [Interview one-liners](#9-interview-one-liners)

---

# Part 1: Concepts

## 1. Shell script vs Ansible: same ideas, different words

**Definition:** a shell script and an Ansible playbook both **automate work on a server**, so they need the same building blocks: store values, decide, repeat, change data and handle failures. Ansible just gives each building block a **different keyword**. If you know the shell version, you already know the idea; you only learn the new word.

| Building block | Shell script | Ansible | What it means |
|---|---|---|---|
| **Variables** | `NAME=nginx`, read with `$NAME` | `vars:` → read with `{{ NAME }}` | Store a value once, use it many times |
| **Data types** | Everything is text (string) | int `10`, float `1.5`, string `"hi"`, bool `true`, **list** (`- item` or `[a, b]`), **map / dictionary** (`key: value` or `{ k: v }`) | What kind of value it is |
| **Conditions** | `if [ ... ]; then ... fi` | **`when:`** | Run something only if a check is true |
| **Loops** | `for pkg in git nginx; do ... done` | **`loop:`**, current value in **`{{ item }}`** | Repeat the same work for many values |
| **Functions** | `VALIDATE(){ ... }` (our own code) | **Filters**: `{{ name \| upper }}`, `{{ list \| length }}` | Change / manipulate data |
| **Error handling** | `set -e`, `trap`, `if [ $? -ne 0 ]` | **`ignore_errors: true`**, `register` + `when: out.rc != 0` | Decide what happens when a step fails |
| **Check before doing** | We write it: `dnf list installed nginx` | **Modules do it for us** (idempotency) | Don't redo work that's already done |

**Same job, both ways: install 3 packages**

```bash
#!/bin/bash
for pkg in git nginx mysql
do
  dnf list installed $pkg &>/dev/null      # our own check
  if [ $? -ne 0 ]; then
    dnf install $pkg -y
  else
    echo "$pkg already installed...SKIPPING"
  fi
done
```

```yaml
- name: install packages
  hosts: local
  connection: local
  become: yes
  tasks:
  - name: install packages
    package:
      name: "{{ item }}"
      state: present          # the module checks for us
    loop:
    - git
    - nginx
    - mysql
```

The shell script needs **our own check** (`dnf list installed` + `if`). The `package` module **checks by itself**: already installed → `ok`, not installed → installs it → `changed`.

> **Interview one-liner:** Ansible has the same building blocks as shell scripting under different names: variables with `{{ }}`, conditions with `when`, loops with `loop` and `item`, filters for data manipulation, and `ignore_errors` / `register` for error handling; the big difference is that modules are idempotent, so we don't write the "already done?" checks ourselves.

---

## 2. Idempotency: only with modules

**Definition:** **idempotency** means that running the same playbook **once or 10 times gives the same end result**. If the server is already in the right state, Ansible **changes nothing** and reports `ok`. Ansible gives us this **only when we use its modules** (`package`, `user`, `service`, `copy`…), because each module first **checks the current state** and acts only if something is different.

| Run | `user` module | `command: useradd roboshop` |
|---|---|---|
| 1st | Creates the user → `changed` | Creates the user |
| 2nd | User exists → `ok` (does nothing) | ❌ **Fails**: `user 'roboshop' already exists` |

**Rule:**

| Step in the playbook | What we use |
|---|---|
| Ansible **has a module** for this task (install a package, create a user, start a service, copy a file) | ✅ **Always the module**, so the step is idempotent |
| Ansible has **no module** for this task | Only then use the **`command` / `shell`** module for that one step, and add the check yourself with `register` + `when` ([Day 21, Step 15](../day-21-ansible-facts-conditions-loops-filters/README.md#step-15-error-handling-create-a-user-only-if-missing)) |

---

## 3. command vs shell module

**Definition:** the **`command`** and **`shell`** modules both **run a Linux command on the remote server**, for jobs where Ansible has no module. The difference is **how** they run it:

- **`shell`** runs the command **through a shell** (`/bin/sh`), so we get **full shell access**: the server's **environment variables** (`$HOME`, `$PATH`), **pipes** `|`, **redirections** `>` `>>`, `&&` and wildcards `*` all work.
- **`command`** runs the command **directly, without a shell**. It does **not** see the environment variables, and **pipes and redirections don't work**: `|` and `>` are passed to the command as plain text.

| | `command` | `shell` |
|---|---|---|
| Runs through a shell | ❌ No | ✅ Yes (`/bin/sh`) |
| Environment variables (`$HOME`) | ❌ | ✅ |
| Pipes `\|`, redirections `>` `>>` | ❌ | ✅ |
| `&&`, wildcards `*` | ❌ | ✅ |
| Safer (no shell tricks / injection) | ✅ | less |
| **Use for** | **Simple** commands: `id roboshop`, `mkdir /app` | **Complex** commands: pipes, redirections, or when we need the env |

For **simple commands**, use the **`command`** module. Example:

```
id roboshop
```

For **complex commands** with **pipes and redirections**, or when we need the server's env, use the **`shell`** module. Example:

```
cat /etc/passwd | grep roboshop > /tmp/users.txt
```

> **Interview one-liner:** Both run commands on the remote host; `command` runs it directly without a shell, so no env variables, pipes or redirections, and is safer for simple commands; `shell` runs it through `/bin/sh`, so pipes, redirections and env variables work, and we use it for complex commands.

---

## 4. How Ansible talks to AWS (boto3)

**Definition:** Ansible can create AWS resources (EC2 servers, DNS records, security groups…) using the modules in the **`amazon.aws` collection**, such as `amazon.aws.ec2_instance` and `amazon.aws.route53`. These modules are written in Python and call AWS through **`boto3`** (the official AWS SDK for Python) and **`botocore`** (its core library). So the **Ansible server must have boto3 and botocore installed**, and it needs **AWS permissions** (an IAM role on the server).

```
 playbook ──► amazon.aws.ec2_instance ──► boto3 / botocore (Python) ──► AWS API ──► EC2 server created
```

| Piece | What it is | How we get it |
|---|---|---|
| `amazon.aws` collection | The AWS modules for Ansible | Comes with the `ansible` package |
| `boto3` + `botocore` | Python libraries the modules use | `pip3.9 install botocore boto3` |
| AWS permissions | Allows creating EC2 and Route 53 records | **IAM role** attached to the Ansible server (no keys on disk) |

**Why `pip3.9`?** On RHEL 9, Ansible runs on **Python 3.9**. The libraries must be installed for the **same Python** Ansible uses; otherwise the module fails with `Failed to import the required Python library (botocore and boto3)`.

**Hosts for these playbooks:** we're not configuring a server, we're calling the AWS API, so the play runs on the **Ansible server itself**: `hosts: local` (the inventory group with `localhost`) + `connection: local`.

---

## 5. register with a loop: the `results` list

**Definition:** `register` saves a task's output in a variable. When the task has a **loop**, Ansible runs it once per item, so the registered variable holds **one result per item** inside a list called **`results`**. Each entry in `results` has the task's output for that round, plus **`item`** = the loop value that produced it.

We create servers in a loop and register the output as `ec2_output`:

```
 ec2_output
 └── results                          ← a LIST, one entry per server
     ├── [0]  item: mongodb
     │        instances[0].private_ip_address: 172.31.20.11
     ├── [1]  item: redis
     │        instances[0].private_ip_address: 172.31.25.40
     └── [2]  item: mysql
              instances[0].private_ip_address: 172.31.30.7
```

To create DNS records we **loop over `ec2_output.results`**. In the first round `item` is the first result (mongodb), and so on:

| Expression | Gives | Why |
|---|---|---|
| `{{ ec2_output.results }}` | The list of all results | Loop over this |
| `{{ item.item }}` | `mongodb` | The name from the **first** loop (the one that created the server) |
| `{{ item.instances[0].private_ip_address }}` | `172.31.20.11` | `instances` is a list; `[0]` = the first (only) server in it |

> **Interview one-liner:** When a looped task is registered, the variable has a `results` list with one entry per item; each entry has `item` (the loop value) and that round's output, so we can loop over `results` in the next task, e.g. `item.instances[0].private_ip_address`.

---

## 6. group_vars

**Definition:** **`group_vars`** is a folder next to the inventory or playbook where we keep **variables for a group of hosts in separate YAML files**. A file named after a group (`group_vars/web.yaml`) applies to that group, and **`group_vars/all.yaml`** applies to **every host**. It does the same job as **inventory variables**, but keeps them out of the inventory and the playbook, so they're easier to read and reuse.

```
 project/
 ├── ansible.cfg
 ├── inventory.ini
 ├── group_vars/
 │   └── all.yaml        ← variables for every host (also localhost)
 └── 01-create-instances.yaml
```

| Where the variable lives | Example | Good for |
|---|---|---|
| Inventory | `[web:vars]` + `port=80` | A few values |
| **`group_vars/<group>.yaml`** | `port: 80` | Many values, clean files |
| Playbook `vars:` | `vars:` block | Values used only in this playbook |

> **Interview one-liner:** `group_vars` holds variables per inventory group in separate YAML files (`all.yaml` for every host), doing the same job as inventory variables but keeping them clean and reusable.

---

# Part 2: Lab

## 7. Lab: create RoboShop servers + DNS records with Ansible

**Goal:** with **one playbook** (`roboshop.yaml`), create all **10 RoboShop servers** and their Route 53 records, and delete them all again, just by changing one variable (`action`).

| Record | Points to | Used by |
|---|---|---|
| `mongodb.abhignadevops.store`, `redis…`, `catalogue…` (one per server) | That server's **private IP** | Servers talking to each other inside the VPC |
| `abhignadevops.store` (the domain itself) | **frontend's public IP** | Users opening the website in a browser |

**Before you start:**

| Need | Why |
|---|---|
| Ansible server (RHEL 9) with Ansible and the `[local]` inventory from [Day 21](../day-21-ansible-facts-conditions-loops-filters/README.md#step-5-create-the-inventory) | Runs the playbook on itself |
| **IAM role** on the Ansible server with EC2 + Route 53 permissions | Lets boto3 call AWS without keys |
| Security groups **`roboshop-common`** + **`roboshop-<name>`** for each server (`roboshop-mongodb`, `roboshop-frontend`…) | Every server gets both SGs; the playbook doesn't create them |
| Route 53 **hosted zone** `abhignadevops.store` | Where the records go |

> ⚠️ This creates **10 real EC2 servers**. Run the delete (Step 8) when you finish.

### Step 1: Attach an IAM role to the Ansible server

In the console: **EC2 → select the Ansible server → Actions → Security → Modify IAM role** → choose a role with `AmazonEC2FullAccess` and `AmazonRoute53FullAccess` → **Update IAM role**.

```bash
aws sts get-caller-identity
```

**Expected:** the `Arn` shows `assumed-role/<your-role>/...` ✅. The server now has AWS access without any keys.

### Step 2: Install boto3 and botocore

```bash
sudo pip3.9 install botocore boto3
```

**What it does:** installs the AWS Python libraries for Python 3.9, the Python Ansible uses on RHEL 9.

```bash
ansible --version | grep "python version"
```

**Expected:** `python version = 3.9.x`, the same Python we installed boto3 for.

### Step 3: Write the playbook

```bash
vim roboshop.yaml
```

```yaml
- name: create ec2 instances and r53 records
  hosts: local
  connection: local
  vars:
    # ansible-playbook roboshop.yaml -e "instances=['mongodb', 'redis']"
    # ansible-playbook roboshop.yaml -e "action=delete"
    instances: ["mongodb", "redis", "mysql", "rabbitmq", "catalogue", "user", "cart", "shipping", "payment", "frontend"]
    action: create
    domain_name: abhignadevops.store
    ami_id: ami-0055977a6e828a4f4      # RHEL 9 DevOps practice AMI (check the current ID)
  tasks:
  - name: create ec2 instance
    amazon.aws.ec2_instance:
      name: "roboshop-{{ item }}"
      image_id: "{{ ami_id }}"
      instance_type: t3.micro
      security_groups:
      - roboshop-common
      - "roboshop-{{ item }}"
      region: us-east-1
    loop: "{{ instances }}"
    when: action == "create"
    register: ec2_output

  - name: create R53 record
    amazon.aws.route53:
      state: present
      zone: "{{ domain_name }}"
      record: "{{ item.item }}.{{ domain_name }}"   # mongodb.abhignadevops.store
      type: A
      ttl: 1
      value: "{{ item.instances[0].private_ip_address }}"
      overwrite: true
    loop: "{{ ec2_output.results }}"
    when: action == "create"

  - name: create R53 record for frontend
    amazon.aws.route53:
      state: present
      zone: "{{ domain_name }}"
      record: "{{ domain_name }}"                   # abhignadevops.store → frontend public IP
      type: A
      ttl: 1
      value: "{{ item.instances[0].public_ip_address }}"
      overwrite: true
    loop: "{{ ec2_output.results }}"
    when: action == "create" and item.item == "frontend"

  - name: delete R53 records
    amazon.aws.route53:
      state: absent
      zone: "{{ domain_name }}"
      record: "{{ item }}.{{ domain_name }}"
      ttl: 1
      type: A
    loop: "{{ instances }}"
    when: action == "delete"

  - name: delete R53 record for frontend
    amazon.aws.route53:
      state: absent
      zone: "{{ domain_name }}"
      record: "{{ domain_name }}"
      ttl: 1
      type: A
    when: action == "delete"

  - name: delete ec2 instances
    amazon.aws.ec2_instance:
      state: absent
      name: "roboshop-{{ item }}"
      region: us-east-1
      wait: false
    loop: "{{ instances }}"
    when: action == "delete"
```

**How the playbook works:**

| Part | What it does |
|---|---|
| `vars:` `instances`, `action`, `domain_name`, `ami_id` | Default values. `action: create` means a plain run **creates** everything |
| `when: action == "create"` / `"delete"` | Every task has a condition, so **one playbook does both jobs**: create tasks run on create, delete tasks run on delete, the rest are `skipping` |
| **Task 1** `create ec2 instance` | Loops over the 10 names, creates `roboshop-mongodb`, `roboshop-redis`… with **2 SGs** each (`roboshop-common` + its own) and saves everything in `ec2_output` |
| **Task 2** `create R53 record` | Loops over `ec2_output.results`: `item.item` = `mongodb`, `item.instances[0].private_ip_address` = its private IP → `mongodb.abhignadevops.store` |
| **Task 3** `create R53 record for frontend` | Same loop, but `item.item == "frontend"` keeps only frontend: the **domain itself** → frontend's **public IP**, so users can open the site |
| **Task 4** `delete R53 records` | Loops over the **names** (no `ec2_output` on delete) and removes `<name>.abhignadevops.store` |
| **Task 5** `delete R53 record for frontend` | Removes the domain record |
| **Task 6** `delete ec2 instances` | Terminates `roboshop-<name>`; `wait: false` = don't wait for termination to finish |

> 💡 **Variables from the command line (`-e`):** `-e` (extra vars) has the **highest priority**, so it overrides the values in `vars:`. That's how the comments at the top change what the same playbook does, with no file edits.

### Step 4: Create all 10 servers + records

```bash
ansible-playbook roboshop.yaml
```

**Expected:** Task 1 → `changed` for 10 servers, Task 2 → 10 records, Task 3 → `changed` only for frontend (`skipping` for the other 9), Tasks 4–6 → `skipping`. EC2 console: 10 servers named `roboshop-mongodb` … `roboshop-frontend` ✅.

### Step 5: Check the DNS records

```bash
nslookup mongodb.abhignadevops.store
```

**Expected:** mongodb's **private IP** (e.g. `172.31.20.11`).

```bash
nslookup abhignadevops.store
```

**Expected:** frontend's **public IP**. Open `http://abhignadevops.store` later, once the frontend is configured.

### Step 6: Create only some servers

```bash
ansible-playbook roboshop.yaml -e "instances=['mongodb', 'redis']"
```

**What it does:** `-e` replaces the list of 10 with just 2, so only those servers and records are created (or reported `ok` if they already exist).

### Step 7: Run it again (idempotency)

```bash
ansible-playbook roboshop.yaml
```

**Expected:** **no new servers**: `ec2_instance` finds the running servers by their **Name tag**, so it reports `ok` instead of creating duplicates. The shell script with `aws ec2 run-instances` ([Day 15](../day-15-shell-loops-error-handling-aws-cli/README.md)) would create 10 more every time.

### Step 8: Delete everything

```bash
ansible-playbook roboshop.yaml -e "action=delete"
```

**Expected:** Tasks 1–3 → `skipping`, Tasks 4–6 → records deleted and all 10 servers terminating ✅.

> ⚠️ Task 5 has no check for frontend, so **any** delete run also removes the domain record. `-e "action=delete instances=['mongodb']"` deletes mongodb **and** `abhignadevops.store`.

**Troubleshooting:**

| Error | Cause | Fix |
|---|---|---|
| `Failed to import the required Python library (botocore and boto3)` | boto3 installed for a different Python | `sudo pip3.9 install botocore boto3` |
| `Unable to locate credentials` / `UnauthorizedOperation` | No IAM role, or missing permissions | Attach the role (Step 1), check with `aws sts get-caller-identity` |
| `InvalidGroup.NotFound: The security group 'roboshop-xxx' does not exist` | A `roboshop-<name>` SG is missing | Create the SG, or check the region |
| `'dict object' has no attribute 'instances'` or an empty IP | Server details not ready when the record is made | Run the playbook again (servers report `ok`, records are filled in), or add `wait: true` to Task 1 |
| `Zone abhignadevops.store does not exist` | Wrong `domain_name` | Must match the hosted zone name exactly |

---

# Wrap-up

## 8. What I learned

**Part 1: Concepts**
- Shell and Ansible have the same building blocks: `$VAR` → `{{ }}`, `if` → `when`, `for` → `loop` + `item`, functions → filters, `set -e` → `ignore_errors` / `register`.
- Idempotency comes **only from modules**. `command` / `shell` are for jobs with no module.
- `command` = no shell (no env, no pipes or redirections), for simple commands. `shell` = full shell, for complex ones.
- AWS modules need **boto3 + botocore** (`pip3.9`) and an **IAM role**.
- A registered loop gives a **`results`** list: `item.item` = loop value, `item.instances[0].private_ip_address` = the server's IP.
- **`group_vars/all.yaml`** = variables for every host, kept outside the playbook.

**Part 2: Lab**
- One playbook (`roboshop.yaml`) creates all 10 servers, a private-IP record per server and the domain → frontend public IP. `-e "action=delete"` removes everything; running create again makes **no duplicates**.
- `-e` (extra vars) overrides `vars:`, so the same playbook can create only some servers or delete.

```
 vars / -e ──► ec2_instance (loop) ──► register ec2_output ──► loop ec2_output.results ──► route53 A records
```

## 9. Interview one-liners

| Question | Answer |
|---|---|
| Shell `if` in Ansible? | `when:` |
| Shell `for` loop in Ansible? | `loop:` with `{{ item }}` |
| When is Ansible idempotent? | Only when we use its modules; `command` / `shell` run every time |
| command vs shell? | `command` runs without a shell (no env, pipes, redirections); `shell` runs through `/bin/sh` |
| What do AWS modules need? | `amazon.aws` collection + `boto3` / `botocore` + AWS permissions (IAM role) |
| What is in a registered loop variable? | A `results` list, one entry per item, each with `item` and that round's output |
| What is `group_vars`? | A folder of per-group variable files (`all.yaml` = every host), same job as inventory variables |
| Why `hosts: local` + `connection: local` to create EC2? | We call the AWS API from the Ansible server; there's no remote server yet |
| How does one playbook both create and delete? | Every task has `when: action == "create"` or `"delete"`, and `-e "action=delete"` switches it |
| What does `-e` do? | Passes extra variables from the command line; they have the highest priority and override `vars:` |

---

**Source:** [amazon.aws.ec2_instance](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_instance_module.html) · [amazon.aws.route53](https://docs.ansible.com/ansible/latest/collections/amazon/aws/route53_module.html) · [Using loops: registering variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html#registering-variables-with-a-loop) · [Organizing host and group variables](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
