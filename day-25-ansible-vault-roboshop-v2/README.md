# Day 25 - Ansible Vault: Encrypting RoboShop V2 Secrets

[← All notes](../README.md)

> **In short:** in RoboShop V1 the passwords (SSH, MySQL root, shipping DB, RabbitMQ) sat in `group_vars/all.yaml`, and most of them were **plain text in a public Git repo**. **Ansible Vault** encrypts them with **AES256**, so the file in Git is unreadable without the **vault password**. In V2, `group_vars/all` becomes a **folder** with two files: `main.yaml` (plain, safe to read) and `vault.yaml` (fully encrypted). `main.yaml` only points to the secrets: `ansible_password: "{{ vault_ansible_password }}"`. We give Ansible the vault password at run time with `--ask-vault-pass` or with a **password file** set in `ansible.cfg`. That file stays on the Ansible server and is **never pushed**.

## About this class

| Part | Topic | What you learn |
|---|---|---|
| **Part 1: Concepts** | What Vault is · whole file vs one value · the `vault_` pattern · `group_vars/all/` as a folder · how to give the vault password · what goes to Git | What each piece is and why we need it |
| **Part 2: Lab** | Practice the vault commands · move every RoboShop V2 secret into `vault.yaml` · see the error without a password · run with `--ask-vault-pass` · run with a password file · push only encrypted data | Do it on the real Ansible server with the V2 roles |

**Before this:** [Day 24 - Background Jobs (nohup), Ansible Tags, Python venv & Ansible Roles](../day-24-nohup-tags-venv-ansible-roles/README.md)

