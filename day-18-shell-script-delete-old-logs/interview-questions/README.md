# Day 18 - Interview Questions

[← Back to Day 18 notes](../README.md)

## ⭐ Very Important (asked in class)

**1. Tell me about an issue you faced with a cron job. (Interview story: cron PATH, dev vs prod)**

| | What happened |
|---|---|
| **Situation** | I wrote a shell script (our `archive` command) and scheduled it with **crontab** to run every day. |
| **Problem** | I tested it first on the **development** server: it **worked**. On the **production** servers the same cron job **failed** with `command not found`. |
| **Root cause** | Cron's `$PATH` is **different** from the terminal's. The terminal has a long PATH; cron's PATH is **minimal** (`/usr/bin:/bin`). On dev, someone had set cron's PATH to include `/usr/local/bin`; on prod it was **not** set. The command lived in `/usr/local/bin`, so cron on prod couldn't find it. |
| **Fix** | Option 1: **change the command location** → call it by its full path (`/usr/local/bin/archive`). Option 2: **set the full PATH explicitly at the top of the script**: `PATH=/usr/bin:/bin:/usr/local/bin` |
| **Result** | The job ran on prod too. Lesson: "works on dev" doesn't mean "works on prod"; cron's environment must be checked. |

**Fix in the script: give the full PATH explicitly**

```bash
#!/bin/bash
PATH=/usr/bin:/bin:/usr/local/bin     # first line after the shebang
...rest of the script...
```

```
cron's PATH:     /usr/bin:/bin                      ← /usr/local/bin missing
script sets:     /usr/bin:/bin:/usr/local/bin       ← every folder written out
```

| Part | Means |
|---|---|
| `/usr/bin:/bin` | normal commands (`find`, `tar`, `rm`, `date`) |
| `/usr/local/bin` | our own commands (`archive`, `cleanup`) |
| `:` | separator between folders (**no spaces**) |

**Why write the full PATH explicitly?** The script no longer depends on what PATH cron (or the server) gives it. Dev and prod run with the **same** PATH, so it works on every server.

> ⚠️ Don't write only `PATH=/usr/local/bin`: that **replaces** the whole PATH with one folder, and normal commands like `find`, `tar`, `rm` stop working. Always include `/usr/bin:/bin` too.

**Short answer to say in the interview:** "My cron job worked on dev but failed on prod with command not found. Cron runs with a minimal PATH, and only dev had `/usr/local/bin` added to it. I fixed it by using the full path to the command, `/usr/local/bin/archive`, and by setting the full PATH explicitly at the top of the script: `PATH=/usr/bin:/bin:/usr/local/bin`. Now the script runs the same on every server."

**2. We have Prometheus and other monitoring tools. Why write monitoring shell scripts?**

On **legacy** and **high-security servers** (like banking), installing external tools is often not allowed; only the commands already on the server can be run. Shell scripting is **native** (bash, `df`, `free`, `awk` are already there), so a script can monitor disk/CPU/RAM and send alerts there. No tool promises 100% automation; shell scripts fill those gaps and are also used in CI/CD pipelines.

**3. How do you send an alert when disk usage is above 80%?**

Read `df -hT` (without the header) line by line in a `while read` loop. For each line, take the Use% (column 6) with `awk`, remove `%` with `cut`, and compare with `-ge 80`. Add every high partition to a message, and if the message isn't empty, send it by email (`mail.sh` → HTML template → `msmtp`). Schedule it with cron.

## Other Questions

**1. Why do we delete old log files?**

Apps write logs all the time, so log files keep growing. If nobody cleans them, the disk fills up and the app or server can fail. Deleting logs older than N days is routine daily maintenance.

**2. How do you find `.log` files older than 14 days?**

`find /var/log/roboshop -type f -name "*.log" -mtime +14`

**3. What is the difference between `-mtime +14`, `-mtime -14` and `-mtime 14`?**

`+14` = modified more than 14 days ago, `-14` = less than 14 days ago, `14` = exactly 14 days ago.

**4. What do you check before deleting anything in the script?**

