# Day 26 - Roles Recap, AWS Secrets Manager, include_role vs import_role, Dynamic Inventory & Parallelism

[← All notes](../README.md)

> **In short:** RoboShop V2 is organised with **roles**, and its passwords are encrypted with **Ansible Vault**. But a vault still lives in Git and needs a shared vault password, so we move the secrets to **AWS Secrets Manager**, a managed AWS service that stores and encrypts them, and Ansible **fetches them at run time** with a lookup plugin. A role can be pulled in two ways: **`import_role`** (static: loaded and checked **before** the play runs) and **`include_role`** (dynamic: loaded **while** the play runs). Instead of a hand-written `inventory.ini`, a **dynamic inventory** asks AWS which servers exist right now. Finally, **parallelism**: `forks` sets how many servers Ansible works on at the same time, and `serial` updates servers in **batches**, so the app stays up during a deployment (**rolling update**).

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | Roles recap · Vault recap and its limits · AWS Secrets Manager · `include_role` vs `import_role` · dynamic inventory · `forks` vs `serial` | What each one is, why we need it, and when to use which |
| **Part 2: Lab** | Store the MySQL password in Secrets Manager → give the Ansible server read access → fetch it with a lookup → compare include vs import → build an AWS dynamic inventory → run with `forks` and `serial` | Do it on the real Ansible server with the RoboShop V2 roles |

**Before this:** [Day 24 - Roles](../day-24-nohup-tags-venv-ansible-roles/README.md) · [Day 25 - Ansible Vault & Handlers](../day-25-ansible-vault-roboshop-v2/README.md)

## Table of Contents

