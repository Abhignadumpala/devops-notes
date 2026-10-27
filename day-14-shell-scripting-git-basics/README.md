# Day 14 - Shell Scripting and Version Control Basics

> **In short:** Manual steps are slow, error-prone and leave no record. A **shell script** makes them repeatable. **Git** makes those scripts safe to change - history, backup, versions, review. The shell gives you **special variables** for free, has **no real data types**, never stops on failure by itself (check **`$?`**), and lets a script branch with **conditions**.

## Table of Contents

1. [What this is / why it matters](#what-this-is--why-it-matters)
2. [Building blocks of any script](#building-blocks-of-any-script)
3. [How it works](#how-it-works)
   - [The problem with doing things manually](#the-problem-with-doing-things-manually)
   - [Why scripts still aren't enough on their own](#why-scripts-still-arent-enough-on-their-own)
   - [VCS/SCM, and where Git fits](#vcsscm-and-where-git-fits)
   - [Shebang](#shebang)
   - [Variables](#variables)
   - [Special variables](#special-variables)
   - [Exit status](#exit-status)
   - [Environment variables](#environment-variables)
   - [Shell has no real data types](#shell-has-no-real-data-types)
   - [Think before you write code: algorithm and pseudocode](#think-before-you-write-code-algorithm-and-pseudocode)
   - [Conditions](#conditions)
   - [Functions](#functions)
   - [Logs and redirections](#logs-and-redirections)
4. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
5. [Key takeaways](#key-takeaways)
6. [What I learned](#what-i-learned)
7. [Interview Questions](#interview-questions)

**More in this folder:** [Interview questions](interview-questions/README.md)

---

## What this is / why it matters

Doing deployments and server changes by hand (typing commands one at a time, every time) doesn't scale and doesn't stay safe for long. Shell scripting turns a sequence of manual steps into a single, repeatable program. Version control (Git) is what makes it safe to change those scripts over time - tracking who changed what, keeping old versions recoverable, and letting more than one person work on the same code. Beyond the basics of writing and running a script, the shell also hands you built-in variables for free, remembers some variables across a whole login session, has no real data types at all, and lets a script branch based on a condition - and every command it runs leaves behind a status telling you whether it actually worked.

## Building blocks of any script

Almost every scripting language is learned in the same order. Learn these 6, and any new language is just new syntax:

| # | Step | What it is | Shell example |
|---|---|---|---|
| 1 | **Variables** | Store a value under a name, write it once and reuse it | `NAME="John"` |
| 2 | **Data types** | The kind of value (string, number, boolean, list). Shell treats everything as a string | `COUNT="5"` |
| 3 | **Conditions** | Choose what to run based on true / false | `if [ $USER_ID -ne 0 ]; then ... fi` |
| 4 | **Functions** | Group steps under a name, call them many times | `VALIDATE() { ... }` |
| 5 | **Loops** | Repeat the same steps for many items | `for pkg in nginx mysql; do ... done` |
| 6 | **Error handling** | Detect failures and stop or report them | `if [ $? -ne 0 ]; then echo "failed"; exit 1; fi` |

```
Variables ──► Data types ──► Conditions ──► Functions ──► Loops ──► Error handling
 (store)       (what kind)    (decide)      (reuse)      (repeat)   (catch failures)
```

## How it works

### The problem with doing things manually

Running commands by hand, one at a time, has the same handful of problems every time:
- **Only you know the steps** - there's no written record of what was actually done, only whatever is in someone's head or a one-off note.
- **It's slow** - every repeat of the same deployment takes the same amount of manual effort again.
- **Human mistakes** - a skipped step or a typo is easy to make and easy to miss.
- **No easy way back** - if something goes wrong, there's no recorded "previous state" to restore to.
- **No accountability** - when several people can log in and make changes, it's hard to tell who changed what.

A shell script fixes the first four: it's a written, repeatable, exact record of the steps, run the same way every time.

### Why scripts still aren't enough on their own

A script sitting on a server (or a laptop) by itself still has gaps:
- **No security** - anyone with access to the file can change it, with no record of the change.
- **No backup** - if the file is deleted or corrupted, that version of the logic is gone.
- **No versioning** - there's no way to tell "this is version 1.0.0" from "this is version 2.0.0," or to go back to an older one.
- **No collaboration** - two people editing the same file by hand will overwrite each other.
- **No review** - nobody gets a chance to check a change before it takes effect.
- **No tracking** - no history of what changed, when, or why.

This is exactly what a **version control system (VCS)**, also called **source code management (SCM)**, is for.

### VCS/SCM, and where Git fits

Different tools store different kinds of things:
- **Git** - stores and versions source code (and scripts).
- **Google Drive** (and similar) - general file/object storage, not built for tracking code changes.
- **An artifact repository** (e.g. Nexus, Artifactory) - stores build outputs (artifacts), not source code.

A **repository** is just storage for something - in Git's case, storage for a project's code and its full history of changes.

Basic Git workflow:
```bash
# one-time setup, per machine (or per repo with the --global flag removed)
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

git init                       # turn the current folder into a git repo
git branch -M main             # name the default branch "main"
git add .                      # stage all changes
git commit -m "my first commit"
git remote add origin <URL>    # point this repo at one on GitHub
git push origin main           # upload commits to the remote repo
```

A normal folder becomes a **git repo** the moment it has a hidden `.git` subfolder in it - that's what Git uses to track history. No `.git` folder means it's just a regular folder, with no version tracking at all.

Typical day-to-day flow for one file:
```bash
git add 01-hello-world.sh              # stage the file
git commit -m "my first shell script"  # commit to the local repo
git push origin main                   # push to the remote repo (e.g. GitHub)
```

The usual review habit before touching an important shared file: make a copy, make the change in the copy, show it to a lead/reviewer, and only then replace the original once it's approved. Git's review tools (pull requests) are the structured version of this same idea.

### Shebang

Every shell script should start with a **shebang** line:
```bash
#!/bin/bash
```
It has to be the very first line in the file. The shebang tells Linux which interpreter should run the rest of the file - without it, Linux has no way to know the file is a set of bash commands rather than, say, a Python script. "Shell script" and "bash script" mean the same thing here, since bash is the shell being used.

**Comments** start with `#`. They are only for information; the shell doesn't run them (the shebang is the one special `#!` line).

```bash
#!/bin/bash

# This is a comment, just for information. This line is not executed
echo "Hello World!"
```

### Variables

A variable holds a value under a name, so the value only has to be written once:
```bash
NAME="John"
```

> **No spaces around `=`**: `PERSON1=John` works, `PERSON1 = John` gives `command not found`.

```bash
#!/bin/bash
PERSON1=John
PERSON2=Raheem

echo "$PERSON1:: Hi, $PERSON2. How are you?"
echo "$PERSON2:: Hello $PERSON1. I am good. How about you?"
```
This matters for the same reason **DRY (Don't Repeat Yourself)** matters in any code: if a value (a path, a username, a number used in a calculation) is typed out directly in ten places and it needs to change, all ten have to be found and fixed by hand. Held in one variable, it only has to change in one place, and that one change takes effect everywhere the variable is used - which also prevents accidental, inconsistent edits.

**Arguments** are values passed into a script when it's run:
```bash
sh 04-variables.sh John Raheem
```
Inside the script, these show up as numbered variables - `$1` is the first argument, `$2` is the second, and so on:
```text
$1 = John
$2 = Raheem
```

**Command substitution** runs a command and stores its output in a variable, using `$( )`:
```bash
START_TIME=$(date +%s)
```
This is how a script can measure its own runtime - capture the time at the start, capture it again at the end, and subtract:
```text
Script executed at: 08:34 AM
Script completed at: 08:35 AM
Total time for execution is 1 min
```

**Full timing script** (`05-variables.sh`), using **arithmetic** `$(( ))`:
```bash
#!/bin/bash

START_TIME=$(date +%s)          # seconds since 1970 (epoch time)
echo "Script started execution at: $START_TIME"

sleep 10

END_TIME=$(date +%s)
echo "Script completed execution at: $END_TIME"

TOTAL_TIME=$(($END_TIME-$START_TIME))
echo "Total time taken: $TOTAL_TIME Seconds"     # 10 Seconds
```

| Syntax | Meaning |
|---|---|
| `$( )` | Run a **command**, use its output |
| `$(( ))` | Do **maths**: `+ - * / %` |
| `${ }` | Read a **variable** |

**User input with `read`:** the script waits for you to type a value.
```bash
#!/bin/bash

echo "Please enter your username::"
read USER_NAME          # what you type goes into USER_NAME

echo "Please enter your password::"
read -s PASSWORD        # -s = silent, the typing is not shown on screen

echo "Username is: $USER_NAME"
```

> Use `read -s` for passwords so nobody can see them on the screen. Never `echo` a password in a real script.

Variable access uses `$VAR` or, to make the variable name's boundary explicit (e.g. right before more text), `${VAR}`.

**Quote your variables: `"$VAR"`**

```bash
rm "$FILE"      # correct: quotes around the whole variable, including $
rm $"FILE"      # wrong: $"..." is a different bash feature (translated text), not a variable
```

| Problem | Example | Fix |
|---|---|---|
| **Spaces** in a value | `FILE="my report.txt"` → `rm $FILE` tries to delete `my` and `report.txt` | `rm "$FILE"` |
| **Empty** value | `DIR=""` → `rm -rf "$DIR"/*` = `rm -rf /*` (quotes **don't** help here) | `rm -rf "${DIR:?DIR is empty}"/*` → script stops, nothing deleted |

> `${VAR:?message}` = stop the script with `message` if `VAR` is empty or unset.

### Special variables

The shell gives us these variables for free - we don't create them, we just use them:

| Variable | What it does |
|---|---|
| `$@` | Shows **all the args** passed to the script → `John Raheem` |
| `$*` | Also shows **all the args**, but as **one single word** → `"John Raheem"` |
| `$#` | Shows the **number of args** passed to the script → `2` |
| `$1`, `$2`, ... | Shows the **first, second, ... arg** passed → `$1` = `John`, `$2` = `Raheem` |
| `$0` | Shows the **script name** → `script.sh` |
| `$(realpath $0)` | Shows the **full path** of the script → `/home/ec2-user/script.sh` |
| `$USER` | Shows **who is running** the current script → `ec2-user` |
| `$PWD` | Shows the **directory** of the current script → `/home/ec2-user` |
| `$HOME` | Shows the **home directory** of the current user → `/home/ec2-user` |
| `$$` | Shows the **PID** of the current script → `2345` |
| `$!` | Shows the **PID of the command running in the background** now → `2346` |
| `$LINENO` | Shows the **current line number** in the script → `15` |
| `$?` | Shows the **exit status of the previous command** → `0` success, not 0 failure |
| `$SECONDS` | Shows the **total time** the script has been running, in seconds → `10` |

Examples use the run `sh script.sh John Raheem`.

**Exit status (`$?`)** - if we want to know the status of the previous command, we can use `$?`:

```text
0      -> success
1-127  -> failure   (any value that is not 0 = failure)
```

**Full script** (`special-variables.sh`):

```bash
#!/bin/bash

echo "All args passed to the script: $@"
echo "All args passed to the script as word: $*"
echo "Number of args passed to the script: $#"
echo "First variable passed: $1"
echo "Script name: $0"
echo "Realpath: $(realpath $0)"
echo "Who is running current script: $USER"
echo "Directory of the current script: $PWD"
echo "Home directory of the current user: $HOME"
echo "PID of the current script: $$"
sleep 10 &
echo "PID of the command running in background now: $!"
wait $!     # script waits until the $! command (sleep 10) is complete
echo "Line number: $LINENO"
echo "previous command exit status: $?"
echo "Total time executed for this script: $SECONDS"
```

**Run it:** `sh special-variables.sh John Raheem`

```text
All args passed to the script: John Raheem
All args passed to the script as word: John Raheem
Number of args passed to the script: 2
First variable passed: John
Script name: special-variables.sh
Realpath: /home/ec2-user/special-variables.sh
Who is running current script: ec2-user
Directory of the current script: /home/ec2-user
Home directory of the current user: /home/ec2-user
PID of the current script: 2345
PID of the command running in background now: 2346
Line number: 15
previous command exit status: 0
Total time executed for this script: 10
```

> `sleep 10 &` - the `&` runs `sleep` in the **background**, so the script doesn't wait. `wait $!` makes the script **wait until that background command is complete** - that's why the total time is 10 seconds.

### Exit status

If we want to know the **status of the previous command**, we use `$?`.

| `$?` value | Meaning |
|---|---|
| `0` | **success** |
| `1`–`255` (anything not 0) | **failure** |
| `127` | command not found |
| `126` | command found but not executable |

```bash
ls /tmp
echo $?        # 0   -> success

ls /nofolder
echo $?        # 2   -> failure

abc
echo $?        # 127 -> command not found
```

Nothing stops a shell script automatically just because one command in it failed - checking `$?` after anything that matters (installing a package, a critical step in a deployment) is the script writer's own responsibility. Example:
```
start
check if the user running has sudo access
  if yes, proceed
  if no, error

install the package
check exit status ($?)
  0  -> success
  not 0 -> failure
```

### Environment variables

`export` makes a variable available to the current session **and** to any sub-process started from it:
```bash
export COURSE="Shell Script"
export DURATION="10 Hrs"
```
This only lasts as long as the session is alive - log out, and the variable is gone. To persist it:
- `~/.bashrc` - persists for one specific user only (e.g. `ec2-user`). Run `source ~/.bashrc` to reload it without logging out again.
- `/etc/profile.d/*.sh` - persists for every user on the machine.

Running `env` lists every environment variable currently available, including the ones you loaded yourself. A common naming convention for variables is **snake_case**, e.g. `user_id`.

### Shell has no real data types

Other languages distinguish between data types - `int`, `float`, `double`, `long`, `char`, `string`, `boolean`, `array`, `list`, `set`, `map`, and so on. Shell doesn't: **by default, shell treats everything as a string**, whether it looks like a number, a yes/no value, or a list.

Why real data types matter elsewhere: in 1996, the Ariane 5 rocket (flight 501) was destroyed about 37 seconds after launch because reused Ariane 4 guidance software converted a 64-bit floating-point velocity value into a 16-bit signed integer - the new rocket's higher velocity overflowed that integer, the conversion wasn't protected against the overflow, and the resulting error cascaded into the flight computer reading garbage as real flight data. Shell skipping data types entirely means that specific failure mode doesn't apply the same way, but it also means shell won't catch type mistakes for you - the responsibility shifts to the script writer.

**Data types in practice** (`09-data-types.sh`):
```bash
#!/bin/bash

var1=10
var2=20
var3=devops

echo "$var1+$var2"                  # 10+20   → just text, no maths
echo "$(($var1+$var2))"             # 30      → $(( )) does the maths
echo "$(($var1+$var2+$var3))"       # 30      → "devops" is not a number, counted as 0

declare -i COUNT=5                  # declare as integer
COUNT=COUNT+1
echo "Count is: $COUNT"             # 6

FRUITS=("Apple" "Banana" "Papaya")  # array
echo "All fruits: ${FRUITS[@]}"     # Apple Banana Papaya
echo "First fruit: ${FRUITS[0]}"    # Apple  (index starts at 0)
echo "Second fruit: ${FRUITS[1]}"   # Banana

name="DevOps"
echo "${name}Engineer"              # DevOpsEngineer
```

| Concept | Meaning |
|---|---|
| `"$var1+$var2"` | Shell joins **text**: `10+20` |
| `$(( ))` | Turns the values into numbers and calculates |
| `declare -i` | Tells shell "this variable is an **integer**", so `COUNT+1` is maths |
| **Array** `( "a" "b" )` | Many values in one variable. `${ARR[@]}` = all, `${ARR[0]}` = first |
| `${name}Engineer` | `{}` mark where the variable name ends |

> Arrays start at index **0**: `${FRUITS[0]}` is the **first** fruit, `${FRUITS[1]}` the second.

### Think before you write code: algorithm and pseudocode

Before writing any real syntax, work out the steps in plain English (the **algorithm**) and then as simple structured steps (**pseudocode**) - no particular language's syntax yet, just the logic. Roughly 90% of the effort in solving a problem is this thinking step; the actual code is the easy 10% once the steps are clear.

Example - checking if a number is even or odd:
1. Get the number.
2. Divide it by 2, get the remainder.
3. If the remainder is 0 → even. Otherwise → odd.

### Conditions

A condition lets a script choose between different actions instead of always running the same steps. The logic is worked out the same way as any algorithm - in plain steps - before it becomes real code:

```
if (expression) {
  this runs if the expression is true
} else if (expression) {
  this runs if that expression is true
} else {
  this runs if none of the above were true
}
```

Example - even or odd:
```
start
get the number
divide it by 2, get the remainder
if remainder is 0:
  print number is even
else:
  print number is odd
```

Example - grading scale, using ranges instead of a single equality check:
```
less than 33                      -> fail
33 up to (not including) 50       -> third class
50 up to (not including) 60       -> second class
60 up to (not including) 75       -> first class
75 and above                      -> distinction
```

The grading scale as a real script (`10-condition.sh`), with `if` / `elif` / `else`:
```bash
#!/bin/bash

echo "Please enter the marks"
read marks

if [ $marks -lt 33 ]; then          # -lt = less than
    echo "Fail"
elif [ $marks -lt 50 ]; then
    echo "Third class"
elif [ $marks -lt 60 ]; then
    echo "Second class"
elif [ $marks -lt 75 ]; then
    echo "First class"
else
    echo "Distinction"
fi

echo "End"
```

| Keyword | Meaning |
|---|---|
| `if [ ... ]; then` | Check the first condition |
| `elif [ ... ]; then` | "else if": checked only when everything above was false |
| `else` | Runs when **no** condition was true |
| `fi` | End of the `if` block (`if` written backwards) |

Run: enter `45` → `Third class`. Enter `80` → `Distinction`. Checks go **top to bottom** and stop at the first true one.

Example - combining a condition with exit status, before installing a package (`dnf install nginx -y`):
```
start
get the user_id
if user_id is 0 (root) -> proceed
if user_id is not 0    -> error, end

install the package
check exit status ($?)
  0     -> success
  not 0 -> show failure
```
The same logic as a real bash script is in [Functions](#functions) below.

### Functions

**Function** = a block of code with a name. Write it once, call it many times.

```bash
greet(){                     # define
    echo "Hello $1, you are $2"
}

greet Abhi DevOps            # call → Hello Abhi, you are DevOps
greet Ravi Cloud             # call → Hello Ravi, you are Cloud
```

| Point | Meaning |
|---|---|
| Define before you call | Bash reads top to bottom, so the function must be above the line that uses it |
| `$1`, `$2` inside a function | The values passed **to the function** (not to the script) |
| Why use one | No repeated code; fix it in one place and every call gets the fix |

**Real example: sudo check + `validate` function** (`11-conditions.sh`). It checks for root first, then installs packages and checks every install with one reusable function:

```bash
#!/bin/bash

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

validate(){
    if [ $1 -ne 0 ]; then
        echo "${2}..FAILED"
        exit 1
    else
        echo "${2}..SUCCESS"
    fi
}

echo "proceeding...."
dnf install nginx -y
validate $? "Nginx Installation"

dnf install mysql -y
validate $? "Mysql Installation"

echo "Still proceeded..."
```

| Part | Meaning |
|---|---|
| `user_id=$(id -u)` | `$( )` runs a command and stores its output. `id -u` prints the user id: **root = 0** |
| `[ $user_id -ne 0 ]` | `-ne` = **not equal**. Not root → print a message and stop |
| `exit 1` | Stop the script right here with a failure status. Nothing below it runs |
| `validate(){ ... }` | A **function**: write the check once, call it after every install |
| `validate $? "Nginx Installation"` | Passes 2 values to the function: the exit status of `dnf install` and a name |
| `$1`, `$2` (inside the function) | The 1st and 2nd values passed to the function → `$1` = exit status, `$2` = "Nginx Installation" |
| `${2}..FAILED` | `${2}` is the same as `$2`; the `{}` separate the variable from the text after it |

**Number comparisons inside `[ ]`:**

| Operator | Meaning |
|---|---|
| `-eq` | equal |
| `-ne` | not equal |
| `-gt` / `-lt` | greater than / less than |
| `-ge` / `-le` | greater or equal / less or equal |

> Spaces matter: `[ $1 -ne 0 ]` works, `[$1 -ne 0]` gives an error.

**What happens when you run it:**

| Run as | Output |
|---|---|
| Normal user (`sh 11-conditions.sh`) | `Please run this script with sudo access..` → stops |
| Root, both installs work | `Nginx Installation..SUCCESS`, `Mysql Installation..SUCCESS`, `Still proceeded...` |
| Root, nginx install fails | `Nginx Installation..FAILED` → stops. MySQL is never installed and `Still proceeded...` never prints |

> **Why a function?** Without it, the same `if [ $? -ne 0 ]` block is copied after every install. With `validate`, one line per install, and a fix in one place fixes every check.

### Logs and redirections

**Why logs?** When a script runs `dnf install`, hundreds of lines fill the screen. Instead, send that output to a **log file**: the screen stays clean (only SUCCESS / FAILED), and if something breaks you open the log and see exactly what happened.

**Redirections:**

| Symbol | Sends | Into the file |
|---|---|---|
| `>` | normal output (stdout) | **overwrite** |
| `>>` | normal output | **append** (add at the end) |
| `2>` / `2>>` | error output (stderr) | overwrite / append |
| `&>` | output **and** errors | overwrite |
| `&>>` | output **and** errors | **append** ← used for logs |
| `\| tee -a file` | output | shows on **screen and** appends to the file |

```
1 = stdout (normal output)     2 = stderr (errors)     & = both
```

**Example script** (`13-logs.sh`): same sudo check + `validate` function, now with a log file:

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

echo "Script started execution at $(date +"%F %T")"

validate(){
    if [ $1 -ne 0 ]; then
        echo "${2}..FAILED" | tee -a $logs_file
        exit 1
    else
        echo "${2}..SUCCESS" | tee -a $logs_file
    fi
}

echo "proceeding...."
dnf install nginx -y &>> $logs_file
validate $? "Nginx Installation"

dnf install mysql -y &>> $logs_file
validate $? "Mysql Installation"

echo "Script execution completed at $(date +"%F %T")"
```

| Line | Meaning |
|---|---|
| `logs_folder="/var/log/shell-practice"` | `/var/log` is where Linux keeps logs. Our own folder inside it |
| `logs_file="${logs_folder}/${0}.log"` | `$0` = **script name** → `/var/log/shell-practice/13-logs.sh.log` |
| `mkdir -p $logs_folder` | Create the folder. `-p` = no error if it already exists |
| `$(date +"%F %T")` | Current date and time → `2026-10-18 00:13:45` (`%F` = date, `%T` = time) |
| `dnf install nginx -y &>> $logs_file` | All install output **and errors** go to the log, not the screen |
| `echo ... \| tee -a $logs_file` | SUCCESS / FAILED shows on the **screen** and is also saved in the **log** |

> **Common mistake:** `${date +"%F %T"}` gives `bad substitution`. `${ }` is for **variables**; `$( )` **runs a command**. Date is a command → `$(date +"%F %T")`.

**Run and check:**
```bash
sudo sh 13-logs.sh
# Script started execution at 2026-10-18 00:13:45
# proceeding....
# Nginx Installation..SUCCESS
# Mysql Installation..SUCCESS
# Script execution completed at 2026-10-18 00:14:20

cat /var/log/shell-practice/13-logs.sh.log     # full dnf output + SUCCESS lines
```

> **Tip:** run it as `sh 13-logs.sh` from the script's folder. If you run it with a full path (`sh /home/ec2-user/13-logs.sh`), `$0` becomes that full path and the log path breaks. `$(basename $0)` gives only the file name, whichever way it's run.

## Common problems and how to solve them

- **`fatal: unable to auto-detect email address` / "Please tell me who you are"** - Git refuses to commit until it knows who's committing. Fix: run `git config --global user.email "..."` and `git config --global user.name "..."` once per machine (drop `--global` to set it for just one repository).
- **Git push asks for authentication** - on a fresh setup, pushing to GitHub for the first time prompts for a login, usually handled by signing in through the browser when prompted.
- **A script runs "command not found" or behaves oddly depending on how it's run** - usually a missing or wrong shebang line. Make sure `#!/bin/bash` is the exact first line, with nothing above it.
- **Mixing up `$@` and `$#`** - `$@` is every argument's value; `$#` is just the count of how many were passed.
- **A script keeps going after a command fails** - shell doesn't stop on failure by itself; check `$?` right after any command whose success actually matters.
- **An exported variable "disappears"** - `export` only lasts for the current session. For something that needs to survive a logout, put it in `~/.bashrc` (one user) or a script under `/etc/profile.d/` (all users).
- **Unquoted variable breaks on spaces** - `rm $FILE` with `FILE="my report.txt"` deletes two wrong files. Always write `"$FILE"`. For values that must not be empty (like a folder before `rm -rf`), use `"${DIR:?}"`.
- **Treating a shell variable like a typed value** - e.g. assuming a variable "is a number" and relying on that for arithmetic or comparisons. Shell stores it as a string regardless; validate or convert it explicitly instead of assuming.

## Key takeaways

- Manual deployment has five recurring problems: no documentation of the steps, slow repetition, human error, no way to restore a previous state, and no accountability for who changed what.
- A shell script solves the manual-process problems by making the steps repeatable and written down - but a script by itself still has no security, backup, versioning, collaboration, review, or change tracking.
- Git (a VCS/SCM) solves that second set of problems; it's a different kind of tool from general file storage (Google Drive) or an artifact repository, which store different things entirely.
- A folder is a git repo only once it contains a `.git` subfolder - that's what's actually tracking the history.
- `#!/bin/bash` must be the first line of a shell script - it tells Linux which interpreter runs the file.
- Variables (including positional arguments `$1`, `$2`, ... and command substitution `$( )`) exist so a value is written once and reused - the same DRY principle behind avoiding repeated code anywhere else.
- **Quote variables** (`"$VAR"`, not `$"VAR"`): quotes fix spaces; `${VAR:?}` stops the script if a value is empty.
- Comments start with `#`; `read` (and `read -s` for passwords) takes user input; `$(( ))` does maths; arrays start at index 0.
- Special variables (`$@`, `$*`, `$#`, `$0`, `$USER`, `$PWD`, `$$`, `$!`, `$LINENO`, `$?`, `$SECONDS`) are provided by the shell, not declared by you; `$?` specifically holds the previous command's exit status (`0` success, non-zero failure), and checking it is on the script writer since shell doesn't stop automatically on failure.
- `export` makes a variable available for the session and to sub-processes; `~/.bashrc` persists it per-user, `/etc/profile.d/*.sh` persists it for everyone; `env` lists them all.
- Shell has no real data types - everything is a string by default, which puts the burden of correctness on the script writer rather than a type system.
- A **`validate` function** (`validate $? "name"`) checks the exit status after every install in one line: `$1` = status, `$2` = name, `exit 1` on failure.
- **Logs:** send command output to a log file with `&>>` (output + errors, append), and use `| tee -a` to show a message on screen and save it too. `$(cmd)` runs a command, `${var}` reads a variable.
- Any scripting language is built from the same 6 blocks: variables, data types, conditions, functions, loops, error handling.
- Work out logic as an algorithm/pseudocode before writing real syntax, then express it as conditions (`if` / `else if` / `else`) once the steps are clear.

See also: [Day 5 - Linux Administration](../day-05-users-packages-services-processes/linux-administration.md)

---

## What I learned

- Manual work = no record, slow, mistakes, no rollback, no accountability. **Scripts** fix the first three; **Git** fixes the rest.
- `#!/bin/bash` on line 1. **Variables:** no spaces around `=`; `$1 $2` arguments; `$( )` runs a command; `$(( ))` maths.
- **Quote variables** `"$VAR"` (not `$"VAR"`); `${VAR:?}` stops if empty.
- **Special variables:** `$@ $# $0 $? $$ $LINENO $SECONDS`. `$?` = last exit status (`0` = success).
- Everything is a **string**; `export` + `~/.bashrc` keeps a variable.
- **`validate $? "msg"`** after each step; logs with `&>>` and `tee -a`.
- Think in pseudocode first, then write `if / elif / else`.

---

## Interview Questions

11 questions with short answers → [interview-questions/](interview-questions/README.md)
