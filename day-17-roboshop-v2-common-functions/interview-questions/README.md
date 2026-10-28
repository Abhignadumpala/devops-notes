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
