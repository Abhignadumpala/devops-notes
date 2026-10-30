# Day 18 - Interview Questions

[← Back to Day 18 notes](../README.md)

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
