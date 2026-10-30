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

That the user passed a folder (`$#`), and that the folder exists (`[ -d "$DIR" ]`). If either check fails, print a message and `exit 1`, so the script never runs `rm` on a wrong path.

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
