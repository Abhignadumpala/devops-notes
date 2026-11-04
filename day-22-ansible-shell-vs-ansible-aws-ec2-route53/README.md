# Day 22 - Ansible vs Shell Script, command vs shell, and Creating EC2 + Route 53 Records with Ansible

[← All notes](../README.md)

> **In short:** everything we did in shell scripts (variables, conditions, loops, functions, error handling) has the **same idea with a different name** in Ansible. Ansible is **idempotent** only when we use its **modules**; when no module exists we fall back to the `command` or `shell` module. Ansible can also talk to **AWS**: with the `amazon.aws` collection and the `boto3` Python library, one playbook creates all RoboShop EC2 servers and their **Route 53** DNS records. Shared values go in **`group_vars`**.

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | Shell vs Ansible words · idempotency · command vs shell · Ansible + AWS (boto3) · `register` with loops (`results`) · `group_vars` | What each one is and why we need it |
| **Part 2: Lab** | Create RoboShop EC2 servers + Route 53 records with one playbook | Install boto3, write `group_vars`, create servers in a loop, read their private IPs, create DNS records, clean up |

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

**Hosts for these playbooks:** we're not configuring a server, we're calling the AWS API, so the play runs on the **Ansible server itself**: `hosts: localhost` + `connection: local`.

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

**Goal:** with **one playbook**, create the RoboShop EC2 servers and a Route 53 **A record** for each one (`mongodb.abhignadevops.store` → its private IP). Then clean everything up.

**Before you start:**

| Need | Why |
|---|---|
| Ansible server (RHEL 9, `Redhat-9-DevOps-Practice` AMI) with Ansible installed ([Day 20](../day-20-ansible-data-formats-yaml/README.md)) | Runs the playbook |
| **IAM role** on the Ansible server with EC2 + Route 53 permissions | Lets boto3 call AWS without keys |
| A security group ID for RoboShop (e.g. `roboshop-common`) | Used by every new server |
| A Route 53 **hosted zone** (`abhignadevops.store`) | Where the DNS records go |

> ⚠️ This creates real EC2 servers. Do Step 8 (clean up) when you finish.

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

### Step 3: Create the project and group_vars

```bash
mkdir -p ~/ansible-aws/group_vars && cd ~/ansible-aws
```

```bash
vim group_vars/all.yaml
```

```yaml
ami_id: ami-0220d79f3f480ecf5          # Redhat-9-DevOps-Practice
instance_type: t3.micro
security_group: sg-xxxxxxxxxxxxxxxxx   # your roboshop-common SG ID
region: us-east-1
domain: abhignadevops.store            # your Route 53 hosted zone
instances:
- mongodb
- redis
- mysql
```

**What it does:** keeps every value in one place. The playbook only reads them (`{{ ami_id }}`), so changing the server list or the domain never touches the playbook.

### Step 4: Playbook part 1: create the servers

```bash
vim 01-roboshop-infra.yaml
```

```yaml
- name: create roboshop servers and DNS records
  hosts: localhost
  connection: local
  tasks:
  - name: create ec2 instances
    amazon.aws.ec2_instance:
      name: "{{ item }}"                 # Name tag: mongodb, redis, mysql
      image_id: "{{ ami_id }}"
      instance_type: "{{ instance_type }}"
      security_group: "{{ security_group }}"
      region: "{{ region }}"
      wait: true                         # wait until running, so the IP exists
    loop: "{{ instances }}"
    register: ec2_output

  - name: print the results
    debug:
      msg: "{{ item.item }} → {{ item.instances[0].private_ip_address }}"
    loop: "{{ ec2_output.results }}"
```

| Line | Means |
|---|---|
| `hosts: localhost` + `connection: local` | Run on the Ansible server itself: we call AWS, not a remote server |
| `loop: "{{ instances }}"` | One server per name in `group_vars/all.yaml` |
| `wait: true` | Don't continue until the server is running and has its IP |
| `register: ec2_output` | Save all 3 results in `ec2_output.results` |

```bash
ansible-playbook 01-roboshop-infra.yaml
```

**Expected:** `changed` for each server, then lines like `mongodb → 172.31.20.11`. Check the EC2 console: 3 servers named mongodb, redis, mysql ✅.

