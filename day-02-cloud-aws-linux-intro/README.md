# Day 2 - Cloud, AWS & Linux Introduction

## Table of Contents

1. [Why Is Everyone Moving to Cloud?](#why-is-everyone-moving-to-cloud)
2. [Regions and Availability Zones](#regions-and-availability-zones)
3. [Creating an AWS Account](#creating-an-aws-account)
4. [What Is a Computer?](#what-is-a-computer)
5. [What Is an OS?](#what-is-an-os)
6. [Linux History](#linux-history)
7. [Linux Distributions](#linux-distributions)
8. [Firewall / Security Group](#firewall--security-group)
9. [Client-Server Architecture](#client-server-architecture)
10. [Authentication](#authentication)
11. [SSH - Connecting to a Linux Server](#ssh---connecting-to-a-linux-server)
12. [Summary](#summary)
13. [Interview Questions](#interview-questions)

---

## Why Is Everyone Moving to Cloud?

We need servers to host applications.

### On-Premise (Own Data Center)

To host an app yourself you must:

1. Buy servers
2. Rent space (like a warehouse)
3. Set up AC (cooling)
4. Power connection
5. Network connection
6. Install OS
7. Physical security and surveillance

Problems:
- **More cost** - pay upfront even if unused
- **More time** - weeks/months to set up
- **Maintenance** - hardware failures are your problem
- **High availability not guaranteed**

### Cloud

- Create servers **immediately** and start hosting
- **Pay only for what you use**
- Provider handles hardware, power, cooling, physical security

| | On-Premise | Cloud |
|---|------------|-------|
| Setup time | Weeks/months | Minutes |
| Cost | Large upfront | Pay as you go |
| Maintenance | You | Cloud provider |
| Scaling | Buy more hardware | Click / automate |
| High availability | Hard | Built-in (multiple AZs) |

---

## Regions and Availability Zones

- **Region** = a geographic area (e.g. Mumbai, Hyderabad, N. Virginia)
- **Availability Zone (AZ)** = a data center (or group of data centers) inside a region
- Every region has **at least 2 AZs** (most have 3 or more)

```text
Hyderabad Region (ap-south-2)
├── AZ-1 (e.g. North Hyderabad)
├── AZ-2 (e.g. South Hyderabad)
└── AZ-3 (e.g. East Hyderabad)
```

If one AZ goes down, the app keeps running in the others → **high availability**.

### Common Regions

| Region Code | Location |
|-------------|----------|
| `us-east-1` | N. Virginia |
| `ap-south-1` | Mumbai |
| `ap-south-2` | Hyderabad |

### Latency

**Latency = how late you get a response.**

- User in Hyderabad → server in Hyderabad → **less latency**
- User in Hyderabad → server in US → **more latency**

Choose a region close to your users.

---

## Creating an AWS Account

Tips:
- Prefer **UPI**-enabled card or a private debit/credit card
- Enable **international transactions** on the card
- Give your **bank address** to AWS
- Use the **same name as in the bank**
- Prefer a **new email and phone number**
- **PAN card** is mandatory

Free credits: new accounts get sign-up credits plus more for completing activities (about $200 total). Use them slowly and **stop/terminate servers when not in use**.

---

## What Is a Computer?

**A device with CPU, RAM, Storage and an OS is a computer.** We can assign it an IP address.

| Device | Use |
|--------|-----|
| Laptop | Personal use |
| Server | Host applications |
| Mobile | Calling, apps |
| TV | Entertainment |

### Human Analogy

| Computer | Human |
|----------|-------|
| CPU | Brain |
| RAM | Muscle memory |
| Storage | Memory (brain storage ≈ 2.5 PB ≈ 2500 TB) |
| OS | How we think/behave |

---

## What Is an OS?

- **Hardware**: CPU, RAM, Storage
- **Software**: OS - manages the hardware and runs applications

### OS Architecture

```text
┌──────────────────────┐
│     Applications     │  ← browsers, apps
├──────────────────────┤
│        Shell         │  ← takes your commands
├──────────────────────┤
│        Kernel        │  ← talks to hardware
├──────────────────────┤
│  Hardware (CPU, RAM, │
│      Storage)        │
└──────────────────────┘
```

**OS = Kernel + Shell + Applications**

### Hardware + Software Coupling

| Example | Model |
|---------|-------|
| Mac laptop | Pay for hardware + software together (tightly coupled) |
| Dell laptop | Pay for hardware, install any OS you want |

---

## Linux History

- **Unix** - came as hardware + software together, very costly.
- **1991** - **Linus Torvalds** wrote the **Linux kernel** from scratch in **C**, inspired by Unix. Free and open source.
- To manage the Linux kernel source code, he later also created **Git** (2005).

Linux runs most servers, cloud, Android phones and all top supercomputers - that's why DevOps engineers must know Linux.

---

## Linux Distributions

**Distribution (distro / flavour) = Linux kernel + shell + applications packaged by a company or community.**

| Distro | Type |
|--------|------|
| Red Hat Enterprise Linux (RHEL) | Enterprise (paid support) |
| Ubuntu | Community (paid support available) |
| SUSE | Enterprise |
| Amazon Linux | AWS |
| CentOS, AlmaLinux | Community |

**RHEL family:** RHEL ≈ CentOS ≈ AlmaLinux ≈ Amazon Linux - same commands (`yum`/`dnf`).

| Enterprise | Community |
|------------|-----------|
| Immediate support (paid) | No official support |

Size: a full server OS is ~2.5 GB, while **Embedded Linux** (for devices) can be ~10 MB.

---

## Firewall / Security Group

In AWS, a firewall is called a **Security Group (SG)**.

| Direction | Also Called | Meaning | Usually |
|-----------|-------------|---------|---------|
| **Inbound** | Ingress | Incoming traffic to server | Allow only what's needed |
| **Outbound** | Egress | Outgoing traffic from server | Allow all |

### CIDR Examples

| CIDR | Meaning |
|------|---------|
| `0.0.0.0/0` | Any device on the internet |
| `122.183.36.3/32` | Only one IP (e.g. my laptop) |

---

## Client-Server Architecture

- **Client** - sends a request (your laptop, browser, Git Bash)
- **Server** - receives the request and responds (EC2 Linux server, website)

```text
Client (laptop)  ── request ──▶  Server (EC2)
                 ◀── response ──
```

A Linux server is also called a **box** or **node**.

---

## Authentication

Three ways to prove who you are:

| Factor | Type | Example |
|--------|------|---------|
| What you **know** | Knowledge | Username + password |
| What you **have** | Possession | OTP, SSH keys |
| What you **are** | Biometric | Fingerprint, retina, palm |

Linux servers on cloud use **SSH keys** (what you have).

---

## SSH - Connecting to a Linux Server

**SSH (Secure Shell)** gives you terminal access to a remote server over an encrypted connection.

| Protocol | Use |
|----------|-----|
| HTTPS | Secure websites (e.g. `https://www.facebook.com`) |
| SSH | Secure terminal access to servers (port 22) |

### Git Bash (Windows)

Git Bash = Git client + SSH client + mini Linux terminal.

```bash
pwd       # present working directory
# /c/Users/<your-name>
```

### Create an SSH Key Pair

```bash
ssh-keygen -f devops-key
```

Creates two files:

| File | Keep Where |
|------|------------|
| `devops-key` | Private key - stays on your laptop, never share |
| `devops-key.pub` | Public key - goes to the server (import in AWS) |

Connecting to the server: see [Day 3](../day-03-linux-basics/README.md#connecting-to-ec2).

---

## Summary

- **Cloud** = servers in minutes, pay as you go, no hardware maintenance.
- **Region** = location; **AZ** = data center; region has ≥ 2 AZs.
- **Computer** = CPU + RAM + Storage + OS.
- **OS** = Kernel + Shell + Applications.
- **Linux** = free Unix-like OS by Linus Torvalds (1991); he also created Git.
- **Security Group** = firewall; inbound (ingress) / outbound (egress).
- **SSH** = secure terminal access using key pairs.

---

## Interview Questions

**1. Why are companies moving to cloud?**

On-premise needs buying servers, space, cooling, power, network and security - high upfront cost and weeks of setup. Cloud gives servers in minutes, pay-as-you-go pricing, no hardware maintenance, easy scaling and built-in high availability.

**2. What is a Region and an Availability Zone?**

Region = a geographic location (e.g. Mumbai `ap-south-1`). AZ = one or more isolated data centers inside a region. Every region has at least 2 AZs, so an app spread across AZs survives one AZ failing.

**3. What is latency? How do you reduce it?**

The delay before you get a response. Reduce it by hosting in a region close to users (and using a CDN).

**4. What is an Operating System? Its parts?**

Software that manages hardware (CPU, RAM, storage) and runs applications. OS = Kernel + Shell + Applications.

**5. Kernel vs Shell?**

Kernel talks directly to hardware (memory, CPU, devices). Shell takes the user's commands and passes them to the kernel (e.g. bash).

**6. Why is Linux used in DevOps?**

Free and open source, stable, secure, lightweight, and runs most servers and cloud workloads. Almost all DevOps tools (Docker, Kubernetes, Jenkins) run on Linux.

**7. Name some Linux distributions and their package managers.**

RHEL, CentOS, AlmaLinux, Amazon Linux → `dnf`/`yum`. Ubuntu, Debian → `apt`.

**8. What is a Security Group?**

A virtual firewall for an EC2 instance. Inbound (ingress) rules control incoming traffic, outbound (egress) rules control outgoing traffic. Security groups are **stateful** - if a request is allowed in, its response is allowed out automatically.

**9. What do `0.0.0.0/0` and `/32` mean?**

`0.0.0.0/0` = any IP on the internet. `x.x.x.x/32` = exactly one IP address.

**10. What are the authentication factors?**

Something you **know** (password), something you **have** (OTP, SSH key), something you **are** (fingerprint). Using two or more = MFA.

**11. What is SSH? Which port?**

Secure Shell - encrypted remote terminal access to a server. Port **22**.

**12. How does key-based authentication work?**

`ssh-keygen` creates a key pair. The **public key** goes on the server (`~/.ssh/authorized_keys`); the **private key** stays with me and is never shared. On login, the server checks that I hold the matching private key.

**13. Client vs Server?**

Client sends the request (browser, laptop), server receives and responds (EC2, website).