**V1 project (inline vault for the SSH password only):** [roboshop-with-ansible-v1 LAB.md, Step 19](https://github.com/Abhignadumpala/roboshop-with-ansible-v1/blob/main/LAB.md#step-19-encrypt-the-ssh-password-with-ansible-vault)

## Table of Contents

**Part 1: Concepts**
1. [The problem: passwords in Git](#1-the-problem-passwords-in-git)
2. [What is Ansible Vault?](#2-what-is-ansible-vault)
3. [The vault commands](#3-the-vault-commands)
4. [Whole file vs one value (encrypt_string)](#4-whole-file-vs-one-value-encrypt_string)
5. [The vault_ pattern: main.yaml points, vault.yaml holds](#5-the-vault_-pattern-mainyaml-points-vaultyaml-holds)
6. [group_vars/all as a folder](#6-group_varsall-as-a-folder)
7. [Giving Ansible the vault password](#7-giving-ansible-the-vault-password)
8. [What goes to Git and what never does](#8-what-goes-to-git-and-what-never-does)

**Part 2: Lab**
- [Lab setup](#lab-setup)
- [Step 1: Practice the vault commands on a test file](#step-1-practice-the-vault-commands-on-a-test-file)
- [Step 2: Turn group_vars/all.yaml into a folder](#step-2-turn-group_varsallyaml-into-a-folder)
- [Step 3: Create the encrypted vault.yaml](#step-3-create-the-encrypted-vaultyaml)
- [Step 4: Point main.yaml to the vault variables](#step-4-point-mainyaml-to-the-vault-variables)
- [Step 5: Run without the vault password (see the error)](#step-5-run-without-the-vault-password-see-the-error)
- [Step 6: Run with --ask-vault-pass](#step-6-run-with---ask-vault-pass)
- [Step 7: Use a vault password file in ansible.cfg](#step-7-use-a-vault-password-file-in-ansiblecfg)
- [Step 8: Run with no prompt](#step-8-run-with-no-prompt)
- [Step 9: Check that Git only has encrypted data, then push](#step-9-check-that-git-only-has-encrypted-data-then-push)
- [Step 10: Change a secret and the vault password](#step-10-change-a-secret-and-the-vault-password)

**Wrap-up**
- [Troubleshooting](#troubleshooting)
- [What I learned](#what-i-learned)
- [Interview questions](#interview-questions)

---

# Part 1: Concepts

## 1. The problem: passwords in Git

In V1, `group_vars/all.yaml` looked like this (only the SSH password was encrypted):

```yaml
ansible_user: ec2-user
ansible_password: !vault |        # encrypted ✅
          $ANSIBLE_VAULT;1.1;AES256
          3062...
mysql_root_password: <plain text> # ❌ anyone can read it on GitHub
shipping_db_password: <plain text>
rabbitmq_password: <plain text>
```

| Problem | Why it's bad |
|---|---|
| Passwords readable on GitHub | Anyone who opens the repo can log in to the databases |
| Git keeps **history** | Even if we delete the password later, old commits still show it |
| Secrets mixed with normal settings | Hard to see which values are secret |

**Rule:** a secret goes to Git **only encrypted**. The key that opens it **never** goes to Git.

## 2. What is Ansible Vault?

**Definition:** **Ansible Vault** = a tool built into Ansible that **encrypts** files or single values with **AES256** using a **vault password**. Ansible **decrypts them in memory** while a playbook runs, so the secret is never written back to disk in plain text.

```
 vault.yaml (plain)  ──ansible-vault encrypt + vault password──►  vault.yaml (encrypted, safe in Git)
                                                                        │
 ansible-playbook ... + vault password ──► decrypt in memory ──► tasks use the real values
```

An encrypted file always starts with this header:

```
$ANSIBLE_VAULT;1.1;AES256
6337393262636333623462373837...
```

| Part | Meaning |
|---|---|
| `$ANSIBLE_VAULT` | "This is a vault file" |
| `1.1` | Vault format version |
| `AES256` | The encryption algorithm |
| The long numbers | The encrypted data (hex) |

## 3. The vault commands

| Job | Command |
|---|---|
| Create a new encrypted file (opens vim) | `ansible-vault create vault.yaml` |
| Encrypt a file that already exists | `ansible-vault encrypt example.yaml` |
| Read it without changing it | `ansible-vault view example.yaml` |
| Edit it (decrypts → vim → encrypts again on save) | `ansible-vault edit example.yaml` |
| Turn it back into plain text | `ansible-vault decrypt example.yaml` |
| Change the vault password | `ansible-vault rekey example.yaml` |
| Encrypt one value only | `ansible-vault encrypt_string '<value>' --name '<var_name>'` |

> 💡 `view` and `edit` never leave a plain-text copy on disk. `decrypt` **does**, so don't commit after a `decrypt`.

## 4. Whole file vs one value (encrypt_string)

| | Whole file (`create` / `encrypt`) | One value (`encrypt_string`) |
|---|---|---|
| What's encrypted | Every line in the file | Only that variable |
| What Git shows | Only numbers | Variable names visible, values encrypted |
| Edit later | `ansible-vault edit vault.yaml` (easy) | Run `encrypt_string` again and paste the new block (slow) |
| Used in | **V2** (`group_vars/all/vault.yaml`) | **V1** (`ansible_password: !vault \|` in `all.yaml`) |
| Best for | Many secrets | One or two secrets |

## 5. The vault_ pattern: main.yaml points, vault.yaml holds

**Problem with a fully encrypted file:** you can't see **which variables exist** without decrypting it.

**Fix:** two files. The secret value lives only in the encrypted file under a `vault_` name. The normal file has the **real variable name** and points to it.

| File | Encrypted? | Example line |
|---|---|---|
| `group_vars/all/main.yaml` | ❌ no (anyone can read it) | `ansible_password: "{{ vault_ansible_password }}"` |
| `group_vars/all/vault.yaml` | ✅ yes | `vault_ansible_password: <real password>` |

```
 role task uses  mysql_root_password
                     │
 main.yaml:   mysql_root_password: "{{ vault_mysql_root_password }}"
                     │
 vault.yaml:  vault_mysql_root_password: <real password>   (encrypted)
```

| Why this is good | |
|---|---|
| Roles don't change | They still use `mysql_root_password`, same as V1 |
| Easy to search | `grep -r mysql_root_password` finds where it's set, without decrypting |
| Clear | Anything starting with `vault_` is a secret |

## 6. group_vars/all as a folder

**Definition:** `group_vars/<group>` can be **a file** (`all.yaml`) **or a folder** (`all/`). When it's a folder, Ansible loads **every YAML file inside it** for that group.

| V1 | V2 |
|---|---|
| `group_vars/all.yaml` (one file, mixed) | `group_vars/all/main.yaml` + `group_vars/all/vault.yaml` |

```
roboshop-with-ansible-v2/
├── ansible.cfg
├── inventory.ini
├── main.yaml                 ← - hosts: "{{ component }}"  roles: "{{ component }}"
├── group_vars/
│   └── all/
│       ├── main.yaml         ← plain: DNS names + pointers to vault_ variables
│       └── vault.yaml        ← encrypted: every password
└── roles/
    ├── mongodb/ ...
    └── mysql/   ...
```

> ⚠️ Don't keep **both** `group_vars/all.yaml` and `group_vars/all/`. Move the file into the folder, so each variable is set in one place only.

## 7. Giving Ansible the vault password

| Way | How | When to use |
|---|---|---|
| Ask every time | `ansible-playbook main.yaml -e "component=mongodb" --ask-vault-pass` | Learning, running by hand |
| Password file on the command line | `--vault-password-file ~/.ansible_random` | One-off runs, scripts |
| Password file in `ansible.cfg` | `vault_password_file = ~/.ansible_random` under `[defaults]` | Daily work: no prompt, no extra flags |
| Vault IDs (many passwords) | `--vault-id dev@prompt --vault-id prod@~/.vault_prod` | Different passwords for dev and prod |

**The password file:**
- One line: the vault password, nothing else.
- Lives in the **home folder**, **outside** the repo, so `git add .` can't pick it up.
- `chmod 600` (only you can read it).
- ⚠️ It must **not** be executable. If the file is executable, Ansible **runs it as a script** and uses its output as the password.

## 8. What goes to Git and what never does

| File | Push to Git? |
|---|---|
| `group_vars/all/main.yaml` (pointers) | ✅ yes |
| `group_vars/all/vault.yaml` (encrypted) | ✅ yes, it's only numbers without the password |
| `ansible.cfg` with `vault_password_file = ~/.ansible_random` | ✅ yes (it only has the **path**, not the password) |
| `~/.ansible_random` (the vault password) | ❌ **never** |
| SSH private keys, `.pem` files | ❌ **never** |
| A file after `ansible-vault decrypt` | ❌ never. Encrypt it again first |

---

# Part 2: Lab

## Lab setup

| What | Details |
|---|---|
| **Ansible server** | The RHEL 9 Ansible server from the RoboShop labs |
| **Project** | `~/roboshop-with-ansible-v2` (RoboShop with roles, run with `main.yaml -e "component=<name>"`) |
| **Targets** | The RoboShop servers created by `roboshop.yaml` (start with `mongodb`) |
| **Passwords in this note** | Shown as `<placeholders>`. Type your real values only inside `ansible-vault` |

```bash
cd ~/roboshop-with-ansible-v2
ansible --version
```

**Expected:** the version prints, and `config file = /home/ec2-user/roboshop-with-ansible-v2/ansible.cfg` ✅.

---

## Step 1: Practice the vault commands on a test file

📍 **Where:** Ansible server, home folder (not the repo, so nothing gets pushed by mistake)

```bash
cd ~
vim example.yaml
```

```yaml
ansible_user: ec2-user
ansible_password: <test-password>
```

```bash
ansible-vault encrypt example.yaml     # set a vault password (twice)
cat example.yaml                       # only numbers now
ansible-vault view example.yaml        # asks the vault password, shows plain text
ansible-vault edit example.yaml        # opens vim; save → encrypted again
ansible-vault rekey example.yaml       # old password, then new password twice
ansible-vault decrypt example.yaml     # back to plain text
cat example.yaml
rm example.yaml
```

| Command | Expected |
|---|---|
| `encrypt` | `Encryption successful` |
| `cat` after encrypt | First line `$ANSIBLE_VAULT;1.1;AES256` + numbers ✅ |
| `view` | `Vault password:` then the 2 plain lines |
| `rekey` | `Rekey successful` |
| `decrypt` | `Decryption successful` |

Also try one value:

```bash
ansible-vault encrypt_string '<test-password>' --name 'db_password'
```

**Expected:** `db_password: !vault |` followed by the encrypted block (this is the V1 style).

---

## Step 2: Turn group_vars/all.yaml into a folder

📍 **Where:** Ansible server, repo folder

```bash
cd ~/roboshop-with-ansible-v2
mkdir -p group_vars/all
git mv group_vars/all.yaml group_vars/all/main.yaml
ls group_vars/all
```

**Expected:** `main.yaml` ✅. (If there's no `all.yaml` yet, just create `group_vars/all/main.yaml` in Step 4.)

`git mv` keeps the file's history and stages the move.

---

## Step 3: Create the encrypted vault.yaml

```bash
ansible-vault create group_vars/all/vault.yaml
```

It asks `New Vault password:` and `Confirm New Vault password:`, then opens vim. Type **every** secret with a `vault_` name:

```yaml
vault_ansible_user: ec2-user
vault_ansible_password: <ssh-password>
vault_mysql_root_password: <mysql-root-password>
vault_shipping_db_password: <shipping-db-password>
vault_rabbitmq_password: <rabbitmq-password>
```

Save with `:wq`.

```bash
cat group_vars/all/vault.yaml
```

**Expected:** first line `$ANSIBLE_VAULT;1.1;AES256`, then only numbers ✅. Remember this vault password; you need it in every next step.

### Write code on the laptop? Copy the encrypted text into the repo

In my case, I write the code in VS Code on my laptop and push from there, but the vault password lives only on the Ansible server. So I create `vault.yaml` **on the server**, then copy its **encrypted** text into the laptop repo:

```
 Ansible server                               Laptop (VS Code)               GitHub
 ansible-vault create vault.yaml   ──copy──►  paste into                ──push──►  vault.yaml
 cat vault.yaml (encrypted text)              group_vars/all/vault.yaml          (encrypted only)
```

| # | Where | Do this |
|---|---|---|
| 1 | Ansible server | `ansible-vault create group_vars/all/vault.yaml`: type the real secrets, `:wq` |
| 2 | Ansible server | `cat group_vars/all/vault.yaml`: copy **everything**, from `$ANSIBLE_VAULT;1.1;AES256` to the last line |
| 3 | Laptop | Paste it into `group_vars/all/vault.yaml` in the repo, save |
| 4 | Laptop | `git add`, `git commit`, `git push` |
| 5 | Ansible server | `git pull`. The file is the same encrypted text, and the vault password on the server opens it |

**Why this is safe:** only the **encrypted** text goes to GitHub. The real passwords and the vault password never leave the Ansible server.

> ⚠️ Copy the whole block exactly: the header line plus every number line, with no extra spaces. If one character is missing, Ansible fails with `Decryption failed`.

---

## Step 4: Point main.yaml to the vault variables

```bash
vim group_vars/all/main.yaml
```

Delete every real password and the old inline `!vault` block. Keep the same variable names the roles use, and point them to the vault:

```yaml
ansible_user: "{{ vault_ansible_user }}"
ansible_password: "{{ vault_ansible_password }}"

mongodb_host: mongodb.abhignadevops.store
redis_host: redis.abhignadevops.store
mysql_host: mysql.abhignadevops.store
rabbitmq_host: rabbitmq.abhignadevops.store
catalogue_host: catalogue.abhignadevops.store
user_host: user.abhignadevops.store
cart_host: cart.abhignadevops.store
shipping_host: shipping.abhignadevops.store
payment_host: payment.abhignadevops.store

mysql_root_password: "{{ vault_mysql_root_password }}"
shipping_db_user: shipping
shipping_db_password: "{{ vault_shipping_db_password }}"
rabbitmq_user: roboshop
rabbitmq_password: "{{ vault_rabbitmq_password }}"
```

| Line | Meaning |
|---|---|
| `"{{ vault_ansible_password }}"` | Quotes are **required**: a YAML value that starts with `{` must be quoted |
| Same names as V1 | The roles don't change at all |
| No password anywhere in this file | Safe to read and push |

Check nothing secret is left:

```bash
grep -rn "password" group_vars/
```

**Expected:** in `main.yaml`, every `password` line ends with `{{ vault_... }}`. `vault.yaml` shows nothing readable ✅.

---

## Step 5: Run without the vault password (see the error)

```bash
ansible-playbook main.yaml -e "component=mongodb"
```

**Expected (error on purpose):**

```
ERROR! Attempting to decrypt but no vault secrets found
```

**Why:** Ansible loads `group_vars/all/vault.yaml`, sees the `$ANSIBLE_VAULT` header, and has no password to open it.

---

## Step 6: Run with --ask-vault-pass

```bash
ansible-playbook main.yaml -e "component=mongodb" --ask-vault-pass
```

**Expected:** `Vault password:` prompt → type it → the play runs → recap `failed=0` ✅.

Ansible decrypted `vault.yaml` in memory, so `ansible_password` became the real SSH password.

---

## Step 7: Use a vault password file in ansible.cfg

Typing the password every run is slow. Store it in a file **outside** the repo:

```bash
vim ~/.ansible_random          # one line: the vault password
chmod 600 ~/.ansible_random
ls -l ~/.ansible_random
```

**Expected:** `-rw-------` (read/write for you only, **no `x`**) ✅.

Add the path to `ansible.cfg`:

```bash
vim ansible.cfg
```

```ini
[defaults]
stdout_callback=yaml
inventory=inventory.ini
vault_password_file = ~/.ansible_random
```

> ⚠️ Check the path carefully: one dot, `~/.ansible_random`. A typo like `~/..ansible_random` points to a file that doesn't exist, and the run fails.

---

## Step 8: Run with no prompt

```bash
ansible-playbook main.yaml -e "component=mongodb"
```

**Expected:** no `Vault password:` prompt, the play runs, `failed=0` ✅.

Run one more component that uses a vault secret, to prove it reaches the role:

```bash
ansible-playbook main.yaml -e "component=mysql"
```

**Expected:** MySQL is configured with the root password from the vault, `failed=0` ✅.

---

## Step 9: Check that Git only has encrypted data, then push

```bash
git status
git diff --cached group_vars/
head -1 group_vars/all/vault.yaml
git ls-files | grep -i ansible_random
```

| Check | Expected |
|---|---|
| `git status` | `main.yaml` (moved/modified), `vault.yaml` (new), `ansible.cfg` (modified) |
| `head -1 vault.yaml` | `$ANSIBLE_VAULT;1.1;AES256` ✅ |
| `git ls-files \| grep ansible_random` | **No output** (the password file isn't in the repo) ✅ |

```bash
git add group_vars/ ansible.cfg
git commit -m "Move all secrets to an encrypted vault.yaml"
git push
```

Open the repo on GitHub → `group_vars/all/vault.yaml` shows only numbers ✅.

> 💡 The V1 repo still has plain passwords in its **Git history**. Encrypting in V2 doesn't remove them from V1. In real work you would **change those passwords** (rotate them), because anything ever pushed counts as leaked.

---

## Step 10: Change a secret and the vault password

```bash
ansible-vault edit group_vars/all/vault.yaml     # change a value, :wq
ansible-vault rekey group_vars/all/vault.yaml    # new vault password
vim ~/.ansible_random                            # put the new vault password here too
ansible-playbook main.yaml -e "component=mongodb"
```

**Expected:** `Rekey successful`, and the playbook still runs with no prompt ✅. If you forget to update `~/.ansible_random`, you get `Decryption failed`.

---

# Wrap-up

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Attempting to decrypt but no vault secrets found` | A vault file was loaded, but no password was given | Add `--ask-vault-pass`, or set `vault_password_file` in `ansible.cfg` |
| `Decryption failed (no vault secrets were found that could decrypt)` | Wrong vault password (or the file was rekeyed) | Use the right password; update `~/.ansible_random` after a `rekey` |
| `The vault password file ... was not found` | Wrong path in `ansible.cfg` (e.g. `~/..ansible_random`) | Fix the path, check with `ls -l ~/.ansible_random` |
| `'vault_ansible_password' is undefined` | Name in `main.yaml` doesn't match `vault.yaml`, or `vault.yaml` isn't inside `group_vars/all/` | `ansible-vault view` and compare names; check the folder |
| Ansible tries to **run** the password file | The file is executable | `chmod 600 ~/.ansible_random` |
| YAML error near `{{ vault_... }}` | Value not in quotes | Write `"{{ vault_xyz }}"` |
| Password visible in `-v` output | A task prints the variable | Add `no_log: true` to tasks that use secrets |
| `ERROR! input is already encrypted` | Ran `encrypt` on a vault file | It's already done; use `edit` |

## What I learned

**Part 1: Concepts**
- **Ansible Vault** encrypts files or values with **AES256**; Ansible decrypts them in memory at run time.
- Encrypted file header: `$ANSIBLE_VAULT;1.1;AES256`.
- **Whole file** (`create`/`encrypt`) for many secrets (V2); **`encrypt_string`** for one value (V1).
- **`vault_` pattern:** `main.yaml` has `x: "{{ vault_x }}"`, `vault.yaml` has the real `vault_x`. Roles don't change.
- **`group_vars/all/`** can be a folder; Ansible loads every file inside.
- Password: `--ask-vault-pass` (prompt) or `vault_password_file` in `ansible.cfg` (no prompt). The file is outside the repo, `chmod 600`, not executable.
- Git gets the **encrypted file**; the **vault password never**.

**Part 2: Lab**
- Practised `encrypt`, `view`, `edit`, `rekey`, `decrypt`, `encrypt_string` on a test file.
- Moved every RoboShop secret (SSH, MySQL root, shipping DB, RabbitMQ) into `group_vars/all/vault.yaml`.
- Saw `no vault secrets found` without a password, ran with `--ask-vault-pass`, then with no prompt using `~/.ansible_random`.
- Checked Git has only `$ANSIBLE_VAULT` data and no password file before pushing.

```
 V1: group_vars/all.yaml   (1 value encrypted inline, the rest plain text ❌)
                │
 V2: group_vars/all/main.yaml   → x: "{{ vault_x }}"     (plain, pushed)
     group_vars/all/vault.yaml  → vault_x: <secret>      (AES256, pushed)
     ~/.ansible_random          → vault password          (never pushed)
                │
     ansible-playbook main.yaml -e "component=mysql"   (ansible.cfg finds the password file)
```

## Interview questions

### ⭐ Very Important

| Question | Answer |
|---|---|
| How do you store passwords securely in Ansible? | Encrypt them with **Ansible Vault** (`ansible-vault create`/`encrypt`). The encrypted file can go to Git; the vault password is given at run time with `--ask-vault-pass` or a password file that is never committed |
| How does Ansible get the vault password in a pipeline (no one to type it)? | A password file (`--vault-password-file` or `vault_password_file` in `ansible.cfg`) written at run time from a CI secret or AWS Secrets Manager / SSM, never stored in the repo |

### Other Questions

| Question | Answer |
|---|---|
| Which algorithm does Vault use? | AES256 |
| `encrypt` vs `encrypt_string`? | `encrypt` encrypts a whole file; `encrypt_string` encrypts one value you paste into a normal vars file |
| `view` vs `decrypt`? | `view` shows the plain text without changing the file; `decrypt` writes plain text back to disk |
| How do you change the vault password? | `ansible-vault rekey <file>` |
| Why use `vault_` prefixed variables? | So the normal vars file shows which variables exist (`x: "{{ vault_x }}"`) without decrypting, and roles keep using the normal names |
| What does "Attempting to decrypt but no vault secrets found" mean? | A vault-encrypted file was loaded but no vault password was supplied |
| How do you stop a secret from showing in the output? | `no_log: true` on the task |
| What are vault IDs? | Labels for different vault passwords, e.g. `--vault-id dev@prompt --vault-id prod@~/.vault_prod`, so dev and prod use different passwords |
| Can a vault password file be a script? | Yes. If it's executable, Ansible runs it and uses its output (e.g. to read the password from a secrets manager) |
| You pushed a plain password by mistake. Is deleting it enough? | No. It stays in Git history. Rotate the password, then clean the history if needed |
| Vault vs AWS Secrets Manager / SSM Parameter Store? | Vault keeps encrypted secrets **in the repo**; Secrets Manager / SSM keep them **in AWS**, read at run time with a lookup, with IAM access control and rotation |

---

**Source:** [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) · [Encrypting content](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html) · [Using encrypted variables and files](https://docs.ansible.com/ansible/latest/vault_guide/vault_using_encrypted_content.html) · [Organizing host and group variables](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
