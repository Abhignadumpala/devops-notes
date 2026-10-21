# Day 16 - Problems I Hit and Fixes

[← Back to Day 16 notes](README.md)

| # | Problem | Cause | Fix |
|---|---------|-------|-----|
| 1 | Old AMI `ami-0220d79f3f480ecf5` not found | The practice AMI was rebuilt; old ID deregistered | New `Redhat-9-DevOps-Practice` = `ami-0055977a6e828a4f4`. Check by name before using an ID |
| 2 | SG ID from class (`sg-043444d…`) not found | That ID belongs to the trainer's account | Use **my own** SGs, or SG **names** (`--security-groups`) |
| 3 | `sh roboshop.sh` printed nothing | No server names given → `$@` empty → loop ran 0 times | `bash roboshop.sh mongodb` |
| 4 | Variable printed empty | Bash names are case-sensitive: set `INSTANCE_ID`, used `$instance_id` | Use the same name everywhere |
| 5 | `r53_recod: command not found` (trainer's live code) | Spaces around `=` | `r53_record_name="..."`, no spaces |
| 6 | Route 53 got literal `$IP` (trainer's live code) | Variables don't expand inside single quotes | `"'$IP'"` (close the quote around the variable) |

**Find the latest AMI by name:**
```bash
aws ec2 describe-images --owners 973714476881 \
  --filters "Name=name,Values=Redhat-9-DevOps-Practice" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text
```

> Use `bash`, not `sh`: on Ubuntu, `sh` is **dash**, a smaller shell.
