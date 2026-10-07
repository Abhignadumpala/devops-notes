# MySQL

## Server Login

| Item | Value |
|------|-------|
| Server name | `mysqldb` |
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`, us-east-1) |
| Username | `ec2-user` |
| Password | `DevOps321` |

```bash
ssh ec2-user@<mysqldb-public-ip>    # enter the password
sudo su -                         # become root
hostnamectl set-hostname mysqldb   # name the server, then: exec bash
```

MySQL is the database for this app. We need to install, configure, and load the schema.

> **Check with the developer for the exact version required. This setup uses MySQL 8.0.x.**

---

## Install

```bash
dnf install mysql-server -y
```

## Configure

Enable and start the MySQL service:

```bash
systemctl enable mysqld
systemctl start mysqld
```

Set the root password (replace `<db-root-password>` with your own):

```bash
mysql_secure_installation --set-root-pass <db-root-password>
```

---

## Verification

The schema is loaded from the backend server (see [02-backend.md](02-backend.md)). After that, connect to MySQL from the same server:

```bash
mysql -u root -p
```

Connect remotely from another server:

```bash
mysql -h <MYSQL-SERVER-IPADDRESS> -u root -p
```

Check databases and tables:

```sql
SHOW DATABASES;
USE transactions;
SHOW TABLES;
DESCRIBE transactions;
SELECT * FROM transactions;
```

---

## Security Group

Ensure the DB EC2 security group allows **inbound TCP on port 3306** from the backend EC2's security group (not from the internet).
