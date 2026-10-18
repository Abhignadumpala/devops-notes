# Day 15 - Interview Questions

[← Back to Day 15 notes](../README.md)

**1. Does a shell script stop when a command fails?**

No. Shell keeps going by default. We check `$?` after important commands (`0` = success, not `0` = failure) and `exit 1` ourselves.

**2. Why use functions in a script?**

To keep repeated code in one place. A function does one task, takes inputs (`$1`, `$2`) and is called many times, so the script has fewer lines and is easier to read and fix.

**3. What do `1>`, `2>` and `&>` mean?**

`1>` redirects success output, `2>` redirects errors, `&>` redirects both. `>` overwrites the file, `>>` appends.

**4. How does a for loop work?**

Set a start value, check the condition, run the body, update the value, and repeat until the condition is false.

**5. What is `$@` used for in a loop?**

It holds all the arguments passed to the script, so `for package in $@` runs the loop once per argument.

**6. How do you make an install script safe to run again?**

Check first (`dnf list installed <package>`): if it's installed, skip it; if not, install it. That makes the script idempotent.

**7. What is idempotency?**

Running something many times gives the same result as running it once. Ansible and Terraform are built on this idea.

**8. Known errors vs unknown errors?**

Known errors (no root access, install failed) can be checked and handled in the script. Unknown errors can't be predicted, so we log everything to trace them later.

**9. What is programmatic access in AWS?**

Using AWS through the CLI or an SDK instead of the console. Example: `aws ec2 run-instances --image-id ... --instance-type t3.micro` launches a server from a script.

**10. What does the pipe `|` do?**

It sends the output of one command as input to the next, for example `ls -l | grep ".sh"`.

**11. What does `set -e` do?**

It makes the script exit as soon as any command fails, instead of continuing. Commands inside an `if` condition don't trigger it.

**12. What is `trap ... ERR` used for?**

It runs a command whenever an error happens, e.g. `trap 'echo "Error at line $LINENO: $BASH_COMMAND"' ERR`, so you see exactly which line and command failed.