That the user passed a folder (`[ -z "$source_dir" ]` → print usage), and that the folder exists (`[ ! -d "$source_dir" ]`). If either check fails, print a message and `exit 1`, so the script never runs `rm` on a wrong path.

**5. How do you test a cleanup script without waiting 14 days?**

Create files with old dates using `touch -d 20260101 cart.log`.

**6. How do you check if a variable is empty in bash?**

`[ -z "$VAR" ]` is true when it's empty. In the script: if `find` returned nothing, print "no files found" and exit.

**7. Why not hard-code `/var/log/roboshop` and `14` in the script?**

Taking them as arguments (`$1`, `$2`) makes the same script work for any folder and any number of days.

**8. `find -delete` vs a loop with `rm`?**

`-delete` is shorter. A loop lets you print each file name before deleting it, so the user sees what was removed.

**9. How do you run the cleanup every day automatically?**

With cron: `0 2 * * * bash /home/ec2-user/cleanup.sh /var/log/roboshop 14` runs it every day at 02:00.

**10. What tool does Linux already have for this?**

`logrotate`: it rotates, compresses and deletes old logs based on a config file in `/etc/logrotate.d/`.

**11. What is the difference between `<` and `<<<`?**

`<` gives a **file** as input (`done < files.txt`); `<<<` gives a **variable** as input (`done <<< "$files_to_delete"`).

**12. Why quote variables, e.g. `rm -f "$file"`?**

Without quotes, bash splits the value at spaces. `rm -f my app.log` deletes `my` and `app.log`, not `my app.log`, so it can delete the wrong file.

**13. What does `${2:-14}` mean?**

Use the 2nd argument; if it's empty, use `14` as the default.

**14. What is crontab and when do cron jobs usually run?**

crontab schedules scripts to run automatically in Linux. Maintenance jobs (cleanup, backup) usually run at low-traffic times like 2 AM.

**15. What do the 5 fields in `0 2 * * *` mean?**

minute, hour, day of month, month, day of week → every day at 02:00. `* * * * *` = every minute.

**16. A script works in the terminal but fails in cron. Why?**

Cron runs with a minimal environment: its PATH is only `/usr/bin:/bin`, so commands in `/usr/local/bin` (like `aws`) aren't found. Fix: full paths, or set `PATH=` in the crontab or the script. Also save output with `>> file.log 2>&1` to see the error.

**17. The same cron job works on dev but fails on prod. What do you check?**

The cron environment, especially PATH. On dev, cron's PATH had `/usr/local/bin`; on prod it didn't, so the command wasn't found.

**18. How do you back up logs safely before deleting them?**

Compress them into another folder (`tar -czf $dest/logs-$(date +%Y-%m-%d-%H-%M-%S).tar.gz ...`), check tar's exit code, and delete the originals only if it's `0`. If tar fails, keep the files.

**19. `&&` vs `||` in an if condition?**

`&&` is true only if both sides are true; `||` is true if either side is true. To check that two required arguments are both given, use `[ -z "$src" ] || [ -z "$dest" ]` → error if either is missing.

**20. Why avoid `:` in a tar archive name?**

tar treats `name:path` as `host:path` (a remote archive) and fails with "Cannot connect". Use `-` in timestamps.

**21. In cron, why do both `0` and `7` mean Sunday?**

Cron supports two ways of counting the week: Sunday-first (Sunday = 0, old Unix/C style) and Monday-first (Sunday = 7, ISO style). Monday to Saturday are 1 to 6 either way, so cron accepts both numbers for Sunday. You can also write `SUN`.

**22. Can you create your own Linux command with shell scripting? How?**

Yes. Commands like `ls` are just files in PATH folders. Copy the script into a folder in `$PATH`, usually `/usr/local/bin` (`sudo cp cleanup.sh /usr/local/bin/cleanup`), make it executable (`chmod +x`), and keep the `#!/bin/bash` shebang. Then `cleanup /var/log/roboshop 14` works from any folder. Check with `which cleanup`.

