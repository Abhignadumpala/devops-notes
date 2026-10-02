# Day 3 - Interview Questions

[← Back to Day 3 notes](../README.md)

**1. Absolute vs relative path?**

Absolute starts from root `/` and works from anywhere (`/home/ec2-user/app`). Relative starts from the current directory (`app`, `../logs`).

**2. Difference between `>` and `>>`?**

`>` overwrites the file, `>>` appends to the end.

**3. How do you see hidden files? Latest modified files?**

`ls -la` shows hidden files. `ls -ltr` sorts by time with the latest at the bottom.

**4. `cp` vs `mv`? How to rename a file?**

`cp` copies (original stays), `mv` moves (original is gone). Rename = `mv old.txt new.txt`. Use `-r` with `cp` for folders.

**5. `wget` vs `curl`?**

`wget` downloads and saves the file. `curl` prints the response on screen (save with `-o`); also used to test APIs.

**6. Important `grep` options?**

`-i` ignore case, `-n` line numbers, `-c` count, `-v` lines that don't match, `-r` search in a folder.

**7. How to print lines 5 to 13 of a file?**

`head -n 13 file | tail -n 9` or `sed -n '5,13p' file`.

**8. How to watch a log file live?**

`tail -f app.log`.

**9. What is a pipe `|`?**

Sends the output of one command as input to the next: `cat file | grep error`.

**10. `cut` vs `awk`?**

Both split text by a delimiter. `awk` can also print the last field (`$NF`) and filter with conditions (`$3 > 999`).

**11. How to list only normal (human) users?**

`awk -F: '$3 >= 1000 {print $1}' /etc/passwd`.

**12. What are the fields in `/etc/passwd`?**

`username:x:UID:GID:comment:home:shell` - `x` means the password is in `/etc/shadow`.

**13. UID ranges?**

0 = root, 1-999 = system users (for services), 1000+ = normal users.

**14. How to create and extract a `.tar.gz`?**

Create: `tar -czf backup.tar.gz files`. Extract: `tar -xzf backup.tar.gz`. List: `tar -tzf backup.tar.gz`.

**15. Vim modes? How to save and quit, or quit without saving?**

Normal (Esc), Insert (`i`), Command (`:`). `:wq` = save and quit, `:q!` = quit without saving.
