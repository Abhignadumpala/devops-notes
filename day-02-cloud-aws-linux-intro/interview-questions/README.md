# Day 2 - Interview Questions

[← Back to Day 2 notes](../README.md)

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
