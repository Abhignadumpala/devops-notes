# Day 15 - Hands-On: Create and Terminate EC2 with AWS CLI Scripts (2026-10-19)

[← Back to Day 15](../README.md)

I launched and terminated an EC2 instance from **shell scripts** on my Ubuntu laptop using the **AWS CLI**, no console.

## Table of Contents

1. [Check AWS CLI access](#1-check-aws-cli-access)
2. [Find the AMI, subnet and security group](#2-find-the-ami-subnet-and-security-group)
3. [Create script: ec2-creation.sh](#3-create-script-ec2-creationsh)
4. [Terminate script: ec2-termination.sh](#4-terminate-script-ec2-terminationsh)
5. [Problems I faced and how I fixed them](#5-problems-i-faced-and-how-i-fixed-them)
6. [Summary](#6-summary)

---

## 1. Check AWS CLI access

`aws configure` showed keys already saved (masked as `****QKFS`). Pressed **Enter** at every prompt to keep them.

```bash
$ aws configure
AWS Access Key ID [****************QKFS]:
AWS Secret Access Key [****************fGgj]:
Default region name [us-east-1]:
Default output format [json]:

$ aws sts get-caller-identity
{
    "UserId": "AIDA...",
    "Account": "0028****0983",
    "Arn": "arn:aws:iam::0028****0983:user/abhiterrauser"
}
```

| Check | Result |
|---|---|
| Keys work | ✅ `sts get-caller-identity` answered |
| Who | An **IAM user** (`abhiterrauser`), not root ✅ |
| Region / output | `us-east-1` / `json` |

> Pressing **Enter** keeps the saved value. Typing something replaces it.

## 2. Find the AMI, subnet and security group

| Item | Value | How I found it |
|---|---|---|
| AMI | `ami-0220d79f3f480ecf5` (Redhat-9-DevOps-Practice) | `aws ec2 describe-images --filters "Name=name,Values=*Redhat-9-DevOps-Practice*"` |
| Subnet | `subnet-03628f95f21fe62ce` (us-east-1a, default VPC) | `aws ec2 describe-subnets` |
| Security group | `sg-0def50d1e6c5ddca6` (roboshop-frontend) | `aws ec2 describe-security-groups` |

## 3. Create script: ec2-creation.sh

```bash
#!/bin/bash

##ec2 creation

aws ec2 run-instances \
  --image-id ami-0220d79f3f480ecf5 \
  --instance-type t3.micro \
  --subnet-id subnet-03628f95f21fe62ce \
  --security-group-ids sg-0def50d1e6c5ddca6 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server-roboshop}]' \
  --count 1
```

```bash
$ sh ec2-creation.sh
{
    "ReservationId": "r-0d29ab97643309fd1",
    "Instances": [
        {
            ...
            "GroupName": "roboshop-frontend",
            "PrivateIpAddress": "172.31.4.195",
            ...
:
```

✅ Instance created: `i-0c468b75e028ff1e9`, private IP `172.31.4.195`, SG `roboshop-frontend`.

| Option | Console field |
|---|---|
| `--image-id` | AMI |
| `--instance-type` | Instance type |
| `--subnet-id` | Subnet (optional in the default VPC) |
| `--security-group-ids` | Security group |
| `--tag-specifications ... Key=Name` | Name |
| `--count 1` | Number of instances |

> The `:` at the end = the output opened in a **pager** (`less`). Press `q` to exit. To turn it off: `aws configure set cli_pager ""`.

## 4. Terminate script: ec2-termination.sh

Finds the instance **by its Name tag**, terminates it and waits until it's gone. Works for one or many names.

```bash
#!/bin/bash

##ec2 termination
# Usage: bash ec2-termination.sh <server-name> [more names...]

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $# -eq 0 ]; then
    echo -e "${R}Usage: bash $0 <server-name>${N}"
    exit 1
fi

for name in $@
do
    instance_id=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=pending,running,stopped" \
      --query 'Reservations[].Instances[].InstanceId' --output text)

    if [ -z "$instance_id" ]; then
        echo -e "$name not found...${Y}SKIPPING${N}"
        continue
    fi

    aws ec2 terminate-instances --instance-ids $instance_id &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "Terminating $name ($instance_id)...${R}FAILED${N}"
        exit 1
    fi

    echo "Terminating $name ($instance_id)... waiting"
    aws ec2 wait instance-terminated --instance-ids $instance_id
    echo -e "$name ($instance_id) terminated...${G}SUCCESS${N}"
done
```

```bash
$ bash ec2-termination.sh web-server-roboshop
Terminating web-server-roboshop (i-0c468b75e028ff1e9)... waiting
web-server-roboshop (i-0c468b75e028ff1e9) terminated...SUCCESS
```

| Part | Meaning |
|---|---|
| `$#` / `$@` | Number of names / all names passed |
| `describe-instances --filters Name=tag:Name` | Find the instance ID **by Name** |
| `--query ... --output text` | Print only the ID, not the whole JSON |
| `-z "$instance_id"` | Empty = not found → `continue` to the next name |
| `terminate-instances --instance-ids` | Terminate needs **only the ID** |
| `aws ec2 wait instance-terminated` | Wait until it's fully gone |

## 5. Problems I faced and how I fixed them

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | `--iam-instance-profile Name=roboshop-server` | That instance profile **doesn't exist** in my account (checked with `aws iam list-instance-profiles`) → run-instances would fail | Removed the line. RoboShop servers don't call AWS APIs, so they don't need an IAM role |
| 2 | Output ended with `:` and didn't return to the prompt | AWS CLI opens long output in a **pager** | `q` to exit; `aws configure set cli_pager ""` |
| 3 | `ParamValidation: the following arguments are required: --instance-ids` | Changed `run-instances` to `terminate-instances` but kept the **create options** (image-id, type, subnet...) | Separate script: look up the ID by Name tag, then `terminate-instances --instance-ids <id>` |
| 4 | `-e Usage: bash ec2-termination.sh <server-name>` | Ran it with **`sh`**: on Ubuntu `sh` is dash, which doesn't understand `echo -e`. Also no name was passed | Run with **`bash`** and pass the name: `bash ec2-termination.sh web-server-roboshop` |
| 5 | Couldn't copy from Vim: right-click **Copy** was greyed out | Vim's **mouse mode** made a Vim selection, not a terminal selection | Hold **Shift** while dragging → `Ctrl+Shift+C`. Permanent: `set mouse=` in `~/.vimrc` |

> **What is an instance profile?** The container that attaches an **IAM role** to an EC2 instance, so programs on it get temporary AWS credentials without stored keys. Optional: only needed when the server itself calls AWS (S3, SSM...).

## 6. Summary

| What | Result |
|---|---|
| Tool | AWS CLI from my Ubuntu laptop, IAM user (not root) |
| Created | 1 × t3.micro (`web-server-roboshop`) with `run-instances` |
| Terminated | Same instance with my own script: lookup by Name → terminate → wait |
| Script skills used | Variables, `$( )`, `$#`, `$@`, `for` loop, `if` / `-z`, `continue`, `exit 1`, colors |
| Problems fixed | 5 (missing instance profile, pager, wrong terminate args, sh vs bash, Vim copy) |
| Cost | Instance terminated the same night |
