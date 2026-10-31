# Day 19 - Interview Questions

[← Back to Day 19 notes](../README.md)

## Other Questions

**1. What are the disadvantages of shell scripts?**

No idempotency, no built-in error handling, imperative (commands must run in order), can't handle scale (many servers), homogeneous (works only on one distro, e.g. `dnf` vs `apt`), and can't store secrets securely.

**2. What is idempotency?**

Running the same thing many times gives the same result as running it once. Ansible modules are idempotent: if nginx is already installed, the task reports `ok` and changes nothing.

**3. Imperative vs declarative?**

Imperative = you write how to do it, step by step (shell). Declarative = you write what final state you want (`state=installed`) and the tool works out how (Ansible, Terraform).

**4. What is configuration management?**

Tools that set up servers and keep them in the desired state (packages, users, files, services) automatically and consistently, e.g. Ansible, Chef, Puppet.

**5. What does "configuring a server" mean?**

Turning a plain server into one ready to host an app: install the language, create the system user and app directory, download and unzip the code, install dependencies, create the systemd service, load data if needed, and start it.

**6. Push vs pull configuration management?**

Push: the control server sends changes to servers when you run it (Ansible, over SSH, no agent). Pull: an agent on every server polls the master on a schedule (Chef, Puppet), which causes unnecessary traffic and wastes resources.

**7. Is Ansible agent-based?**

No. Ansible is agentless: it connects over SSH (WinRM for Windows) from the control server; the managed servers only need SSH and Python.

**8. What is non-interactive SSH?**

Running one command remotely without opening a shell: `ssh ec2-user@<ip> "touch /tmp/devops.txt"`. Ansible uses SSH this way.

**9. What is an inventory?**

The list of servers Ansible manages: inline (`-i 172.31.31.45,` — the trailing comma makes it a list) or an inventory file.

**10. What is an Ansible module?**

A ready-made unit of work, like a Linux command: `dnf`, `user`, `file`, `get_url`, `unarchive`, `service`. A collection is a package of modules.

**11. Ad-hoc command vs playbook?**

Ad-hoc: one-line command for an emergency or one-time simple task (`ansible all -i <ip>, -b -m dnf -a "name=nginx state=installed"`). Playbook: a YAML file with many tasks for repetitive work, run with `ansible-playbook`.

**12. What do `-i`, `-e`, `-b`, `-m`, `-a` mean in an ad-hoc command?**

`-i` inventory, `-e` extra variables (e.g. `ansible_user`), `-b` become root (sudo), `-m` module, `-a` module arguments.

**13. What is YAML and why does Ansible use it?**

YAML ("Yet Another Markup Language") is a simple key: value format that's easy for humans to read and write. Playbooks are YAML, so tasks are clear and can be kept in Git.

**14. YAML vs JSON vs XML vs HTML?**

YAML: configs (Ansible, Kubernetes). JSON: APIs and data exchange. XML: older configs/APIs (e.g. `pom.xml`). HTML: web pages and HTML emails.

**15. Why store data as key-value pairs?**

The key says what each value is, so the order doesn't matter, like a labeled form. Different systems can read the same data correctly.

**16. What is a DTO?**

A Data Transfer Object: an object used only to carry data between systems, often sent as JSON.
