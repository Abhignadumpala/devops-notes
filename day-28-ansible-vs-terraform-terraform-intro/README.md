# Day 28 - Ansible vs Terraform & Terraform Intro

[← All notes](../README.md)

> **In short:** Ansible can **create** infrastructure, but it has **no memory** of what it created, so it can't safely **update** or **delete** it. **Terraform** is built for infrastructure: we write **what we want** (declarative), and its **state** file remembers what it created, so it can compare and create, update or delete only what's needed. Terraform talks to AWS through a **provider**, and the code is written in **HCL** as blocks: `resource`, `data`, `variable`, `provider`, `output`, `module`. The workflow is `terraform init` → `plan` → `apply`.

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | Infra with Ansible · imperative vs declarative · Terraform state · IaC advantages · code vs configuration · Ansible vs Terraform · providers · HCL blocks · init/plan/apply · variables and data types | Why we need a separate tool for infrastructure, and how Terraform works |
| **Part 2: Lab** | Write a provider and an EC2 resource → `init` / `plan` / `apply` → run plan again → change it → add variables → `destroy` | Do it on the laptop, in your AWS account |

**Before this:** [Day 27 - Dynamic Inventory Recap](../day-27-dynamic-inventory-recap/README.md) · [Day 22 - Ansible creating EC2 + Route 53](../day-22-ansible-shell-vs-ansible-aws-ec2-route53/README.md)

## Table of Contents