### Step 5: Playbook part 2: create the DNS records

Add this task at the end of the same playbook:

```yaml
  - name: create route53 records
    amazon.aws.route53:
      state: present
      zone: "{{ domain }}"
      record: "{{ item.item }}.{{ domain }}"                  # mongodb.abhignadevops.store
      type: A
      ttl: 1
      value: "{{ item.instances[0].private_ip_address }}"
      overwrite: true                                         # update if the record exists
    loop: "{{ ec2_output.results }}"
```

| Line | Means |
|---|---|
| `loop: "{{ ec2_output.results }}"` | One round per server we just created |
| `item.item` | The server name (`mongodb`) from the first loop |
| `item.instances[0].private_ip_address` | That server's private IP |
| `overwrite: true` | If the record already exists (old IP), replace it |

```bash
ansible-playbook 01-roboshop-infra.yaml
```

**Expected:** servers → `ok` (already exist), DNS records → `changed`.

### Step 6: Check the DNS records

```bash
nslookup mongodb.abhignadevops.store
```

**Expected:** `Address: 172.31.20.11`, the same private IP the playbook printed ✅. Also visible in **Route 53 → Hosted zones → abhignadevops.store**.

### Step 7: Run it again (idempotency)

```bash
ansible-playbook 01-roboshop-infra.yaml
```

**Expected:** **no new servers**. `ec2_instance` finds the running servers by their **Name tag** (and AMI), so it reports `ok` instead of creating duplicates. This is the advantage over the shell script, where `run-instances` would create 3 more servers every time.

**Troubleshooting:**

| Error | Cause | Fix |
|---|---|---|
| `Failed to import the required Python library (botocore and boto3)` | boto3 installed for a different Python | `sudo pip3.9 install botocore boto3` |
| `Unable to locate credentials` / `UnauthorizedOperation` | No IAM role, or missing permissions | Attach the role (Step 1), check with `aws sts get-caller-identity` |
| `InvalidGroup.NotFound` | Wrong SG ID, or a different region | Check `security_group` and `region` in `group_vars/all.yaml` |
| `'dict object' has no attribute 'instances'` / empty IP | Server not running yet | Keep `wait: true` on the EC2 task |
| `Zone abhignadevops.store does not exist` | Wrong `domain` | Must match the hosted zone name exactly |

### Step 8: Clean up

```bash
vim 02-roboshop-cleanup.yaml
```

```yaml
- name: delete roboshop servers and DNS records
  hosts: localhost
  connection: local
  tasks:
  - name: get server details
    amazon.aws.ec2_instance_info:
      region: "{{ region }}"
      filters:
        "tag:Name": "{{ item }}"
        instance-state-name: running
    loop: "{{ instances }}"
    register: info

  - name: delete route53 records
    amazon.aws.route53:
      state: absent
      zone: "{{ domain }}"
      record: "{{ item.item }}.{{ domain }}"
      type: A
      ttl: 1
      value: "{{ item.instances[0].private_ip_address }}"
    loop: "{{ info.results }}"
    when: item.instances | length > 0      # skip if the server is already gone

  - name: terminate ec2 instances
    amazon.aws.ec2_instance:
      state: absent
      region: "{{ region }}"
      filters:
        "tag:Name": "{{ item }}"
    loop: "{{ instances }}"
```

```bash
ansible-playbook 02-roboshop-cleanup.yaml
```

**Expected:** DNS records deleted, servers terminated ✅. The `when` with the `length` filter uses what we learned on Day 21.

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
- One playbook created the RoboShop servers and their Route 53 records; running it again created **no duplicates**.

```
 group_vars ──► ec2_instance (loop) ──► register ec2_output ──► loop ec2_output.results ──► route53 A records
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
| Why `hosts: localhost` to create EC2? | We call the AWS API from the Ansible server; there's no remote server yet |

---

**Source:** [amazon.aws.ec2_instance](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_instance_module.html) · [amazon.aws.route53](https://docs.ansible.com/ansible/latest/collections/amazon/aws/route53_module.html) · [Using loops: registering variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html#registering-variables-with-a-loop) · [Organizing host and group variables](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
