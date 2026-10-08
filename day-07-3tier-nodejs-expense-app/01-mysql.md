# MySQL

## Server Login

| Item | Value |
|------|-------|
| Server name | `mysqldb` |
| AMI | `Redhat-9-DevOps-Practice` (`ami-0220d79f3f480ecf5`, us-east-1) |
| Username | `ec2-user` |
| Password | `DevOps321` |
| MySQL root password | `<db-root-password>` (user: `root`) |

```bash
ssh ec2-user@<mysqldb-public-ip>    # enter the password
sudo su -                         # become root
hostnamectl set-hostname mysqldb   # name the server, then: exec bash
```

MySQL is the database for this app. Here we install and configure it. The schema is loaded later **from the backend server**.

> **Set up this server FIRST** - order is DB → Backend → Frontend. The backend's schema load needs MySQL running with a root password.

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

Check it right away - this command prints nothing even when it works:

```bash
mysql -u root -p<db-root-password> -e "SELECT 1;"     # prints 1 ✅
```

> If this gives `Access denied for user 'root'@'localhost'`: `set-root-pass` set only `root@%` (remote) and left `root@localhost` (local) **empty**. Fix:
> ```bash
> mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '<db-root-password>';"
> ```
> The app never uses `root@localhost`, so this only matters when you log in on this server.

---

## Verification

The schema is loaded from the backend server (see [02-backend.md](02-backend.md)). After that, check it from either server:

| Where you are | Command | Why |
|---|---|---|
| **MySQL server** (mysqldb) | `mysql -u root -p` | No `-h` = MySQL on **this** server (local socket) |
| **Backend server** | `mysql -h <MYSQL-SERVER-IPADDRESS> -u root -p` | `-h` = MySQL on **another** server, over port 3306 |

> On the backend, `mysql -u root -p` **without `-h`** fails with `ERROR 2002 ... mysql.sock` - there's no MySQL server on the backend, only the client.

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

Use a separate SG for each tier - not one SG for all 3 servers.

| SG | Inbound | Source |
|---|---|---|
| `mysql-sg` | 3306 | `backend-sg` (not the internet) |
| `mysql-sg` | 22 | My IP |
