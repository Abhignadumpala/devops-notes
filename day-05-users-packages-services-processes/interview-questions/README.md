# Day 5 - Interview Questions

[← Back to Day 5 notes](../README.md)

**1. How do you set up key-based login for a new user?**

User generates keys and sends the public key → admin creates the user → creates `/home/user/.ssh/authorized_keys` and pastes the key → `chown` to the user → `.ssh` 700, `authorized_keys` 600.

**2. Why must `.ssh` be 700 and `authorized_keys` 600?**

SSH refuses keys if other users could read or change them - it's a security check.

**3. An employee leaves the company. What do you do?**

Lock the account (`usermod -e 1`), kill sessions (`pkill -u`), remove from groups (`gpasswd -d`), back up home folder (`tar`), find other files (`find / -user`), then delete (`userdel`).

**4. How to find files by name, type, owner or size?**

`find / -name "*.log"`, `find / -type d -name app`, `find / -user ramesh`, `find / -size +100M`.

**5. `yum` vs `dnf` vs `apt`?**

`yum` - older RHEL. `dnf` - newer RHEL (yum now points to dnf). `apt` - Ubuntu/Debian.

**6. What is a service?**

A program that runs continuously in the background (daemon), e.g. `sshd`, `nginx`. Managed with `systemctl`.

**7. `systemctl start` vs `enable`?**

`start` runs it now. `enable` makes it start automatically on every boot. Usually do both.

**8. How do you check which ports are open or which process uses port 8080?**

`netstat -lntp` or `ss -lntp`; add `| grep 8080`.

**9. Common ports?**

SSH 22, SMTP 25, DNS 53, HTTP 80, HTTPS 443, MySQL 3306, Jenkins/backend apps 8080.

**10. What is a process, PID and PPID?**

A process is a running program. PID = its ID, PPID = the ID of the parent process that started it.

**11. How to see all running processes?**

`ps -ef` (filter with `| grep nginx`).

**12. Foreground vs background process?**

Foreground blocks the terminal until done. Background runs behind with `&` (`sleep 60 &`); see with `jobs`, bring back with `fg`.

**13. `kill` vs `kill -9`?**

`kill PID` asks the process to stop gracefully. `kill -9 PID` force-kills it immediately.

**14. Application is not accessible. How do you troubleshoot?**

Check service status → port listening → process running → security group allows the port → logs (`journalctl -u <service>`).
