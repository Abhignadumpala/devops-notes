# Day 14 - Interview Questions

[← Back to Day 14 notes](../README.md)

**1. Why use a shell script instead of running commands by hand?**

A script is a written, repeatable record of the steps. It runs the same way every time - faster, fewer human mistakes, and anyone can see exactly what was done.

**2. If we have scripts, why do we still need Git?**

A script file alone has no history, backup, versioning, review or collaboration. Git tracks who changed what and when, keeps old versions recoverable, and lets a team review changes (pull requests) before they go live.

**3. Git vs Google Drive vs an artifact repository (Nexus / Artifactory)?**

Git stores and versions source code. Google Drive is general file storage. An artifact repository stores build outputs (jars, packages, images), not source code.

**4. What makes a folder a Git repository?**

A hidden `.git` subfolder, created by `git init`. That's where Git keeps the full history.

**5. What is a shebang?**

The first line of a script, e.g. `#!/bin/bash`. It tells Linux which interpreter runs the file.

**6. `$@` vs `$#`?**

`$@` = all argument values. `$#` = how many arguments were passed.

**7. What is `$?` and what do 0, 126 and 127 mean?**

The exit status of the previous command. `0` = success, non-zero = failure; `127` = command not found, `126` = found but not executable.

**8. Does a shell script stop automatically when a command fails?**

No. It keeps running. Check `$?` after important commands (like a package install) and exit on failure.

**9. How do you make an environment variable permanent?**

`export` lasts only for the current session. Add it to `~/.bashrc` for one user (reload with `source ~/.bashrc`), or to a file in `/etc/profile.d/` for all users.

**10. What data types does shell have?**

None, really - shell treats everything as a string by default. The script writer must validate values before using them as numbers.

**11. Why quote variables, and does `"$DIR"` make `rm -rf "$DIR"/*` safe?**

Quotes stop a value with spaces from being split into several words (`rm "$FILE"`). They don't help an **empty** value: `DIR=""` still gives `rm -rf /*`. Use `"${DIR:?}"` so the script stops if it's empty.
