# Day 15 - Shell Loops, Error Handling & AWS CLI

> **In short:** Keep scripts **short and readable**. Put repeated code in **functions**, send output to **logs** with redirections, repeat work with **loops** (`for package in $@`), check whether something is already done before doing it again, and handle the errors you **know** about. The same scripting skills drive AWS from the command line: `aws ec2 run-instances` launches a server without the console.

## Table of Contents

1. [Building blocks recap](#building-blocks-recap)
2. [Good code vs bad code](#good-code-vs-bad-code)
3. [Functions recap](#functions-recap)
4. [Redirections recap](#redirections-recap)
5. [Loops](#loops)
   - [How a for loop works (step by step)](#how-a-for-loop-works-step-by-step)
   - [Loop syntax in bash](#loop-syntax-in-bash)
6. [Real script: install many packages with a loop](#real-script-install-many-packages-with-a-loop)
7. [Error handling: known vs unknown errors](#error-handling-known-vs-unknown-errors)
8. [Programming vs scripting](#programming-vs-scripting)
9. [Programmatic access: AWS CLI](#programmatic-access-aws-cli)
10. [Pipe `|`](#pipe-)
11. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
12. [Key takeaways](#key-takeaways)
13. [Interview Questions](#interview-questions)

**More in this folder:** [Interview questions](interview-questions/README.md)

---

## Building blocks recap

```
Variables ──► Data types ──► Conditions ──► Functions ──► Loops ──► Error handling
```

Order of work: **Algorithm** (plain steps) → **Pseudocode** (structured steps) → **Syntax** (real code). See [Day 14](../day-14-shell-scripting-git-basics/README.md).

> Shell does **not** exit by itself when a command fails. Checking the previous command's exit status (`$?`: `0` = success, not `0` = failure) is **our** responsibility.

## Good code vs bad code

| Code | Result |
|---|---|
| Fewer lines, more clarity, more readable | ✅ **Good** |
| More lines, less clarity, less readable | ❌ **Bad** |

Functions and loops are the main tools for this: write a block **once** and reuse it.

## Functions recap

**Function** = a block of code that does **one task**. It takes **input** and gives **output**. Keep repeated code in a function.

```bash
FUNC_NAME(){
    # $1 = input-1
    # $2 = input-2
    repeated code
}

FUNC_NAME "input-1" "input-2"
```

Full example (`validate`): [Day 14 → Functions](../day-14-shell-scripting-git-basics/README.md#functions).

## Redirections recap

`>` redirects output into a file, `>>` **appends** to it.

| Number | Stream |
|---|---|
| `1` | success output (stdout) |
| `2` | error output (stderr) |
| `&` | both |

```bash
ls -l > output.log          # same as: ls -l 1> output.log   (only success output)
ls -lwrongflag 2> output.log    # only the error goes to the file
ls -l &> output.log         # success + errors
ls -l &>> output.log        # success + errors, appended
```

Logs for scripts go under `/var/log/`, e.g. `/var/log/shell-practice/13-logs.sh.log`. More: [Day 14 → Logs and redirections](../day-14-shell-scripting-git-basics/README.md#logs-and-redirections).

## Loops

**Loop** = run the same block of code **again and again**, for a list of values or until a condition becomes false.

### How a for loop works (step by step)

Classic loop that prints 0 to 100:
```
for (i=0; i<=100; i++) {
    echo $i
}
```

| Step | i | Check `i<=100` | Action |
|---|---|---|---|
| Start | 0 | true | print 0 |
| Next | 1 | true | print 1 |
| ... | ... | ... | ... |
| Next | 99 | true | print 99 |
| Next | 100 | true | print 100 |
| Next | 101 | **false** | **loop stops** |

1. **Set** the start value (`i=0`)
2. **Check** the condition (`i<=100`)
3. True → **run** the body, then **increase** `i` (`i++`) and check again
4. False → **exit** the loop

### Loop syntax in bash

```bash
# 1. numbers 0 to 100 (C style)
for (( i=0; i<=100; i++ ))
do
    echo $i
done

# 2. a range
for i in {1..10}
do
    echo $i
done

# 3. a list of values
for package in nginx mysql python3
do
    echo "package: $package"
done

# 4. every argument passed to the script
for package in $@
do
    echo "package: $package"
done
```

| Part | Meaning |
|---|---|
| `for x in list` | Take each value of the list into `x`, one by one |
| `do ... done` | The body: runs once per value |
| `$@` | **All arguments** given to the script: `sh script.sh nginx mysql` → `nginx mysql` |

## Real script: install many packages with a loop

`16-loops.sh` installs any number of packages passed as arguments. It **skips** a package that is already installed, and logs everything.

```bash
#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/shell-practice"
logs_file="${logs_folder}/${0}.log"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

echo "Script started execution at $(date +"%F %T")" &>> $logs_file

validate(){
    if [ $1 -ne 0 ]; then
        echo "${2}..FAILED" | tee -a $logs_file
        exit 1
    else
        echo "${2}..SUCCESS" | tee -a $logs_file
    fi
}

for package in $@
do
    dnf list installed $package &>> $logs_file
    if [ $? -ne 0 ]; then
        echo "Going to install: ${package}"
        dnf install $package -y &>> $logs_file
        validate $? "Installing ${package}"
    else
        echo "${package} already installed...SKIPPING"
    fi
done
```

**How it works:**

```
sudo sh 16-loops.sh nginx mysql python3
             │
             ▼
for each package in $@  (nginx → mysql → python3)
             │
   dnf list installed <package>
        │                    │
   $? = 0 (installed)   $? ≠ 0 (not installed)
        │                    │
   "already installed   dnf install <package> -y
    ...SKIPPING"              │
                         validate $? → SUCCESS / FAILED (exit)
```

| Line | Meaning |
|---|---|
| `for package in $@` | Loop over every package name given to the script |
| `dnf list installed $package` | Exit status **0** if installed, **not 0** if not installed |
| `if [ $? -ne 0 ]` | Not installed → install it |
| `else ... SKIPPING` | Already installed → do nothing |
| `validate $? "Installing ${package}"` | Check the install; on failure, stop the script |
| `&>> $logs_file` | `dnf` output goes to the log, the screen stays clean |

**Run it:**
```bash
sudo sh 16-loops.sh nginx mysql python3
# Going to install: nginx
# Installing nginx..SUCCESS
# mysql already installed...SKIPPING
# Going to install: python3
# Installing python3..SUCCESS

sudo sh 16-loops.sh nginx mysql python3     # run again
# nginx already installed...SKIPPING
# mysql already installed...SKIPPING
# python3 already installed...SKIPPING
```

> **Idempotent** = running the script again gives the **same result** without doing the work twice. Checking "already installed?" before installing makes this script safe to re-run. Ansible and Terraform work on the same idea.

## Error handling: known vs unknown errors

| Type | Example | What we do |
|---|---|---|
| **Known errors** | Not root, package install fails, folder missing, package already installed | **Handle** them: check `$?`, print a clear message, `exit 1` or skip |
| **Unknown errors** | Something we never expected (network drop, disk full in the middle, a bug in a tool) | Can't handle in advance. Logs help find them later |

> Handle every error you can predict. For the rest, **log everything**, so you can find out what happened.

## Programming vs scripting

| | Programming | Scripting |
|---|---|---|
| Who | **Developers** | **DevOps** engineers, DBAs (PL/SQL) |
| Builds | Applications (Java, Python, Node.js apps) | Automation of tasks (install, deploy, configure) |
| Example | A shopping website backend | A script that installs and configures nginx on 10 servers |

## Programmatic access: AWS CLI

**Programmatic access** = working with AWS from **code or commands** instead of clicking in the console.

| Way | Used by |
|---|---|
| **Console** (web UI) | Humans, manual work |
| **AWS CLI** (`aws ...` commands) | Scripts, DevOps automation |
| **SDK** (Software Development Kit: boto3 for Python, AWS SDK for Java/Node.js) | Applications written by developers |

**Console steps vs CLI.** Launching an instance in the console means: login → launch instance → name, AMI, instance type, security group, disk, key. The CLI does it in one command:

```bash
aws ec2 run-instances \
    --image-id ami-xxxxxxxxxxxxxxxxx \
    --instance-type t3.micro \
    --security-group-ids sg-xxxxxxxxxxxxxxxxx \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=roboshop-mongodb}]'
```

| Option | Console field |
|---|---|
| `--image-id` | AMI |
| `--instance-type` | Instance type |
| `--security-group-ids` | Security group |
| `--tag-specifications ... Key=Name,Value=...` | Name |

> Before using the CLI: `aws configure` (access key, secret key, region), or an IAM role on the server.

**Order for automation:** create the security group first → give its ID to `run-instances`. With a loop, one script can launch all RoboShop servers:

```bash
for instance in mongodb redis mysql rabbitmq catalogue user cart shipping payment dispatch frontend
do
    aws ec2 run-instances --image-id ami-xxxx --instance-type t3.micro \
        --security-group-ids sg-xxxx \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]"
done
```

## Pipe `|`

`command-1 | command-2` = the **output of command-1** becomes the **input of command-2**.

```bash
ls -l | grep ".sh"                  # list only .sh files
cat /etc/passwd | wc -l             # count users
echo "Nginx..SUCCESS" | tee -a app.log   # screen + log file
```

## Common problems and how to solve them

- **Script installs a package again every run** - check first with `dnf list installed <package>` and skip if it's there.
- **`for package in $@` does nothing** - no arguments were passed. Run it as `sudo sh 16-loops.sh nginx mysql`.
- **Loop never stops** - the condition never becomes false (for example, `i` is never increased).
- **`aws: command not found` / `Unable to locate credentials`** - install the AWS CLI, then run `aws configure` or attach an IAM role to the server.
- **Screen flooded with install output** - redirect it: `&>> $logs_file`.

## Key takeaways

- Fewer lines, more clarity: use **functions** for repeated code and **loops** for repeated actions.
- A function does one task: input `$1`, `$2` ... in, result out.
- `1>` = success output, `2>` = errors, `&>` = both; `>>` appends.
- A `for` loop: set a start value → check the condition → run the body → repeat until false.
- `for package in $@` loops over every argument passed to the script.
- Check before you act (`dnf list installed`) so the script is **idempotent**: safe to run again.
- **Known errors** → handle them; **unknown errors** → log everything so you can trace them.
- Programming builds apps (developers); scripting automates tasks (DevOps).
- **Programmatic access** = AWS CLI or SDK instead of the console; `aws ec2 run-instances` launches a server in one command.
- `|` sends one command's output into the next command.

See also: [Day 14 - Shell Scripting and Version Control Basics](../day-14-shell-scripting-git-basics/README.md)

---

## Interview Questions

10 questions with short answers → [interview-questions/](interview-questions/README.md)
