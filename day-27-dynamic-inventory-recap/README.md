# Day 27 - Dynamic Inventory Recap

[← All notes](../README.md)

> **In short:** a **dynamic inventory** asks AWS for the servers **every time Ansible runs**, instead of reading a hand-written `inventory.ini`. It works like filtering in the EC2 console: **select the region → keep running servers → keep frontend servers → get their IP addresses**. Because the filter uses the **Name tag**, renaming a server in the console is enough to add it to or remove it from the inventory, with no file edit.

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | Static vs dynamic inventory · the 4 filter steps · how the Name tag drives the inventory | How Ansible finds servers that come and go |
| **Part 2: Lab** | List the frontend servers → rename one in the console → watch it leave the inventory → rename it back → run a playbook on the group | Do it on the real Ansible server with the Day 26 project |

**Before this:** [Day 26 - Dynamic Inventory & Parallelism](../day-26-secrets-manager-include-import-dynamic-inventory-parallelism/README.md#5-dynamic-inventory) · **Next:** [Day 28 - Ansible vs Terraform & Terraform Intro](../day-28-ansible-vs-terraform-terraform-intro/README.md)

## Table of Contents

**Part 1: Concepts**
1. [Static vs dynamic inventory](#1-static-vs-dynamic-inventory)
2. [The 4 steps: region → running → frontend → IP](#2-the-4-steps-region--running--frontend--ip)
3. [The Name tag drives the inventory](#3-the-name-tag-drives-the-inventory)

**Part 2: Lab**
- [Lab setup](#lab-setup)
- [Step 1: List the frontend servers](#step-1-list-the-frontend-servers)
- [Step 2: Rename the server in the console](#step-2-rename-the-server-in-the-console)
- [Step 3: List again: the server is gone](#step-3-list-again-the-server-is-gone)
- [Step 4: Rename it back](#step-4-rename-it-back)
- [Step 5: Run a playbook on the group](#step-5-run-a-playbook-on-the-group)

**Wrap-up**
- [Troubleshooting](#troubleshooting)
- [What I learned](#what-i-learned)
- [Interview questions](#interview-questions)

---

# Part 1: Concepts

## 1. Static vs dynamic inventory

**Definition:** a **dynamic inventory** is an inventory that Ansible **builds at run time** by asking a cloud API (here AWS EC2) which servers exist, instead of reading a fixed list of hosts from a file.

| | Static (`inventory.ini`) | Dynamic (`*.aws_ec2.yaml`) |
|---|---|---|
| Server list | Typed by hand | Read from AWS on every run |
| New server (Auto Scaling) | Missing until you add it | Picked up on the next run |
| Server deleted | Still listed, Ansible fails to connect | Gone on the next run |
| IP changed after a restart | Wrong IP until you fix it | Current IP every time |
| Good for | Small, fixed setups (our RoboShop labs) | Real production, where servers come and go |

---

## 2. The 4 steps: region → running → frontend → IP

The plugin file does the same filtering you would do by hand in the EC2 console:

```
 ① select the region           regions: [us-east-1]
          │
 ② keep running servers        filters: instance-state-name: running
          │
 ③ keep frontend servers       filters: tag:Name: roboshop-frontend
          │
 ④ get the IP addresses        hostnames: [private-ip-address]
          │
          ▼
 Ansible connects to these IPs
```

```yaml
plugin: amazon.aws.aws_ec2
regions:
- us-east-1

filters:
  instance-state-name: running
  tag:Name: roboshop-frontend

hostnames:
- private-ip-address

keyed_groups:
- key: tags.Name
```

| Line | Console equivalent |
|---|---|
| `regions` | The region picker at the top right |
| `instance-state-name: running` | Filter **Instance state = running** |
| `tag:Name: roboshop-frontend` | Filter **Name = roboshop-frontend** |
| `hostnames: private-ip-address` | The **Private IPv4 address** column |
| `keyed_groups: tags.Name` | Puts them in the group `roboshop_frontend` (`-` becomes `_`) |

Full explanation of every setting: [Day 26, section 5](../day-26-secrets-manager-include-import-dynamic-inventory-parallelism/README.md#5-dynamic-inventory).

---

## 3. The Name tag drives the inventory

The filter matches the **Name tag**, and the Name is what you change with the pencil icon in the EC2 console. So **renaming a server in the console** adds it to or removes it from the inventory, with no file edit:

| Name tag in the console | In the inventory? |
|---|---|
| `roboshop-frontend` | ✅ yes (matches the filter) |
| `roboshop-frontend-old` | ❌ no (doesn't match any more) |
| `roboshop-catalogue` → renamed `roboshop-frontend` | ✅ yes, now treated as a frontend |

> ⚠️ This works both ways. A wrong tag can make Ansible configure the **wrong** server, or skip one. In real projects, tags are set by code (Terraform, Auto Scaling launch templates), not by hand.

> **Interview one-liner:** the AWS dynamic inventory reads EC2 at run time (region → running → tag filter → IPs), so a server that's added, removed, restarted or renamed is picked up on the next run without editing any file.

---

# Part 2: Lab

## Lab setup

| What | Details |
|---|---|
| **Ansible server** | RHEL 9 server from the RoboShop labs, with the EC2 IAM role, `boto3` and the `amazon.aws` collection |
| **Project** | `~/ansible-dynamic-inventory` from [Day 26, Steps 14–17](../day-26-secrets-manager-include-import-dynamic-inventory-parallelism/README.md#step-14-create-the-dynamic-inventory-project) (`frontend.aws_ec2.yaml` + `main.yaml`) |
| **Servers** | At least one running server named `roboshop-frontend` (the RoboShop frontend is enough) |

```bash
ssh ec2-user@<ansible-server-public-ip>
```

Password: `DevOps321`

```bash
cd ~/ansible-dynamic-inventory
```

---

## Step 1: List the frontend servers

```bash
ansible-inventory -i frontend.aws_ec2.yaml --graph
```

**What it does:** runs the plugin and prints the groups and hosts it found.
**Expected:** the frontend's private IP under `@roboshop_frontend` (and `@aws_ec2`) ✅.

---

## Step 2: Rename the server in the console

**EC2 console → Instances →** select `roboshop-frontend` **→** hover the **Name** → pencil icon **→** type `roboshop-frontend-old` **→ Save**.

---

## Step 3: List again: the server is gone

```bash
ansible-inventory -i frontend.aws_ec2.yaml --graph
```

**Expected:** the IP is **gone**; the group may be missing entirely ✅. Nothing was edited on the Ansible server: the Name tag no longer matches `tag:Name: roboshop-frontend`.

---

## Step 4: Rename it back

In the console, rename it back to `roboshop-frontend`.

```bash
ansible-inventory -i frontend.aws_ec2.yaml --graph
```

**Expected:** the IP is back under `@roboshop_frontend` ✅.

---

## Step 5: Run a playbook on the group

```bash
ansible-playbook -i frontend.aws_ec2.yaml main.yaml
```

**What it does:** runs the Day 26 `main.yaml` (`hosts: roboshop_frontend`) on whatever the plugin found right now.
**Expected:** `ok` on the frontend IP, `failed=0` ✅.

> If the website stopped working after Steps 2–4: it didn't. Renaming a tag doesn't touch the server, its IPs or its DNS records.

---

# Wrap-up

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `--graph` shows only `@ungrouped` / nothing | No running server matches the filter | Check the Name tag and that the server is **running** |
| Renamed server still shows | Typo in the new name still matches, or ran before saving | Check the Name in the console, run `--graph` again |
| `Failed to parse … with auto plugin` | File name doesn't end in `.aws_ec2.yaml` | Rename the file |
| `botocore` / `boto3` required | Python libraries missing | `pip3 install boto3 botocore` |
| `UnauthorizedOperation` | IAM role can't describe EC2 | Role needs `ec2:DescribeInstances` |
| `Could not match supplied host pattern` | Group name in `hosts:` differs | Copy the exact name from `--graph` |

---

## What I learned

| Topic | One line |
|---|---|
| Dynamic inventory | Built at run time from AWS, not from a file |
| 4 steps | Region → running → tag filter → IPs, same as console filters |
| Name tag | Renaming a server in the console adds it to or removes it from the inventory |
| Why | Auto Scaling and restarts change servers and IPs; a static file can't keep up |

---

## Interview questions

### ⭐ Very Important

1. **What is a dynamic inventory and why do you need it?**
   An inventory built at run time from the cloud API. With Auto Scaling, servers and IPs change all the time, so a static `inventory.ini` is always out of date.

2. **How does the AWS dynamic inventory pick the servers?**
   Region → filter running instances → filter by tag (e.g. `Name = roboshop-frontend`) → use their private IPs as hostnames.

### Other Questions

3. **What happens if you rename a server's Name tag in the console?**
   On the next run it no longer matches the tag filter, so it drops out of the inventory (or joins another one). No file changes needed.

4. **How do you check what the dynamic inventory found?**
   `ansible-inventory -i <file>.aws_ec2.yaml --graph` (or `--list` for all variables).
