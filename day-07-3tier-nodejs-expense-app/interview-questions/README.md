# Day 7 - Interview Questions

[← Back to Day 7 notes](../README.md)

**1. Explain how you deployed a 3-tier application.**

I built an expense app on 3 EC2 servers. **DB**: installed MySQL, set the root password. **Backend**: installed Node.js, created a system user, downloaded the code to `/app`, ran `npm install`, created a systemd service with the DB details, loaded the schema. **Frontend**: installed Nginx, deployed the web files and configured a reverse proxy for `/api/` to the backend. Servers talk over private IPs, and security groups allow only 80 from the internet, 8080 from frontend and 3306 from backend.

**2. Why run an application as a system user, not root or a human user?**

Instead of running applications on servers with human credentials, we use a system user to limit the blast radius and follow least privilege. It has no password, no login and no shell (`/sbin/nologin`), the app doesn't break when an employee leaves, and audit logs clearly show what the app did.

**3. If a system user can't log in, how does the app run?**

systemd starts it. The service file has `User=expense`, so `systemctl start backend` runs the app as the `expense` user. Nobody needs to log in, and the app gets only that user's permissions.

**4. Which user do you use to set up the app - root, ec2-user or the system user?**

Log in as `ec2-user`, then `sudo su -` to become root. All setup is done as root (installing packages, `useradd`, creating `/app`, `npm install`, writing the service file), because a normal user can't change the system - e.g. `mkdir /app` as ec2-user gives `Permission denied`. The app itself runs as the `expense` system user through systemd (`User=expense`), so the running app never has root power.

**5. What is a systemd service file? Where is it stored?**

A config file that tells Linux how to run an app as a service - who runs it (`User`), how (`ExecStart`), settings (`Environment`), and restart behaviour. Custom ones go in `/etc/systemd/system/<name>.service`.

**6. Why run `systemctl daemon-reload`?**

systemd caches service files. After creating or editing one, `daemon-reload` makes it read the changes.

**7. What does `Restart=on-failure` do?**

Automatically restarts the app if it crashes (after `RestartSec` seconds).

**8. What is a build tool? Give examples.**

Automates downloading dependencies, compiling, testing and packaging into an artifact. Java → Maven (`pom.xml`), Node.js → npm (`package.json`), Python → pip (`requirements.txt`).

**9. What is an artifact?**

The packaged, ready-to-deploy output of a build - `.jar`, `.war`, `.zip`, `.tar.gz`.

**10. `package.json` vs `package-lock.json` vs `node_modules`?**

`package.json` is the build file - app name, version, description, start scripts and dependencies. `npm install` reads it. `package-lock.json` lists every dependency, including the dependencies of dependencies, with exact versions. `node_modules/` holds the downloaded dependencies.

**11. What is a reverse proxy? Why use Nginx for it?**

A server that receives client requests and forwards them to backend servers. Nginx serves the frontend and forwards `/api/` to the backend, so the backend is never exposed to the internet.

**12. Public IP vs private IP? Why use private IP between servers?**

Public IP is reachable from the internet and changes on stop/start. Private IP works only inside the VPC and doesn't change. Server-to-server traffic uses private IPs - more secure, faster, no data charges.

**13. How do you secure a 3-tier app with security groups?**

Frontend: 80/443 from `0.0.0.0/0`. Backend: 8080 only from frontend SG. DB: 3306 only from backend SG. SSH 22 only from my IP.

**14. `mysql-server` vs `mysql` package?**

`mysql-server` is the database server (on the DB machine). `mysql` is the client used to connect to it (on the backend machine).

**15. Why do you load the DB schema, and why from the backend server? Where is the table created?**

The app needs a table to store expenses, and the table structure (schema) comes from the application team in `/app/schema/backend.sql`. We load it from the backend because the file comes with the backend code, and it also tests the same connection the app will use (DB IP, port 3306, login). The `mysql` client on the backend only sends the SQL - the database, table and user are created on the **DB server**.

**16. What does `IF NOT EXISTS` do in the schema file?**

Creates the database/table/user only if it's missing. If it already exists, it's skipped with no error and existing data is safe, so the file can be run again safely.

**17. Why use `dnf module`?**

RHEL offers several versions of software like Node.js as modules. `dnf module disable` / `enable nodejs:24` installs the exact version the app needs.

**18. The page loads but shows no data. How do you debug?**

Check backend status and logs (`systemctl status backend`, `journalctl -u backend`), test `curl http://localhost:8080/health`, check backend IP in Nginx config, check DB connectivity from backend (`mysql -h <db-ip>`), and check SG ports 8080 and 3306.

**19. How do you validate Nginx config before restarting?**

`nginx -t`.

**20. Forward proxy vs reverse proxy?**

A forward proxy works for the client and hides the client from the server (VPN, office filtering). A reverse proxy works for the server and hides the server from the client (SSL termination, caching, load balancing) - like our Nginx forwarding `/api/` to the backend.

**21. Why does Nginx add `X-Forwarded-For` / `X-Real-IP` headers?**

Behind a proxy the backend sees every request coming from Nginx's IP. These headers carry the real client IP and protocol so the backend and its logs still know who made the request.

**22. How does Nginx load balance? What's the default method?**

An `upstream` block lists a group of servers and `proxy_pass` sends traffic to that group. Default is round-robin - requests go to each server in turn, so one server failing doesn't take the app down.

**23. Explain REST API methods and these status codes: 201, 204, 401 vs 403, 405, 502, 503, 504.**

GET reads, POST creates, PUT updates, DELETE deletes. 201 = created, 204 = success with no content (e.g. delete), 401 = not logged in / bad credentials, 403 = logged in but not allowed, 405 = method not allowed on that URL, 502 = proxy can't reach the backend, 503 = service unavailable (e.g. DB down), 504 = backend too slow.

**24. What steps do you follow to deploy a backend application? Does it change per language?**

1) Install the language/runtime, 2) create `/app`, 3) create a system user, 4) download the app `.tar.gz` into `/tmp`, 5) extract into `/app`, 6) install dependencies, 7) create the systemd service file, 8) load the DB schema, 9) start the app. The structure is the same for every language - only the runtime, build tool, build file and extension change (Node.js: npm / `package.json` / `.js`, Java: Maven / `pom.xml` / `.java`, Python: pip / `requirements.txt` / `.py`).

**25. Why install the `mysql` package on the backend server?**

It's the MySQL **client**, not the server. The backend uses it to connect to the DB server (`mysql -h <db-ip> -u root -p`) and load the schema file, which creates the database, table and app DB user on the DB server.

**26. Do we still need heavy application servers like WebLogic or JBoss?**

Mostly no. Modern apps come with a built-in lightweight server - Spring Boot (embedded Tomcat/Jetty), Node.js (`http`/Express), Go (`net/http`), .NET (Kestrel) - so the app just runs and listens on a port. Nginx sits in front as the web server / reverse proxy. Our backend runs as `node /app/index.js` on port 8080 with no separate app server.
