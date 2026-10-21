# Day 16 - Interview Questions

[← Back to Day 16 notes](../README.md)

**1. What does `$?` hold?**

The exit code of the last command. `0` = success, anything else = failure.

**2. What does `$0` hold? And `$@`, `$#`?**

`$0` = the script's name. `$@` = all arguments. `$#` = the number of arguments.

**3. How do you check that a script runs as root?**

`id -u` returns `0` for root: `if [ $(id -u) -ne 0 ]; then echo "run with sudo"; exit 1; fi`.

**4. What does `&>>` do?**

Appends both normal output and errors to a file. `>>` appends only normal output; `&>` overwrites.

**5. What does `tee -a` do?**

Shows output on screen **and** appends it to a file at the same time.

**6. Why use a validate function?**

To check every step's exit code in one reusable place, print SUCCESS / FAILED, and stop at the first failure instead of continuing with a broken setup.

**7. Why don't variables work in `'...$IP...'`?**

Single quotes keep text literal. Use double quotes, or close the single quote around the variable: `'"Value": "'$IP'"'`.

**8. What is UPSERT in Route 53?**

Update the record if it exists, create it if it doesn't. Safe to run again and again.

**9. Why does frontend get a public IP record and others private?**

Users reach frontend from the internet. Backend servers talk to each other inside the VPC, so private IPs are enough and safer.

**10. What happens to IPs when an EC2 instance is stopped and started?**

The private IP stays the same; the public IP changes (unless it's an Elastic IP).

**11. Why attach a common SG to all instances?**

Shared rules (like SSH from my IP) live in one place. One change updates every server.

**12. What is `sed -i`?**

sed = Stream EDitor. `-i` = in-place: saves the change into the file. Without it, sed only prints the result.

**13. Where would you use Terraform and Ansible instead of these scripts?**

Terraform to create servers, SGs and DNS (`roboshop.sh`); Ansible to install and configure software (`01-mongodb.sh`).
