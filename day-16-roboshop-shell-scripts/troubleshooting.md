# Day 16 - Problems I Hit and Fixes

[← Back to Day 16 notes](README.md) · [Debugging guide](../roboshop-debugging-guide/README.md)

| # | Problem | Cause | Fix |
|---|---------|-------|-----|
| 1 | Old AMI `ami-0220d79f3f480ecf5` not found | The practice AMI was rebuilt; old ID deregistered | New `Redhat-9-DevOps-Practice` = `ami-0055977a6e828a4f4`. Check by name before using an ID |
| 2 | SG ID from class (`sg-043444d…`) not found | That ID belongs to the trainer's account | Use **my own** SGs, or SG **names** (`--security-groups`) |
| 3 | `sh roboshop.sh` printed nothing | No server names given → `$@` empty → loop ran 0 times | `bash roboshop.sh mongodb` |
| 4 | Variable printed empty | Bash names are case-sensitive: set `INSTANCE_ID`, used `$instance_id` | Use the same name everywhere |
| 5 | `r53_recod: command not found` (trainer's live code) | Spaces around `=` | `r53_record_name="..."`, no spaces |
| 6 | Route 53 got literal `$IP` (trainer's live code) | Variables don't expand inside single quotes | `"'$IP'"` (close the quote around the variable) |
| 7 | `ERROR 1045 Access denied for 'root'@'localhost'` after 03-mysql.sh said SUCCESS | `mysql_secure_installation --set-root-pass` set the password only on `root@'%'`; `root@localhost` stayed empty (proved with `authentication_string=''` in `mysql.user`) | `ALTER USER 'root'@'localhost' IDENTIFIED BY 'RoboShop@1';` + a login-check step in the script |
| 8 | `script completed in  seconds` (empty) | Used `$seconds`; the built-in is `$SECONDS` (case-sensitive) | `$SECONDS` |
| 9 | 2nd run of 04-rabbitmq.sh would fail at `add_user` | User already exists → non-zero exit → validate stops | Check first: `rabbitmqctl list_users \| grep -qw roboshop`, else SKIPPING |
| 10 | `sed: unterminated 's' command` | `"s/DOMAIN_NAME/$domain_name"`: missing the 3rd `/` | `"s/DOMAIN_NAME/$domain_name/"` |
| 11 | `cp catalogue.service` → No such file | Ran after `cd /app`; the file is in the script folder | `scripts_dir=$(dirname "$(realpath "$0")")` at the top, `cp $scripts_dir/catalogue.service ...` |
| 12 | `cp` still couldn't find `catalogue.service` | File was saved as `" catalogue.service"` (leading space in the name) | `mv " catalogue.service" catalogue.service` |
| 13 | Download step would fail | Long lines got cut off when pasted (`.../refs/he-v4.zip`, `$logs_f`) | Check line ends; `bash -n script.sh` for syntax; `curl -sI <url>` → 200 |
| 14 | Typing in VS Code deleted the next letters | Overtype mode (`OVR` in the status bar) | Press the **Insert** key |
| 15 | Script looked frozen at `dnf install` | Output goes to the log; dnf was refreshing repo metadata | `tail -f /var/log/roboshop/<script>.log` in a 2nd session |
| 16 | 2nd run of 05-catalogue.sh would load products twice | `master-data.js` runs every time | Count first with `countDocuments()`; load only if `0`, else SKIPPING |
| 17 | Re-run didn't pick up a changed service file | `systemctl start` does nothing on a running service | End with `systemctl restart catalogue` + `validate` |
| 18 | `cp`/`sed` would fail: "No such file" (06-user.sh) | Set as `script_dir`, used as `scripts_dir`: bash treats the typo as a new, **empty** variable → path `/user.service`. `bash -n` doesn't catch it | Same name everywhere; `grep -n "script_dir\|scripts_dir" *.sh` |
| 19 | After renaming to `scripts_dir`, catalogue would fail at `adding mongo repo` | One `cp $script_dir/mongo.repo` line was missed in the rename | `grep` the old name after every rename |
| 20 | `user.service` was empty on disk | Created in VS Code, never saved | `cat <file>` before `git add` |
| 21 | Wrong domain in `07-cart.sh` / `08-shipping.sh` | Started from a copy with another domain → `redis.<other-domain>` not in my Route 53 | `domain_name="abhignadevops.store"`; `grep -n domain_name= *.sh` |
| 22 | Server created, but `07-cart.sh` not on GitHub | Not committed yet (`git status`: modified + untracked) | `git add` → `commit` → `push`, `git status` clean, **then** clone on the server |
| 23 | `ssh` → `Permission denied (publickey,...,password)` | Password typed wrong (case-sensitive, nothing shows while typing) | Same AMI login on every server; type slowly |
| 24 | JAVA_HOME step always SUCCESS | `validate $?` checks the last command, `echo $JAVA_HOME`, which never fails | `[ -n "$JAVA_HOME" ]` right before `validate` |
| 25 | MySQL password warning printed between SUCCESS lines | `mysql ... < file.sql` had no redirect | `&>> $logs_file` |
| 26 | Payment (v4) can't use RHEL 9's `python3` | It's 3.9; gunicorn 26 needs ≥ 3.10 | `dnf install python3.14 python3.14-pip` + venv `/app/.venv` |
| 27 | Renamed `payment.sh` → `09-payment.sh`, old file stayed on GitHub | Plain `mv` + `git add 09-payment.sh`: the delete was never staged (`git status`: `deleted: payment.sh` not staged) | `git rm payment.sh` → commit → push. Use `git mv` to rename |
| 28 | `bash 09-payment.sh` → "Please run this script with sudo access.." | Ran it on my **laptop** | SSH to the payment server first. Never `sudo` an app script on the laptop |
| 29 | Nearly ran `roboshop.sh payment` twice | The server already existed | `describe-instances --filters Name=tag:Name,Values=roboshop-<name>` first; every run creates a **new** server |
| 30 | `dnf list ... \| grep -E 'python3\.1[0-9] '` printed nothing | Package names are `python3.12.x86_64` (dot after the version, not a space) | `grep -E '^python3\.1[0-9]\.'` |
| 31 | Payment `/health` → 503 `"rabbitmq":false` once, then `true` | Idle RabbitMQ connection had dropped; the health check resets it and answers `false` once | Check again before debugging. Stays `false` → check rabbitmq-server, `rabbitmqctl list_users`, SG 5672 |
| 32 | `10-frontend.sh` would fail at `cp roboshop.conf` | Script written, `roboshop.conf` not created yet | Write it next to the script, `git status` → both files pushed |
| 33 | `sed` on the repo `roboshop.conf`, then `cp` | Changes a tracked file → later `git pull` refuses | `cp` first, `sed` the copy |
| 34 | Classmate's run: `Value () for parameter groupId is invalid. The value cannot be empty`, then `Unknown options: 172.31.x.x, ...`, then "Updated R53 record" anyway | No `roboshop-rabbitmq` SG (SG **names** must exist in the default VPC, same region) → no instance → empty instance ID → `describe-instances` returned **all** IPs → unquoted `'$IP'` split in the JSON. No error check, so the script kept going | Create the SG (check: `aws ec2 describe-security-groups --group-names roboshop-common roboshop-rabbitmq`). In the script: `validate $?` after `run-instances`, `[ -z "$instance_id" ] && exit 1`, quote `"'"$IP"'"` |

**Find the latest AMI by name:**
```bash
aws ec2 describe-images --owners 973714476881 \
  --filters "Name=name,Values=Redhat-9-DevOps-Practice" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text
```

> Use `bash`, not `sh`: on Ubuntu, `sh` is **dash**, a smaller shell.
