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

**13. `validate` function or `set -euo pipefail`?**

"I learned error handling with a `validate` function that checks `$?` after each step, which gives clear logs and lets me allow expected failures. In production I'd add `set -euo pipefail` as a safety net, so nothing slips through if I forget a check."

**14. What does `trap` do, and which signals do you use?**

It runs a command when something happens: `ERR` when a command fails (print `$LINENO`), `EXIT` when the script ends (cleanup), `INT` on Ctrl+C, `TERM` when killed.

**15. Does quoting `"$DIR"` make `rm -rf "$DIR"/*` safe?**

No. Quoting fixes spaces, not empty values: an empty `DIR` still gives `rm -rf /*`. Use `"${DIR:?}"` so the script stops if it's empty.

**16. A command succeeded (`$?` is 0) but the script still did the wrong thing. How?**

Some commands succeed but return nothing, e.g. `describe-instances` with an empty instance ID returns every instance. Check important values aren't empty (`[ -z "$x" ]` or `${x:?}`), not just the exit code.

**17. When do you use a for loop and when a while loop?**

"Both repeat commands, but they decide how many times differently. A **for** loop runs once for each item in a list, so I use it when I know the items: in my RoboShop `roboshop.sh`, `for instance in $@` creates one server per name. A **while** loop runs as long as a condition is true, so I use it when I don't know how long: waiting for a service's health check after a restart, retrying a command, or reading a file line by line with `while read line`. The risk with while is an infinite loop, so I add a counter or a max number of retries."