**Part 1: Concepts**
1. [Roles recap](#1-roles-recap)
2. [Vault recap: why it's not enough](#2-vault-recap-why-its-not-enough)
3. [AWS Secrets Manager](#3-aws-secrets-manager)
4. [include_role vs import_role](#4-include_role-vs-import_role)
5. [Dynamic inventory](#5-dynamic-inventory)
6. [Parallelism: forks and serial](#6-parallelism-forks-and-serial)

**Part 2: Lab**
- [Lab setup](#lab-setup)
- [Step 1: Store the MySQL root password in Secrets Manager (laptop)](#step-1-store-the-mysql-root-password-in-secrets-manager-laptop)
- [Step 2: Find the Ansible server's IAM role](#step-2-find-the-ansible-servers-iam-role)
- [Step 3: Allow the role to read RoboShop secrets (laptop)](#step-3-allow-the-role-to-read-roboshop-secrets-laptop)
- [Step 4: Read the secret from the Ansible server](#step-4-read-the-secret-from-the-ansible-server)
- [Step 5: Fetch the secret with a lookup](#step-5-fetch-the-secret-with-a-lookup)
- [Step 6: Point mysql_root_password to Secrets Manager](#step-6-point-mysql_root_password-to-secrets-manager)
- [Step 7: Run the mysql role](#step-7-run-the-mysql-role)
- [Step 8: Compare import_role and include_role with when](#step-8-compare-import_role-and-include_role-with-when)
- [Step 9: See import catch an error before anything runs](#step-9-see-import-catch-an-error-before-anything-runs)
- [Step 10: Create the AWS dynamic inventory](#step-10-create-the-aws-dynamic-inventory)
- [Step 11: See the groups AWS gives us](#step-11-see-the-groups-aws-gives-us)
- [Step 12: Run a role with the dynamic inventory](#step-12-run-a-role-with-the-dynamic-inventory)
- [Step 13: Watch forks at work](#step-13-watch-forks-at-work)
- [Step 14: Run a rolling update with serial](#step-14-run-a-rolling-update-with-serial)
- [Step 15: Clean up](#step-15-clean-up)

**Wrap-up**
- [Troubleshooting](#troubleshooting)
- [What I learned](#what-i-learned)
- [Interview questions](#interview-questions)

---

# Part 1: Concepts

## 1. Roles recap

**Definition:** a **role** is a **standard folder structure** for creating and managing playbooks. It breaks one long playbook into parts (tasks, variables, templates, files, handlers, dependencies), and Ansible **loads `main.yaml` from each folder automatically**.

```
roles/catalogue/
├── tasks/main.yaml       ← the steps
├── handlers/main.yaml    ← run only when notified (restart on a config change)
├── vars/main.yaml        ← role variables (high priority)
├── defaults/main.yaml    ← default variables (lowest priority)
├── templates/            ← *.j2 files
├── files/                ← files copied as they are
├── meta/main.yaml        ← dependencies: roles that run first
└── library/, module_utils/, lookup_plugins/   ← custom modules and plugins (optional)
```

| Why roles | Example in RoboShop V2 |
|---|---|
| No repeated code | `roles/common/tasks/app-setup.yaml` is written once and used by 5 app roles |
| Short, readable files | `roles/cart/tasks/main.yaml` is just 4 calls to `common` |
| One playbook for every server | `ansible-playbook main.yaml -e "component=cart"` |

### What goes in each folder (simple)

| Folder | In simple words | What the file contains | Example |
|---|---|---|---|
| `tasks/` | **The to-do list.** The steps to set up the server | `main.yaml`: a list of tasks (install, copy, start). Can also call other task files | `- name: install nodejs` / `dnf: name=nodejs` |
| `handlers/` | **"Do this only if something changed."** Tasks that wait for a `notify:` | `main.yaml`: tasks like restart a service | `- name: restart nginx` / `service: state=restarted` |
| `vars/` | **Fixed values** for this role. Hard to override | `main.yaml`: `key: value` lines | `component: catalogue` |
| `defaults/` | **Suggested values.** Used only if nobody sets them anywhere else | `main.yaml`: `key: value` lines | `app_version: v4` |
| `templates/` | **Files with blanks** (`{{ }}`) that Ansible fills in, then copies | `*.j2` files | `catalogue.service.j2` with `{{ mongodb_host }}` |
| `files/` | **Files copied as they are**, nothing filled in | Any plain file | `mongo.repo` |
| `meta/` | **"Run these roles first,"** plus info about the role (author, platforms) | `main.yaml`: `dependencies:` list | `dependencies: - role: common` |
| `library/` | **Your own modules**, when no built-in module does the job | Python files (`*.py`) | `my_check.py` |
| `module_utils/` | **Shared helper code** for your own modules | Python files your modules import | `helpers.py` |
| `lookup_plugins/` (and other `*_plugins/`) | **Your own plugins**, e.g. a lookup that fetches a value from another system | Python files | `my_secret.py` |
| `tests/` | **A small test playbook** for the role (made by `ansible-galaxy role init`) | `test.yml` + `inventory` | Run the role on localhost |
| `README.md` | **How to use the role** | Text | Variables it needs, an example |

**Which ones do I really need?**

| Need | Folders |
|---|---|
| Always | `tasks/` |
| Often | `templates/`, `files/`, `handlers/`, `defaults/` |
| Sometimes | `vars/`, `meta/` |
| Rarely (advanced) | `library/`, `module_utils/`, `lookup_plugins/` |

> Only create the folders you use. Ansible ignores the ones that don't exist, and in RoboShop V2 most roles have just `tasks/` and `templates/`.

📖 Full guide: [Day 24, sections 5–10](../day-24-nohup-tags-venv-ansible-roles/README.md#5-why-roles-the-problems-with-our-v1-playbooks).

---

## 2. Vault recap: why it's not enough

**Definition:** **Ansible Vault** encrypts passwords (AES256) so they can sit in Git. To decrypt them, Ansible needs the **vault password**, typed with `--ask-vault-pass` or read from a file on the Ansible server. 📖 [Day 25](../day-25-ansible-vault-roboshop-v2/README.md).

Vault fixed plain-text passwords, but as the project grows it gets hard to maintain:

| Problem with Vault | Why it hurts |
|---|---|
| **The vault password must be shared** | Every person and every server that runs playbooks needs the same password file, copied by hand |
| **Changing a password is slow** | Decrypt → edit → encrypt → commit → push → pull on the server. Easy to make a mistake |
| **No audit trail** | Anyone with the vault password sees **every** secret, and nothing records who read what |
| **Secrets are tied to one repo** | Another tool (a pipeline, another project) needs its own copy |
| **Still in Git** | Encrypted, but if the vault password ever leaks, every old commit can be decrypted |

So we keep the secrets **outside Git**, in AWS.

---

## 3. AWS Secrets Manager

**Definition:** **AWS Secrets Manager** is a managed AWS service (PaaS) that **stores secrets** such as passwords and API keys. Each secret has a **name** and a **value** (key → value). **AWS takes care of the encryption** (with KMS), and access is controlled with **IAM**. Ansible **fetches the value at run time**, so the password never sits in the repo, not even encrypted.

### Why we moved from Vault to Secrets Manager

In RoboShop V2 we kept the passwords in an encrypted `vault.yaml`. It worked, but it became hard to maintain:

| With Vault, every time… | We had to… |
|---|---|
| We **added or changed a password** | Open the vault (`ansible-vault edit`), change it, save. The file is re-encrypted |
| The vault file changed | Copy the new encrypted text into the repo, commit, push to GitHub, then `git pull` on the Ansible server |
| Someone new (or a new server) ran the playbooks | Share the **vault password** with them by hand. It never goes to GitHub, so it has to be copied around |

So we moved the secrets to **AWS Secrets Manager**:

- It stores **key → value pairs**, but for **confidential information** (passwords, API keys).
- **AWS takes care of the encryption** (KMS). We don't encrypt anything ourselves.
- **Ansible fetches the values** from Secrets Manager **at run time**. Nothing secret is in GitHub anymore, not even encrypted.
- To change a password, we update it **once in AWS**. No code change, no push.

### Why AWS and not a separate tool?

There are separate secrets tools too (for example HashiCorp Vault, a server you install and run yourself). But our servers already run on AWS, so keeping the secrets **inside AWS** makes integration easy:

| We need | Separate tool | Inside AWS |
|---|---|---|
| Who can read a secret | Its own users and tokens | **IAM** roles we already use (the Ansible server's EC2 role) |
| Encryption | Set it up ourselves | **KMS**, automatic |
| Who read what | Its own logs | **CloudTrail**, with our other AWS logs |
| Running it | Install, patch and back up another server | **Managed by AWS** (PaaS) |

```
 Before:  passwords ─► vault.yaml (encrypted) ─► GitHub ─► Ansible server + vault password
 Now:     passwords ─► AWS Secrets Manager ◄── Ansible server asks at run time (IAM role)
```

> **Interview one-liner:** Vault became hard to maintain, because every new password meant editing, re-encrypting and pushing the vault file and sharing the vault password. We moved to AWS Secrets Manager: AWS encrypts the key-value secrets, Ansible fetches them at run time through IAM, and since everything is already on AWS, the integration is simple with no extra tool to run.

### How Ansible gets a secret

```
 Ansible server                                AWS
 ┌──────────────────────────────┐   IAM role   ┌──────────────────────────────┐
 │ group_vars/all/main.yaml     │ ───────────► │ Secrets Manager              │
 │ mysql_root_password:         │  GetSecret-  │ roboshop/dev/                │
 │  "{{ lookup('amazon.aws.     │  Value       │   mysql_root_password = ●●●● │
 │   secretsmanager_secret',    │ ◄─────────── │ (encrypted with KMS)         │
 │   'roboshop/dev/...') }}"    │  the value   └──────────────────────────────┘
 └──────────────┬───────────────┘
                │ SSH, the value is used inside the task
                ▼
          mysql server
```

| Piece | What it does |
|---|---|
| **Secret** | Name `roboshop/dev/mysql_root_password`, value = the real password |
| **IAM role** on the Ansible server | Gives permission to **read** the secret (`secretsmanager:GetSecretValue`). No access keys, no vault password |
| **Lookup plugin** `amazon.aws.secretsmanager_secret` | Runs **on the Ansible server** (it's a plugin, not a module), calls AWS, returns the value |
| **`no_log: true`** | Keeps the value out of the playbook output |

> **Why a lookup and not a module?** A module runs on the **target** server; a plugin runs on the **Ansible server**. The Ansible server has the IAM role, so the secret is fetched there and only the value is used on the target. (Module vs plugin: [Day 24, section 11](../day-24-nohup-tags-venv-ansible-roles/README.md#11-module-vs-plugin).)

### Naming secrets

Use a path-like name: **`<project>/<env>/<name>`**, for example `roboshop/dev/mysql_root_password`. Then one IAM policy can allow `roboshop/dev/*`, and dev can't read prod.

### Vault vs Secrets Manager

| | Ansible Vault | AWS Secrets Manager |
|---|---|---|
| Where secrets live | Encrypted file **in Git** | **In AWS**, encrypted with KMS |
| Who can read | Anyone with the vault password | Only IAM roles/users you allow |
| Change a password | Decrypt → edit → encrypt → push | Update in AWS, **no code change** |
| Who read it? | Unknown | Logged in **CloudTrail** |
| Automatic rotation | ❌ | ✅ (e.g. RDS database passwords) |
| Cost | Free | About $0.40 per secret per month + API calls |
| Best for | Small projects, no AWS | Teams and production on AWS |

> **Cheaper option:** **SSM Parameter Store** (`SecureString`) also stores encrypted values, with no rotation, and standard parameters are free. Lookup: `amazon.aws.aws_ssm`.

> **Interview one-liner:** we moved secrets from Ansible Vault to AWS Secrets Manager: the Ansible server reads them at run time with a lookup plugin through its IAM role, so Git has no secrets, passwords change in one place, and every read is logged in CloudTrail.

---

## 4. include_role vs import_role

**Definition:** both pull a role into the middle of a play, as tasks. **`import_role`** is **static**: Ansible reads and checks the role **before the play starts**, as if its tasks were pasted in. **`include_role`** is **dynamic**: Ansible reads the role **only when it reaches that line** while the play runs.

```yaml
- name: nodejs setup (dynamic)
  include_role:
    name: common
    tasks_from: nodejs

- name: nodejs setup (static)
  import_role:
    name: common
    tasks_from: nodejs
```

```
 import_role:  [ read + check ALL tasks ] ──► run task 1 ──► run task 2 ──► ...
                     ▲ errors found here, nothing has run yet

 include_role: run task 1 ──► run task 2 ──► reach include ──► [ read role ] ──► run its tasks
                                                                    ▲ errors found here, earlier tasks already ran
```

### The differences

| | `import_role` (static) | `include_role` (dynamic) |
|---|---|---|
| **When it's loaded** | Before the play runs (parse time) | When Ansible reaches it (run time) |
| **Errors in the role** | Found **before** anything runs → nothing executes | Found **only when reached** → earlier tasks already ran |
| **`when:` on it** | **Copied to every task** in the role and checked **before each task** again | Checked **once**, at the include line. If true, all tasks run; not checked again per task |
| **`tags:` on it** | **Copied to every task** in the role automatically | Apply only to the include line. With `--tags`, the include **and** the inner task must both match |
| **Loops** (`loop:`) | ❌ Don't work | ✅ Work |
| **Variable in the role name** (`"{{ component }}"`) | ❌ Only if the value is known before the play starts | ✅ Works |
| `--list-tasks` / `--list-tags` | ✅ Shows the role's tasks | ❌ Doesn't show them (not loaded yet) |

### `when:` example: why "checked again" matters

```yaml
- name: setup
  import_role:          # or include_role
    name: example
  when: run_setup == true
```

Say a task inside the role changes `run_setup` to `false` halfway:

| | What happens |
|---|---|
| `import_role` | The condition is checked **before every task**, so the tasks after the change are **skipped** |
| `include_role` | The condition was checked **once** at the start; all tasks **keep running** |

When the condition is false from the start: `import_role` shows **every task** as `skipping`, and `include_role` shows **one** `skipping` line.

### Which one to use?

| Use | When |
|---|---|
| `import_role` | Fixed roles you always run; you want errors caught **before** anything changes and tags to apply everywhere |
| `include_role` | The role name comes from a variable, you need a loop, or you include it only in some cases. **RoboShop V2 uses `include_role`** to call `common` with `tasks_from` |

> **Interview one-liner:** `import_role` is static: it's checked before the play runs, and `when`/`tags` are copied to every task; `include_role` is dynamic: it loads at run time, `when` is checked once at the include, and only include supports loops and variable role names.

---

## 5. Dynamic inventory

**Definition:** a **dynamic inventory** builds the list of servers **at run time** by asking a source like AWS, instead of reading a hand-written `inventory.ini`. On AWS, the **`amazon.aws.aws_ec2` inventory plugin** asks EC2 which instances are **running** in a region, reads their **tags**, and groups them, so Ansible always has the current servers and IPs.

### The problem with a static inventory

| Static `inventory.ini` | What goes wrong |
|---|---|
| We write each server's name or IP by hand | 10 more frontend servers = 10 more lines to add |
| Auto Scaling adds or removes servers | The file is out of date in minutes |
| IPs change after a terminate + create | Wrong or missing hosts |

### How the AWS plugin works

```
 ansible-playbook -i inventory.aws_ec2.yaml ...
        │
        ▼
 aws_ec2 plugin ──► AWS EC2 API (region us-east-1)
        │            "which instances are running?"
        ▼
 filters: running + Name tag starts with roboshop-*
        │
        ▼
 groups by the Component tag  ──►  [frontend] 10.0.1.5, 10.0.1.9, …
                                    [catalogue] 10.0.2.7
        │
        ▼
 Ansible connects to each private IP
```

### The inventory file

The file name **must end with `aws_ec2.yaml`** (or `aws_ec2.yml`); that's how Ansible knows which plugin reads it. Example `inventory.aws_ec2.yaml`:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  instance-state-name: running
  tag:Name: roboshop-*
keyed_groups:
  - key: tags.Component      # a tag on each instance, e.g. Component=frontend
    prefix: ""
    separator: ""
hostnames:
  - private-ip-address       # connect with the private IP (same VPC)
```

| Setting | What it does |
|---|---|
| `plugin` | Use the AWS EC2 plugin |
| `regions` | Which regions to search |
| `filters` | Only running instances whose Name starts with `roboshop-` |
| `keyed_groups` | Make one group per value of the `Component` tag: `frontend`, `catalogue`, … These match `hosts: "{{ component }}"` in `main.yaml` |
| `hostnames` | Show and connect to each host by its private IP |

> **Why a `Component` tag?** The `Name` tag has a hyphen (`roboshop-frontend`), and group names should be plain words. A tag `Component=frontend` gives a clean group name that matches our role names.

**Needs:** `boto3` on the Ansible server, the `amazon.aws` collection, and IAM permission `ec2:DescribeInstances`.

### Scale example

Creating 10 frontend servers in one command:

```bash
aws ec2 run-instances --image-id <ami-id> --instance-type t3.micro --security-groups roboshop-common --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=roboshop-frontend},{Key=Component,Value=frontend}]' --count 10
```

The `frontend` group now has **10 hosts**, and we didn't edit any inventory file. `ansible-playbook main.yaml -i inventory.aws_ec2.yaml -e "component=frontend"` configures all 10.

> **Interview one-liner:** a dynamic inventory asks the cloud at run time which servers exist; on AWS the `aws_ec2` plugin (file name ending in `aws_ec2.yaml`) lists running instances, filters them by tags, and groups them, so scaling needs no inventory edits.

---

## 6. Parallelism: forks and serial

**Definition:** **`forks`** is **how many servers Ansible works on at the same time**. It runs each task on up to that many servers at once, then the next batch, and only then moves to the next task. The default is **5**. **`serial`** splits the servers into **batches** and runs the **whole play** on one batch before starting the next. That's a **rolling update**.

### forks: speed

With 10 servers and the default `forks = 5`:

```
 Task 1: servers 1-5 together → servers 6-10 together
 Task 2: servers 1-5 together → servers 6-10 together
 ...
```

| Set it | Where |
|---|---|
| For every run | `ansible.cfg` → `[defaults]` → `forks = 20` |
| For one run | `ansible-playbook ... -f 20` |

More forks = faster, but uses more CPU and memory on the Ansible server.

### serial: safe deployments

**The problem:** 100 frontend servers. Without `serial`, every task runs on all 100: delete the old code on all → download the new code on all → restart all. During that time, **all 100 are down** at once, and the website is down.

**With `serial: 10`:** the whole play runs on 10 servers, then the next 10, and so on.

```yaml
- name: deploy frontend
  hosts: frontend
  become: yes
  serial: 10
  roles:
  - frontend
```

| Batch | Being updated (down) | Still serving | New code | Old code |
|---|---|---|---|---|
| 1 | 10 | 90 | 10 | 90 |
| 2 | 10 | 90 | 20 | 80 |
| 3 | 10 | 90 | 30 | 70 |
| … | … | … | … | … |
| 10 | 10 | 90 | 100 | 0 |

At most **10 servers are down at any time**; the other 90 keep serving users. If batch 1 fails, the play stops, and only 10 servers are affected.

| Option | Meaning |
|---|---|
| `serial: 10` | 10 servers per batch |
| `serial: "10%"` | 10% of the servers per batch |
| `serial: [1, 5, 10]` | Batches grow: 1 (a canary), then 5, then 10 at a time |
| `max_fail_percentage: 10` | Stop everything if more than 10% of a batch fails |

### forks vs serial

| | `forks` | `serial` |
|---|---|---|
| Controls | How many servers run **a task** at the same time | How many servers run **the whole play** before the next batch |
| Goal | **Speed** | **Safety / no downtime** (rolling update) |
| Set in | `ansible.cfg` or `-f` | The play (`serial:`) |
| Default | 5 | All servers in one batch |

> **Interview one-liner:** `forks` is how many hosts Ansible runs a task on at once (speed, default 5); `serial` runs the whole play on one batch of hosts before the next, which gives a rolling update with no full downtime.

---

# Part 2: Lab

## Lab setup

| What | Details |
|---|---|
| **Ansible server** | The RHEL 9 Ansible server from the RoboShop labs, with an **IAM role** attached (it already creates EC2 and Route 53 records) |
| **Project** | `~/roboshop-with-ansible-v2` (roles, run with `main.yaml -e "component=<name>"`) |
| **Servers** | RoboShop servers created by `roboshop.yaml` (the `mysql` server for Steps 4–7) |
| **Laptop** | AWS CLI configured with admin access (for the IAM change) |
| **Passwords in this note** | Shown as `<placeholders>`. Type your real values only in your terminal |

In my case, the Ansible server and the RoboShop servers already exist from the earlier labs. If you're doing this for the first time, build them first with the [RoboShop V1 lab](https://github.com/Abhignadumpala/roboshop-with-ansible-v1/blob/main/LAB.md).

```bash
cd ~/roboshop-with-ansible-v2
```

```bash
ansible-galaxy collection list amazon.aws
```

**Expected:** `amazon.aws` with a version number ✅. (Missing? `ansible-galaxy collection install amazon.aws`.)

---

## Step 1: Store the MySQL root password in Secrets Manager (laptop)

```bash
aws secretsmanager create-secret --name roboshop/dev/mysql_root_password --secret-string '<mysql-root-password>' --region us-east-1
```

**What it does:** creates a secret with the name `roboshop/dev/mysql_root_password`. AWS encrypts the value with its default KMS key.
**Expected:** JSON with `"ARN"` and `"Name": "roboshop/dev/mysql_root_password"` ✅. You can also see it in **AWS Console → Secrets Manager**.

> 💡 The command goes into your shell history. In real work, use the console or `--secret-string file://secret.txt`, then delete the file.

---

## Step 2: Find the Ansible server's IAM role

On the Ansible server:

```bash
aws sts get-caller-identity --query Arn --output text
```

**What it does:** shows who the server is to AWS.
**Expected:** `arn:aws:sts::<account-id>:assumed-role/<role-name>/i-0abc…`. The part after `assumed-role/` is the **role name** ✅.

---

## Step 3: Allow the role to read RoboShop secrets (laptop)

```bash
aws iam put-role-policy --role-name <role-name> --policy-name roboshop-read-secrets --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":"arn:aws:secretsmanager:us-east-1:<account-id>:secret:roboshop/dev/*"}]}'
```

**What it does:** adds a policy that lets the role **read only** secrets whose names start with `roboshop/dev/`.
**Expected:** no output = success ✅.

> If your role already has `AdministratorAccess` or `SecretsManagerReadWrite`, it can read secrets already. A narrow policy like this one is the **least privilege** way.

---

## Step 4: Read the secret from the Ansible server

```bash
aws secretsmanager get-secret-value --secret-id roboshop/dev/mysql_root_password --query SecretString --output text --region us-east-1
```

**What it does:** reads the secret with the server's IAM role.
**Expected:** your MySQL password ✅. `AccessDeniedException` means Step 3 is missing or has the wrong role name.

---

## Step 5: Fetch the secret with a lookup

```bash
ansible localhost -m debug -a "msg={{ lookup('amazon.aws.secretsmanager_secret', 'roboshop/dev/mysql_root_password', region='us-east-1') | length }}"
```

**What it does:** runs the lookup plugin on the Ansible server and prints only the **length** of the password, not the password.
**Expected:** `"msg": "10"` (your password's length) ✅. The lookup works.

---

## Step 6: Point mysql_root_password to Secrets Manager

```bash
vim group_vars/all/main.yaml
```

Change the MySQL line from the vault variable to the lookup:

```yaml
mysql_root_password: "{{ lookup('amazon.aws.secretsmanager_secret', 'roboshop/dev/mysql_root_password', region='us-east-1') }}"
```

Then remove `vault_mysql_root_password` from the vault:

```bash
ansible-vault edit group_vars/all/vault.yaml
```

**What it does:** every role that uses `mysql_root_password` (mysql, mysql-data/shipping) now gets it from AWS. The roles don't change; only where the value comes from.

> Add `no_log: true` to tasks that use `mysql_root_password`, so the value never shows in the output.

---

## Step 7: Run the mysql role

```bash
ansible-playbook main.yaml -e "component=mysql"
```

**What it does:** configures MySQL with the root password fetched from Secrets Manager.
**Expected:** `failed=0` ✅.

```bash
git diff group_vars/all/main.yaml
```

**Expected:** only the lookup line changed, and **no password** appears anywhere ✅. Commit and push.

---

## Step 8: Compare import_role and include_role with when

Let's create a practice playbook that runs a small role both ways, with a condition that's false. In my case it's the `example` role (a couple of `debug` tasks). If you don't have one, create it with `ansible-galaxy role init roles/example` and add two `debug` tasks to `roles/example/tasks/main.yml`.

> `| bool` turns the value into true/false, so `-e run_it=true` (a string from the command line) works too.

```bash
vim test-include-import.yaml
```

```yaml
- name: include vs import
  hosts: localhost
  connection: local
  vars:
    run_it: false
  tasks:
  - name: static
    import_role:
      name: example
    when: run_it | bool

  - name: dynamic
    include_role:
      name: example
    when: run_it | bool
```

```bash
ansible-playbook test-include-import.yaml
```

**Expected:**
- `import_role`: **every task** in the role shows `skipping`. The `when:` was copied to each task ✅.
- `include_role`: **one** `skipping` line for `dynamic`. The `when:` was checked once, and the role was never loaded ✅.

```bash
ansible-playbook test-include-import.yaml --list-tasks
```

**Expected:** the imported role's tasks are listed; the included role shows only as `dynamic` (it isn't loaded until run time) ✅.

---

## Step 9: See import catch an error before anything runs

```bash
vim roles/example/tasks/main.yaml
```

Add a broken task at the end (bad indentation on purpose):

```yaml
- name: broken
  debug:
   msg: "x"
    oops: here
```

```bash
ansible-playbook test-include-import.yaml -e run_it=true
```

**Expected:** with `import_role` in the file, the play **fails before any task runs** with a YAML syntax error ✅.

Now comment out the `static` (import) task, and run again:

```bash
ansible-playbook test-include-import.yaml -e run_it=true
```

**Expected:** `Gathering Facts` runs first, and the error appears only when Ansible **reaches** `dynamic` ✅. That's the static vs dynamic difference.

Remove the broken task when you're done.

---

## Step 10: Create the AWS dynamic inventory

First, give each RoboShop server a `Component` tag with its short name (laptop):

```bash
for c in mongodb redis mysql rabbitmq catalogue user cart shipping payment frontend; do id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=roboshop-$c" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text); aws ec2 create-tags --resources $id --tags Key=Component,Value=$c; done
```

**What it does:** tags `roboshop-frontend` with `Component=frontend`, and so on for all 10.
**Expected:** no output = success ✅.

> To tag new servers automatically, add `tags: Component: "{{ item }}"` to the `ec2_instance` task in `roboshop.yaml`.

On the Ansible server:

```bash
vim inventory.aws_ec2.yaml
```

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  instance-state-name: running
  tag:Name: roboshop-*
keyed_groups:
  - key: tags.Component
    prefix: ""
    separator: ""
hostnames:
  - private-ip-address
```

**What it does:** tells Ansible to ask AWS for running `roboshop-*` instances and to group them by their `Component` tag.

---

## Step 11: See the groups AWS gives us

```bash
ansible-inventory -i inventory.aws_ec2.yaml --graph
```

**What it does:** shows the groups and hosts the plugin built.
**Expected:** ✅

```
@all:
  |--@ungrouped:
  |--@aws_ec2:
  |  |--172.31.x.x
  |  |--...
  |--@frontend:
  |  |--172.31.x.x
  |--@catalogue:
  |  |--172.31.x.x
  ...
```

```bash
ansible -i inventory.aws_ec2.yaml frontend -m ping
```

**Expected:** `"ping": "pong"` from the frontend's private IP ✅.

---

## Step 12: Run a role with the dynamic inventory

```bash
ansible-playbook -i inventory.aws_ec2.yaml main.yaml -e "component=catalogue"
```

**What it does:** the same V2 playbook, but the hosts come from AWS instead of `inventory.ini`. `hosts: "{{ component }}"` finds the `catalogue` group from the tag.
**Expected:** `failed=0` ✅.

> To make it the default, set `inventory = inventory.aws_ec2.yaml` in `ansible.cfg`. Note: `group_vars/` still works, because it sits next to the inventory file.

---

## Step 13: Watch forks at work

```bash
time ansible -i inventory.aws_ec2.yaml all -m command -a "sleep 5" -f 1
```

**Expected:** about **50 s**: one server at a time × 10 servers.

```bash
time ansible -i inventory.aws_ec2.yaml all -m command -a "sleep 5" -f 10
```

**Expected:** about **5–10 s**: all 10 at once ✅. Same work, more forks, much faster.

---

## Step 14: Run a rolling update with serial

```bash
vim test-serial.yaml
```

```yaml
- name: rolling update demo
  hosts: all
  serial: 2
  tasks:
  - name: step 1 (stop app)
    command: sleep 2
  - name: step 2 (deploy + start)
    command: sleep 2
```

```bash
ansible-playbook -i inventory.aws_ec2.yaml test-serial.yaml
```

**Expected:** the output shows the **whole play** (step 1 and step 2) on **2 servers**, then the whole play again on the next 2, until all 10 are done ✅:

```
PLAY [rolling update demo] (servers 1-2) → step 1 → step 2
PLAY [rolling update demo] (servers 3-4) → step 1 → step 2
...
```

Compare: remove `serial: 2` and run again. Now step 1 runs on **all** servers before step 2 starts.

---

## Step 15: Clean up

```bash
rm test-include-import.yaml test-serial.yaml
```

Keep the secret if you'll use it again. To delete it (laptop):

```bash
aws secretsmanager delete-secret --secret-id roboshop/dev/mysql_root_password --recovery-window-in-days 7 --region us-east-1
```

**Expected:** a `DeletionDate` 7 days from now ✅. You can restore it before then with `restore-secret`.

> Stop or terminate the RoboShop servers when you finish, so they don't keep costing money.

---

# Wrap-up

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `AccessDeniedException ... secretsmanager:GetSecretValue` | The Ansible server's IAM role can't read the secret | Add the policy (Step 3) to the right role (Step 2) |
| `ResourceNotFoundException` | Wrong secret name or region | Check the name and add `region='us-east-1'` to the lookup |
| `lookup plugin (amazon.aws.secretsmanager_secret) not found` | The `amazon.aws` collection isn't installed | `ansible-galaxy collection install amazon.aws` |
| `Failed to import the required Python library (botocore or boto3)` | boto3 missing on the Ansible server | `pip3 install boto3 botocore` |
| `--graph` shows only `@ungrouped` / no hosts | File name doesn't end with `aws_ec2.yaml`, wrong region, or the filter matches nothing | Rename the file, check `regions` and `filters` |
| Groups named `_frontend` or missing | `keyed_groups` prefix/separator, or the `Component` tag is missing | Use `prefix: ""` and `separator: ""`; check the tags in the EC2 console |
| `Could not match supplied host pattern` | The group name from the inventory ≠ the `component` value | Run `ansible-inventory --graph` and compare |
| Tags or `when` "don't apply" to an included role's tasks | `include_role` doesn't pass them down | Use `import_role`, or `apply: tags:` on the include |
| `loop` error on `import_role` | Loops don't work with import | Use `include_role` |

## What I learned

**Part 1: Concepts**
- **Roles** = a standard folder structure; Ansible loads `main.yaml` from each folder.
- **Vault** encrypts secrets in Git, but sharing the vault password, slow changes and no audit trail make it hard to maintain.
- **AWS Secrets Manager** keeps secrets in AWS (KMS encryption, IAM access, CloudTrail logs); Ansible reads them at run time with the `amazon.aws.secretsmanager_secret` **lookup plugin**.
- **`import_role`** = static (checked before running; `when`/`tags` copied to every task; no loops). **`include_role`** = dynamic (loaded when reached; `when` checked once; loops and variable names work).
- **Dynamic inventory** (`*.aws_ec2.yaml`) asks AWS for running instances and groups them by tags.
- **`forks`** = how many servers run a task at once (speed). **`serial`** = how many servers run the whole play per batch (rolling update, no full downtime).

**Part 2: Lab**
- Stored the MySQL root password in Secrets Manager, allowed only `roboshop/dev/*` for the Ansible server's role, and fetched it with a lookup (printed only its length).
- Saw `import_role` skip every task vs `include_role` skip once, and import catch a YAML error before anything ran.
- Built `inventory.aws_ec2.yaml`, grouped servers by a `Component` tag, and ran `main.yaml` with it.
- Timed `-f 1` vs `-f 10`, and watched `serial: 2` update 2 servers at a time.

```
 Secrets:    plain text (V1) ─► Ansible Vault (V2) ─► AWS Secrets Manager (lookup at run time)
 Inventory:  inventory.ini (by hand) ─────────────► inventory.aws_ec2.yaml (asks AWS)
 Deploy:     all servers at once ─────────────────► serial batches (rolling update)
```

## Interview questions

### ⭐ Very Important

| Question | Answer |
|---|---|
| What is the difference between `include_role` and `import_role`? | `import_role` is static: loaded and checked before the play runs, and `when`/`tags` are copied to every task. `include_role` is dynamic: loaded when reached, `when` is checked once, and it supports loops and variable role names |
| What is the difference between `forks` and `serial`? | `forks` = how many hosts run each task at the same time (speed, default 5). `serial` = how many hosts run the whole play before the next batch (rolling update) |
| What is a dynamic inventory? | An inventory built at run time from a source like AWS. The `aws_ec2` plugin lists running instances, filters them by tags and groups them, so no hand-written host list |
| How do you manage secrets in Ansible? | Ansible Vault for encrypted files in Git, or better, a secrets manager (AWS Secrets Manager / SSM Parameter Store) read at run time with a lookup plugin |

### Other Questions

| Question | Answer |
|---|---|
| Why move from Vault to Secrets Manager? | No secrets in Git, no shared vault password, change a password in one place, IAM access control, CloudTrail audit, automatic rotation |
| How does the Ansible server get permission to read secrets? | An IAM role on the EC2 instance with `secretsmanager:GetSecretValue` on the secret's ARN, no access keys |
| Is the secret lookup a module or a plugin? Where does it run? | A lookup **plugin**; it runs on the Ansible server |
| Secrets Manager vs SSM Parameter Store? | Both store encrypted values. Secrets Manager adds automatic rotation and costs per secret; Parameter Store standard parameters are free |
| What must the AWS inventory file be named? | It must end with `aws_ec2.yaml` or `aws_ec2.yml` |
| What does `keyed_groups` do? | Creates groups from instance data, e.g. one group per value of a tag |
| Why does a loop fail with `import_role`? | Imports are processed before the play runs, so a loop can't repeat them; use `include_role` |
| You have 100 servers. How do you deploy without downtime? | `serial: 10` (or `"10%"`) behind a load balancer, with `max_fail_percentage` to stop if a batch fails |
| What is `serial: [1, 5, 10]`? | Growing batches: 1 server first (a canary), then 5, then 10 at a time |
| How do you see the hosts a dynamic inventory finds? | `ansible-inventory -i inventory.aws_ec2.yaml --graph` (or `--list`) |

---

**Source:** [Reusing roles: include vs import](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html) · [Including and importing roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) · [amazon.aws.secretsmanager_secret lookup](https://docs.ansible.com/ansible/latest/collections/amazon/aws/secretsmanager_secret_lookup.html) · [amazon.aws.aws_ec2 inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html) · [Controlling playbook execution: forks and serial](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html) · [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
