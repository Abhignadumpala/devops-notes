# Day 4 - Interview Questions

[← Back to Day 4 notes](../README.md)

**1. Authentication vs Authorization?**

Authentication = who are you (password/key). Authorization = what are you allowed to do (permissions/roles).

**2. What happens when you run `useradd ramesh`?**

Creates the user with a new UID, a group with the same name (primary group), an entry in `/etc/passwd`, `/etc/shadow` and `/etc/group`, and (on RHEL) a home folder `/home/ramesh`.

**3. Primary vs secondary group?**

Every user has exactly **one** primary group (owns new files the user creates) and **zero or more** secondary groups (give extra access).

**4. `usermod -g` vs `-G` vs `-aG`?**

`-g` sets the primary group. `-G` sets secondary groups and **removes** all others. `-aG` **appends** a secondary group and keeps existing ones - always use `-aG`.

**5. How to remove a user from a group?**

`gpasswd -d ramesh devops`.

**6. What does `chmod 751` mean?**

Owner `rwx` (7), group `r-x` (5), others `--x` (1). r=4, w=2, x=1.

**7. Common permissions - 644, 755, 600, 700?**

644 = files, 755 = scripts/folders, 600 = private files/SSH keys, 700 = private folders like `~/.ssh`.

**8. Who can change permissions and who can change ownership?**

Permissions (`chmod`) - the file owner or root. Ownership (`chown`) - only root.

**9. How do you give a user sudo access?**

Add to the `wheel` group (RHEL) / `sudo` group (Ubuntu): `usermod -aG wheel ramesh`. Or create `/etc/sudoers.d/ramesh` with `ramesh ALL=(ALL:ALL) ALL`.

**10. Why use `/etc/sudoers.d/` instead of editing `/etc/sudoers`?**

Main file stays untouched, access is easy to remove per user (delete one file), and it's easy to automate with tools like Ansible.

**11. How to allow a user to run only specific commands with sudo?**

`ramesh ALL=(ALL:ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/usermod` in `/etc/sudoers.d/ramesh`.

**12. How do you check sudoers and SSH config syntax?**

`visudo -c` for sudoers, `sshd -t` for SSH. Always check before restarting - a broken file can lock you out.

**13. How to enable password login over SSH?**

Set `PasswordAuthentication yes` in `/etc/ssh/sshd_config`, run `sshd -t`, then `systemctl restart sshd`.

**14. In vim, replace a word everywhere and delete lines 5-10?**

`:%s/old/new/g` and `:5,10d`.
