# Day 17 - Interview Questions

[← Back to Day 17 notes](../README.md)

**1. Why did you move shared code into `common.sh`?**

In v1 every script repeated the root check, logging, `validate` and colors. Keeping them once in `common.sh` makes each script short, and a fix is made in one file instead of ten (DRY: Don't Repeat Yourself).

**2. What does `source` do? How is it different from `bash file.sh`?**

`source` runs the file inside the current shell, so its variables and functions stay available to my script. `bash file.sh` runs it in a separate process; nothing it defines comes back.

**3. Why can `source ./common.sh` fail?**

`./` is the folder I'm in when I run the command, not the script's folder. Run from another folder and it isn't found. `scripts_dir=$(dirname "$(realpath "$0")")` + `source "$scripts_dir/common.sh"` works from anywhere.

**4. A script runs `cp mongo.repo ...` and fails on the server, but works on your laptop. Why?**

The server only has what's in the repo it cloned. If `mongo.repo` wasn't committed and pushed, it isn't there. Every file a script uses must be in the repo.

**5. `git push -u origin main` vs `git push`?**

`-u` links my local `main` to `origin/main` the first time. After that, plain `git push` and `git pull` know where to go.

**6. Why do servers only `git pull`, never push?**

All changes are made on my laptop and pushed to GitHub, so GitHub is the single source of truth and no server holds changes that aren't in Git.

**7. What does `ss -lntp` show vs `ss -tnp`?**

`ss -lntp` shows listening ports: `0.0.0.0:6379` means open to the network, `127.0.0.1:6379` means only local. `ss -tnp` shows established connections and the caller's IP.

**8. Redis listens on `0.0.0.0:6379`. Can anyone reach it?**

No. Listening is one layer; the security group is the other. `roboshop-redis` allows 6379 only from the user and cart security groups, so only those servers get through.

**9. Stop vs terminate an EC2 instance?**

Stop keeps the server, its disk and private IP (I pay only for the disk); the public IP changes on start. Terminate deletes it.

**10. Your script printed `cp: cannot stat 'rabbitmq.repo'` and stopped. What does it mean and how do you fix it?**

`cp` couldn't find the source file. I check `pwd` and `ls`; here the file was never committed. I add it on my laptop, push, `git pull` on the server and run again. I fix it in Git, not only on the server, so every new server gets it.

**11. How does your `validate` function work?**

I pass it `$?` and a step name. If `$?` isn't 0 it prints FAILED, logs it and runs `exit 1`, so the script stops at the first failure. Otherwise it prints SUCCESS and the script continues.

**12. Why stop a script at the first failure?**

The first error is the real cause. If the script carries on, every later step fails too (no repo → install fails → service not found), and the real error gets buried.

**13. What is `$?`?**

The exit status of the last command: 0 = success, anything else = failure. It changes after every command, so I read it immediately (`validate $? "..."`).

**14. What does idempotent mean? Give an example from your scripts.**

Running the script again gives the same result without new errors. Before `rabbitmqctl add_user roboshop` I check `rabbitmqctl list_users | grep -qw roboshop`; if the user exists I print SKIPPING.

**15. `systemctl status mysql` says the unit could not be found, but MySQL works. Why?**

On RHEL the service is `mysqld`; `mysql` is the client. I find real names with `systemctl list-units --type=service | grep -i mysql`.

**16. A Java app's systemd service is `active (running)` but the port isn't listening. How do you debug it?**

Spring Boot opens the port only after startup finishes, so the app is stuck. I read `journalctl -u <app> -n 30` and go to the last `Caused by:`. In my case it was a TLS error connecting to MySQL, so the DB pool never started.

**17. You fixed a TLS problem with `MAVEN_OPTS`, but the app still fails with the same error. Why?**

`MAVEN_OPTS` is only read by Maven. The running app is a separate Java process started by systemd, so the option must go in the service file's `ExecStart`, before `-jar`.

**18. What does `ERROR 1129: Host is blocked because of many connection errors` mean and how do you fix it?**

MySQL counts failed connections per IP; after `max_connect_errors` (100) it blocks that host. I stop the failing app, fix the cause, and clear the block on the DB server with `TRUNCATE TABLE performance_schema.host_cache;` (or `mysqladmin flush-hosts`).

**19. `mysql -uroot -p` says Access denied on the DB server, but the app logs in as root from another server. How?**

MySQL accounts are user + host. `root@localhost` and `root@'%'` are separate accounts with separate passwords; here local root had no password, so `mysql -uroot` worked.