**23. Why `/usr/local/bin` and not `/usr/bin`?**

`/usr/bin` is for commands installed by the package manager (`dnf`), which can overwrite files there. `/usr/local/bin` is for your own scripts and is available to all users.

**24. How do you run a daily maintenance script on all your servers?**

Make the script a command (`/usr/local/bin/archive`, `chmod +x`), schedule it with crontab using the full path (`0 2 * * * /usr/local/bin/archive /var/log/roboshop/ /var/log/logs-archive/`), and bake both into the **AMI**. Every server launched from that AMI then has the command and the cron job.

**25. What is an AMI and why put scripts in it?**

An AMI is a saved image of a server's disk; new EC2 instances start from it. Putting common scripts and cron jobs in the AMI means every new server has them automatically, with the same version everywhere and nothing to set up by hand.

**26. If you change the script after creating the AMI, do servers get the new version?**

No. An AMI is a snapshot of the disk at that moment. Servers already running and old AMIs keep the old script. Create a new AMI version and launch new servers from it (or push the change to running servers).

**27. What is a golden AMI?**

One base image with all the common company setup (scripts like cleanup/archive, cron jobs, monitoring agents, security settings). Every server is launched from it, so all servers start the same.

**28. What does `df -hT` show?**

Every partition's filesystem, type, size, used, available, Use% and mount point. `-h` = human-readable sizes, `-T` = filesystem type.

**29. Why `grep -v Filesystem`?**

To remove the header line of `df`; `-v` shows every line that does **not** match.

**30. Why `cut -d "%" -f1` before comparing?**

`-ge` compares numbers only. `cut` splits `80%` at `%` and keeps the first part, `80`.

**31. What does `message+=` do?**

Appends to the variable instead of overwriting it, so every high partition ends up in one email.

**32. What is `169.254.169.254`?**

The EC2 instance metadata address. A server can ask it for its own private IP, instance ID, region etc. On IMDSv2 you first get a token with a `PUT` request and send it as a header.

**33. Why is mail.sh a separate script?**

Reusability: disk, CPU and RAM scripts all call the same `mail.sh` with different arguments (team, IP, alert type, message, to, subject).

**34. How does mail.sh fill the email template?**

`sed -e "s/TO_TEAM/$team_name/g" -e ... template.html` replaces each placeholder with a real value. The message is escaped first (`/` → `\/`) because `/` is sed's separator.

**35. What is msmtp?**

A small command-line SMTP client. It sends the email built by the script through an SMTP server like Gmail (configured in the global `/etc/msmtprc` with a Gmail **app password**; 2-Step Verification must be on).

**36. Why `Content-Type: text/html` and an empty `echo ""`?**

`text/html` tells the mail client the body is HTML (so `<br>`, `<b>` work). The empty line separates the email headers from the body.

**37. How do you avoid empty or false alerts?**

Send only if the message isn't empty (`[ -n "$message" ]`), skip small system filesystems (`df -x tmpfs -x devtmpfs`), and use a realistic threshold like 75–80%.

**38. How would you monitor RAM and CPU the same way?**

RAM: `free | awk '/Mem:/ {printf "%d", $3/$2*100}'` = used %. CPU: 100 − idle % from `top -bn1`. Compare with the threshold and call the same `mail.sh`.

**39. Why does `line=/dev/nvme0n1p3   xfs   424M ...` give `xfs: command not found`?**

Without quotes, bash ends the value at the first space (`line=/dev/nvme0n1p3`) and runs the next word, `xfs`, as a command. Put the value in quotes: `line="/dev/nvme0n1p3   xfs   424M ..."`.

**40. How do you get the Use% number from one `df -hT` line?**

`echo $line | awk '{print $6}' | cut -d "%" -f1`: awk takes column 6 (`81%`), cut removes the `%` (`81`).

**41. Why send alert emails as HTML instead of plain text?**

HTML makes the alert easy to read: the alert type can be bold and colored, the server IP stands out, and `<br>` puts each problem on its own line. The script sends `Content-Type: text/html` so the mail client renders it.