**Part 1: Concepts**
1. [Creating infra with Ansible: the limits](#1-creating-infra-with-ansible-the-limits)
2. [Imperative vs declarative](#2-imperative-vs-declarative)
3. [Terraform state: the memory](#3-terraform-state-the-memory)
4. [Infrastructure as Code: 7 advantages](#4-infrastructure-as-code-7-advantages)
5. [Code vs configuration](#5-code-vs-configuration)
6. [Ansible vs Terraform](#6-ansible-vs-terraform)
7. [Providers](#7-providers)
8. [HCL: blocks](#8-hcl-blocks)
9. [The resource block: from the console to code](#9-the-resource-block-from-the-console-to-code)
10. [init, plan, apply](#10-init-plan-apply)
11. [Variables and data types](#11-variables-and-data-types)

**Part 2: Lab**
- [Lab setup](#lab-setup)
- [Step 1: Create the Terraform project](#step-1-create-the-terraform-project)
- [Step 2: Write the provider](#step-2-write-the-provider)
- [Step 3: Write the EC2 resource](#step-3-write-the-ec2-resource)
- [Step 4: terraform init](#step-4-terraform-init)
- [Step 5: terraform plan](#step-5-terraform-plan)
- [Step 6: terraform apply](#step-6-terraform-apply)
- [Step 7: Run plan again: state at work](#step-7-run-plan-again-state-at-work)
- [Step 8: Update the server from code](#step-8-update-the-server-from-code)
- [Step 9: Move values into variables](#step-9-move-values-into-variables)
- [Step 10: terraform destroy](#step-10-terraform-destroy)

**Wrap-up**
- [Troubleshooting](#troubleshooting)
- [What I learned](#what-i-learned)
- [Interview questions](#interview-questions)

---

# Part 1: Concepts

## 1. Creating infra with Ansible: the limits

In the RoboShop labs, `roboshop.yaml` created 10 EC2 servers and their Route 53 records with Ansible. So Ansible **can** create infrastructure. The problem is what comes next:

| Action | Ansible |
|---|---|
| **Create** | ✅ Yes (`amazon.aws.ec2_instance`) |
| **Update** | ❌ Not reliably: change `t3.micro` to `t3.small` in the playbook and it has no record of which server it made before; you write the find-and-change logic yourself |
| **Delete** | ❌ Not by itself: remove a server from the playbook and Ansible doesn't notice; we had to write a separate `action: delete` part |

**Why:** Ansible has **no state**. Every run starts from zero. It doesn't remember what it created last time, so it can't work out what to change or remove.

> Ansible is great for **configuring** servers (install, copy, start). For **creating and managing** the servers themselves, we use a tool that remembers: Terraform.

---

## 2. Imperative vs declarative

**Definition:** **imperative** = you write the **steps** (how to do it). **Declarative** = you write the **end result** (what you want), and the tool works out the steps.

| | Imperative | Declarative |
|---|---|---|
| You write | "Create 1 server. If it exists, skip. If the type is different, stop it, change it, start it…" | "I want 1 server, `t3.micro`, named roboshop-mongodb" |
| Who works out the steps | You | The tool |
| Example | Shell script, AWS CLI, Ansible creating EC2 | **Terraform** |

> **Declarative in one line:** whatever we write, that's what we get. Write 3 servers → Terraform makes sure there are 3. Change it to 2 → it deletes one.

---

## 3. Terraform state: the memory

**Definition:** the **state** (`terraform.tfstate`) is a file where Terraform records **every resource it created** and its current details (ID, IP, type…). It's Terraform's **memory**.

On every run, Terraform compares three things and acts on the difference:

```
   your code              state file               real AWS
 (what you want)   (what Terraform created)     (what exists now)
        │                    │                        │
        └─────────── compare ┴────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
     in code,       in both, but     in state,
     not created    different        removed from code
        CREATE         UPDATE            DELETE
```

| Code says | State says | Terraform does |
|---|---|---|
| 1 server `t3.micro` | nothing | **Create** it |
| 1 server `t3.micro` | 1 server `t3.micro` | **Nothing** ("No changes") |
| 1 server `t3.small` | 1 server `t3.micro` | **Update** it |
| nothing | 1 server | **Delete** it |

> ⚠️ The state file can contain secrets (passwords, keys). **Never push it to GitHub.** In real projects it's kept in a **remote backend** (S3), covered in a later day.

> **Interview one-liner:** Terraform state is its memory of what it created; on each run it compares the code with the state and real infrastructure, and creates, updates or deletes only the difference.

---

## 4. Infrastructure as Code: 7 advantages

**Definition:** **Infrastructure as Code (IaC)** means creating servers, networks, DNS records and so on from **code files** instead of clicking in the console. Terraform is the most used IaC tool.

| # | Advantage | What it means |
|---|---|---|
| 1 | **Version control** | Infra is code in Git: history, review, roll back to an older version |
| 2 | **Declarative** | Write the end result; Terraform works out the steps (given the right syntax) |
| 3 | **Consistent infra** | The same code builds DEV, QA and PROD. No more "works in DEV, not in PROD" because DEV was set up by hand and missed a setting |
| 4 | **Reusable (modules)** | Write it once as a **module**, reuse it across environments and projects |
| 5 | **Dependency management** | Terraform sees that the server needs the security group and creates the SG **first** |
| 6 | **CRUD** | **C**reate, **R**ead, **U**pdate and **D**elete infra, all from the same code |
| 7 | **Inventory** | Read the code and state to see exactly what resources the project uses |

> **Point 3 in practice:** lower environments are often set up with less care than PROD. With IaC, every environment comes from the **same code**, so they match.

---

## 5. Code vs configuration

**Definition:** the **code** is the same for every environment; the **configuration** is the values that **change** per environment.

| | Code (same everywhere) | Configuration (changes per env) |
|---|---|---|
| Example | "create an EC2 server with this type and these tags" | DEV: `t3.micro`, 1 server · PROD: `t3.large`, 3 servers |
| In Terraform | `.tf` files with resources | **variables** (`.tfvars` files) |

```
          one code ──┬── dev.tfvars   → small servers
                     ├── qa.tfvars    → medium servers
                     └── prod.tfvars  → big servers
```

---

## 6. Ansible vs Terraform

| | **Ansible** | **Terraform** |
|---|---|---|
| **Main job** | **Configuration management**: set up what runs **inside** servers | **Infrastructure provisioning**: create the servers, networks, DNS, IAM |
| **Style** | Mostly imperative (tasks run in order) | **Declarative** (describe the end result) |
| **State** | ❌ None: every run starts fresh | ✅ `terraform.tfstate` remembers what it created |
| **Update / delete infra** | You write it yourself | Built in: change or remove the code, run `apply` |
| **Language** | YAML | HCL (HashiCorp Configuration Language) |
| **Talks to platforms through** | Modules and collections (`amazon.aws.ec2_instance`) | **Providers** (`hashicorp/aws`) |
| **Agent on servers** | No (SSH) | No (calls the cloud API) |
| **Run it** | `ansible-playbook` | `terraform init` → `plan` → `apply` |
| **Dry run** | `--check` | `terraform plan` |
| **RoboShop example** | Install MongoDB, copy `mongo.repo`, start the service | Create the MongoDB EC2 server and its DNS record |

**Used together:** Terraform builds the infrastructure; Ansible configures the servers on it.

```
 Terraform: create EC2 + SG + Route 53 ──► Ansible: install + configure the app ──► app running
```

> **Interview one-liner:** Terraform provisions infrastructure declaratively and keeps state, so it can create, update and delete; Ansible configures the servers and has no state. In real projects Terraform builds the servers, then Ansible sets them up.

---

## 7. Providers

**Definition:** a **provider** is a **plugin that lets Terraform talk to a platform's API**: AWS, Azure, GCP, GitHub, Kubernetes and many more. Terraform itself knows nothing about AWS; the AWS provider does.

| Ansible | Terraform |
|---|---|
| Module / collection / task (`amazon.aws`) | **Provider** (`hashicorp/aws`) |

```
 your .tf code ──► Terraform ──► AWS provider (plugin) ──► AWS API ──► EC2 server
```

**We write the provider before any other code**, so Terraform knows which plugin to download and which region to use:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

| Part | Meaning |
|---|---|
| `required_providers` | Which plugin to download, from where, which version |
| `source = "hashicorp/aws"` | From the Terraform Registry |
| `version = "~> 6.0"` | Any 6.x version |
| `provider "aws"` | Settings for that plugin: here the region. Login comes from `aws configure`, **never** keys in code |

---

## 8. HCL: blocks

**Definition:** **HCL (HashiCorp Configuration Language)** is the language of Terraform files (`.tf`). Everything is a **block** in curly braces, with `key = "value"` lines inside.

```hcl
<block-type> "<label>" "<name>" {
  key = "value"
}
```

| Block | What it does | Example |
|---|---|---|
| `provider` | Which platform to talk to, and its settings | `provider "aws" { region = "us-east-1" }` |
| `resource` | **Create** and manage something | `resource "aws_instance" "mongodb" { … }` |
| `data` | **Read** something that already exists (don't create it) | Look up the `roboshop-common` SG ID |
| `variable` | An input value, so the code can be reused | `variable "instance_type" { default = "t3.micro" }` |
| `output` | Print a value after apply | The server's private IP |
| `module` | Use a reusable group of resources | A ready-made "EC2 + SG" module |

> **Ansible vs HCL:** YAML uses **indentation**; HCL uses **braces** and `=`. Indentation in HCL is only for reading.

---

## 9. The resource block: from the console to code

To create a server in the **EC2 console**, we pick: **name, AMI, instance type, key pair, security group → Launch**. The same choices can be made with the **AWS CLI**, an **Ansible module**, or a **Terraform resource**.

The idea, in plain words:

```
resource "aws_instance" "roboshop-mongodb" {
    name          = "roboshop-mongodb"
    ami           = "ami-1234"
    instance-type = "t3.micro"
    key           = "<key-pair>"
    sg-name       = "roboshop-mongodb"
}
```

The real AWS provider uses slightly different **argument names**. Look them up in the [Terraform Registry → aws_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance):

```hcl
resource "aws_instance" "roboshop_mongodb" {
  ami                    = "ami-0055977a6e828a4f4"
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["<sg-id>"]

  tags = {
    Name = "roboshop-mongodb"
  }
}
```

| Console choice | Plain idea | Real argument |
|---|---|---|
| Name | `name` | `tags = { Name = "…" }` (the console "name" is just the `Name` tag) |
| AMI | `ami` | `ami` |
| Instance type | `instance-type` | `instance_type` (underscore) |
| Key pair | `key` | `key_name` (not needed: RoboShop logs in with a password) |
| Security group | `sg-name` | `vpc_security_group_ids` (a **list** of SG **IDs**) |

| Part | Meaning |
|---|---|
| `resource` | Block type: create something |
| `"aws_instance"` | Resource **type**, from the AWS provider (`aws_` prefix = AWS provider) |
| `"roboshop_mongodb"` | Our **name** for it inside Terraform (not the AWS name). Refer to it as `aws_instance.roboshop_mongodb` |

---

## 10. init, plan, apply

| Command | What it does |
|---|---|
| `terraform init` | Reads the provider block and **downloads** the provider plugin into `.terraform/`. Run it once per project (and after adding a provider or module) |
| `terraform plan` | Checks the syntax, compares code with state and AWS, and **shows** what it will do (`+` create, `~` update, `-` delete). Changes nothing |
| `terraform apply` | Shows the plan again, asks `yes`, then **creates/updates/deletes** and saves the result in `terraform.tfstate` |
| `terraform destroy` | Deletes everything this project created |

```
 write .tf ──► init ──► plan ──► apply ──► terraform.tfstate updated
  (code)     (download   (preview)  (make it   (memory)
              provider)              real)
```

> **Interview one-liner:** `init` downloads the providers, `plan` previews the changes by comparing code with state, `apply` makes them and updates the state, and `destroy` removes everything the project created.

---

## 11. Variables and data types

**Definition:** a **variable** is a named input, so the same code works with different values. It's like `vars:` in Ansible.

| Ansible (YAML) | Terraform (HCL) |
|---|---|
| `vars:`<br>`  course: terraform` | `variable "course" {`<br>`  default = "terraform"`<br>`}` |
| `"{{ course }}"` | `var.course` |

| Type | Example | Note |
|---|---|---|
| `number` | `123` | No quotes |
| `string` | `"123"` | In quotes, even if it looks like a number |
| `bool` | `true` / `false` | No quotes |
| `list` | `["apple", "banana"]` | Ordered, in square brackets; `var.fruits[0]` = `"apple"` |
| `map` | `{ course = "terraform", duration = "10hrs" }` | Key = value pairs, in braces; `var.course_info["course"]` |

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "roboshop"
    Environment = "dev"
    Terraform   = "true"
  }
}
```

---

# Part 2: Lab

## Lab setup

| What | Details |
|---|---|
| **Machine** | Laptop with **Terraform** and the **AWS CLI** set up ([setup guide](https://github.com/Abhignadumpala/terraform-aws-labs/blob/main/00-setup/README.md)) |
| **Region** | `us-east-1` |
| **Cost** | One `t3.micro` server for a few minutes; deleted in Step 10 |

```bash
terraform version
```

```bash
aws sts get-caller-identity
```

**Expected:** `Terraform v1.x` and your account ID ✅.

---

## Step 1: Create the Terraform project

On the **laptop**:

```bash
mkdir -p ~/terraform-intro && cd ~/terraform-intro
```

```bash
printf '.terraform/\n*.tfstate\n*.tfstate.*\n' > .gitignore
```

**Why the `.gitignore`:** the `.terraform/` folder is the downloaded provider (large), and the state files can hold secrets. Neither goes to Git.

---

## Step 2: Write the provider

```bash
vim provider.tf
```

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

---

## Step 3: Write the EC2 resource

Find the ID of the RoboShop security group:

```bash
aws ec2 describe-security-groups --group-names roboshop-common --query "SecurityGroups[0].GroupId" --output text
```

**Expected:** `sg-0abc…` ✅. Copy it.

```bash
vim ec2.tf
```

```hcl
resource "aws_instance" "roboshop_mongodb" {
  ami                    = "ami-0055977a6e828a4f4"
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["<sg-id>"]

  tags = {
    Name = "tf-roboshop-mongodb"
  }
}

output "private_ip" {
  value = aws_instance.roboshop_mongodb.private_ip
}
```

> The name is `tf-roboshop-mongodb`, not `roboshop-mongodb`, so it doesn't clash with the RoboShop server Ansible already manages.

---

## Step 4: terraform init

```bash
terraform init
```

**What it does:** reads `provider.tf` and downloads the AWS provider.
**Expected:** `Terraform has been successfully initialized!` ✅.

```bash
ls -a
```

**Expected:** `.terraform/` (the provider plugin) and `.terraform.lock.hcl` (the exact provider version, so everyone gets the same one; this file **is** committed) ✅.

---

## Step 5: terraform plan

```bash
terraform plan
```

**What it does:** checks the syntax and shows what would happen. Nothing is created.
**Expected:** `+ resource "aws_instance" "roboshop_mongodb"` and `Plan: 1 to add, 0 to change, 0 to destroy.` ✅.

> A typo like `instance-type` fails here with `An argument named "instance-type" is not expected here`. That's the plan catching syntax errors before anything is created.

---

## Step 6: terraform apply

```bash
terraform apply
```

Type `yes` when asked.

**What it does:** creates the server and writes `terraform.tfstate`.
**Expected:** `Apply complete! Resources: 1 added` and `private_ip = "172.31.…"` ✅. The server shows in the EC2 console as `tf-roboshop-mongodb`.

```bash
terraform state list
```

**Expected:** `aws_instance.roboshop_mongodb` ✅. This is the memory.

---

## Step 7: Run plan again: state at work

```bash
terraform plan
```

**Expected:** `No changes. Your infrastructure matches the configuration.` ✅.

**Why this matters:** run an Ansible `ec2_instance` create task again and it has to search for the server by name. Terraform simply checks its state: the server is already there and matches the code, so there's nothing to do.

---

## Step 8: Update the server from code

Add a tag in `ec2.tf`:

```hcl
  tags = {
    Name    = "tf-roboshop-mongodb"
    Project = "roboshop"
  }
```

```bash
terraform plan
```

**Expected:** `~ update in-place` and `Plan: 0 to add, 1 to change, 0 to destroy.` ✅.

```bash
terraform apply
```

**Expected:** `1 changed`, and the `Project` tag is visible in the console ✅. That's the **update** Ansible couldn't do on its own.

> Some changes can't be done in place. Change the `ami` and the plan shows `-/+ destroy and then create replacement`. Always read the plan before typing `yes`.

---

## Step 9: Move values into variables

```bash
vim variables.tf
```

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "roboshop"
    Environment = "dev"
  }
}
```

In `ec2.tf`, use them:

```hcl
  instance_type = var.instance_type

  tags = merge(var.common_tags, {
    Name = "tf-roboshop-mongodb"
  })
```

| Part | Meaning |
|---|---|
| `var.instance_type` | Read the variable (like `{{ instance_type }}` in Ansible) |
| `merge(a, b)` | Join two maps into one: the common tags + this server's Name |

```bash
terraform plan
```

**Expected:** only the new `Environment = "dev"` tag shows as a change ✅. The code changed, but the result is almost the same.

```bash
terraform plan -var="instance_type=t3.small"
```

**Expected:** the plan shows `instance_type: "t3.micro" -> "t3.small"` ✅. Same code, different configuration ([section 5](#5-code-vs-configuration)). Don't apply this one.

---

## Step 10: terraform destroy

```bash
terraform destroy
```

Type `yes`.

**What it does:** deletes everything in the state: here, the one server.
**Expected:** `Destroy complete! Resources: 1 destroyed.` ✅.

```bash
terraform state list
```

**Expected:** empty ✅. Terraform knew exactly what it had created, so it deleted only that, not the RoboShop servers Ansible made.

---

# Wrap-up

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Inconsistent dependency lock file` / `provider not installed` | `init` not run, or provider changed | `terraform init` (or `terraform init -upgrade`) |
| `An argument named "instance-type" is not expected` | Wrong argument name | Use the names from the Registry docs: `instance_type` |
| `No valid credential sources found` | AWS CLI not configured on this machine | `aws configure` ([setup](https://github.com/Abhignadumpala/terraform-aws-labs/blob/main/00-setup/README.md)) |
| `InvalidAMIID.NotFound` | AMI is from another region | Use an AMI from `us-east-1`, or change the region |
| `InvalidGroup.NotFound` | SG ID wrong or from another VPC/region | Step 4 command again; copy the `sg-…` ID |
| Server still exists after deleting the folder | State was deleted with it, so Terraform forgot it | Always `terraform destroy` **before** deleting the project |

---

## What I learned

| Topic | One line |
|---|---|
| Ansible for infra | Can create, but has no state, so update/delete must be hand-written |
| Declarative | Write the end result; the tool works out the steps |
| State | Terraform's memory; it compares code + state + AWS and acts on the difference |
| IaC advantages | Version control, declarative, consistent envs, modules, dependencies, CRUD, inventory |
| Code vs config | Same code for all environments; values change per environment |
| Provider | Plugin that talks to a platform's API; written first |
| HCL blocks | `provider`, `resource`, `data`, `variable`, `output`, `module` |
| Workflow | `init` → `plan` → `apply` → `destroy` |
| Data types | number, string, bool, list, map |

---

## Interview questions

### ⭐ Very Important

1. **Ansible can create EC2 servers. Why use Terraform?**
   Ansible has no state, so it can create but can't reliably update or delete what it created. Terraform keeps state, so it compares code with what exists and creates, updates or deletes only the difference.

2. **What is Terraform state?**
   The `terraform.tfstate` file: Terraform's memory of every resource it created. It's compared with the code on every plan. It can hold secrets, so it never goes to Git; in teams it's stored in a remote backend like S3.

3. **What does declarative mean?**
   You describe the end result (1 server, t3.micro), not the steps. The tool works out what to create, change or delete.

4. **What are the advantages of Infrastructure as Code?**
   Version control, declarative, consistent infra across DEV and PROD, reusable modules, dependency management, full CRUD, and a clear inventory of what's in use.

5. **What is a provider?**
   A plugin that lets Terraform talk to a platform's API (AWS, Azure, GitHub…). It's declared in `required_providers` and downloaded by `terraform init`.

6. **Explain `init`, `plan` and `apply`.**
   `init` downloads the providers; `plan` checks syntax and previews the changes; `apply` makes the changes and updates the state.

7. **Ansible vs Terraform?**
   Terraform provisions infrastructure (declarative, stateful, HCL, providers). Ansible configures servers (task-based, stateless, YAML, modules). Used together: Terraform builds, Ansible configures.

### Other Questions

8. **What's the difference between `resource` and `data` blocks?**
    `resource` creates and manages something; `data` only reads something that already exists, like an existing security group's ID.

9. **What are Terraform's basic data types?**
    `number`, `string`, `bool`, `list` and `map` (plus `set`, `object`, `tuple`).

10. **What's the difference between code and configuration?**
    Code is the same for every environment; configuration is the values that change per environment, passed as variables or `.tfvars` files.

11. **Should `.terraform.lock.hcl` be committed?**
    Yes: it pins the exact provider versions so everyone gets the same. `.terraform/` and `*.tfstate` are not committed.

12. **What happens if you change an EC2 instance's AMI in Terraform?**
    It can't be changed in place, so the plan shows `-/+` (destroy and create a replacement). That's why you always read the plan.
