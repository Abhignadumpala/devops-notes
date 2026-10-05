# Day 8 - Interview Questions

[← Back to Day 8 notes](../README.md)

**1. Why is Nginx so popular?**

One tool does many jobs: HTTP server, load balancer, reverse proxy, SSL termination and caching server. It's also lightweight and handles a lot of connections.

**2. Where are Nginx's default HTML folder, config and logs?**

HTML: `/usr/share/nginx/html`. Config: `/etc/nginx/nginx.conf` (extra files in `/etc/nginx/default.d/`). Logs: `/var/log/nginx/access.log` and `error.log`.

**3. Forward proxy vs reverse proxy?**

A forward proxy works for the client and hides the client (VPN, geo change, office filtering). A reverse proxy works for the server and hides the server (SSL termination, cache, load balancing).

**4. Why do we set `X-Real-IP` and `X-Forwarded-For` in the proxy config?**

Behind a proxy the backend sees every request coming from Nginx's IP. These headers pass the real client IP along so the backend logs show who actually made the request.

**5. What does the trailing `/` in `proxy_pass http://<backend-ip>:8080/;` do?**

It strips the matched `/api/` prefix, so `/api/transaction` reaches the backend as `/transaction`.

**6. What is a load balancer?**

It sits in front of many servers, checks which are healthy and how busy they are, and spreads incoming requests across them - like a team lead assigning work to available members.

**7. What is an API?**

Application Programming Interface - the way one program talks to another. Here the frontend calls the backend's API and gets JSON back.

**8. Map CRUD to HTTP methods.**

Create → `POST`, Read → `GET`, Update → `PUT`, Delete → `DELETE`.

**9. What do the status code ranges mean?**

1XX info, 2XX success, 3XX redirection, 4XX client-side error, 5XX server-side error.

**10. 401 vs 403?**

`401` = no/wrong credentials sent - "who are you?" (e.g. DELETE all without the admin token). `403` = credentials sent, but not allowed - "I know who you are, but you can\'t do this".

**11. 502 vs 503 vs 504?**

`502 Bad Gateway` - Nginx can't connect to the backend (backend down/unreachable). `503 Service Unavailable` - service can't work right now (e.g. DB down). `504 Gateway Timeout` - backend is reachable but didn't respond in time.

**12. A POST body has `descrition` instead of `description`. Which status code range do you expect?**

4XX (e.g. `400 Bad Request`) - the mistake is in what the client sent, not on the server.

**13. Why put Nginx config in `/etc/nginx/default.d/expense.conf` instead of editing `nginx.conf`?**

Same idea as `/etc/sudoers.d/` vs `/etc/sudoers`: never edit the main default file. A separate file keeps the main config untouched, keeps mistakes isolated to our own file, keeps all our changes in one place, and survives package updates. `nginx.conf` loads it automatically with `include /etc/nginx/default.d/*.conf;`.

**14. Where do you change Nginx's default port number?**

The default comes from `listen 80;` in the `server` block of `/etc/nginx/nginx.conf`. The safe way is not to edit the main file: add your own `server { listen <port>; ... }` in a new file under `/etc/nginx/conf.d/`, then `nginx -t` and `systemctl restart nginx`.

**15. How can you quickly check Nginx is running?**

Open `http://<frontend-ip>/` - if the default page (`/usr/share/nginx/html/index.html`) loads, Nginx is up. On the server: `systemctl status nginx`.

**16. Why don't users type port numbers in URLs?**

The browser uses the default port when none is given - 80 for `http`, 443 for `https`. Servers listen on these defaults, so users only type the domain. A non-default port (like 81) must be typed in the URL.

**17. What can you find in the Nginx access log vs error log?**

`access.log` - every request: client IP, timestamp, method + path, status code, size, browser. `error.log` - failures. Use `tail -f` to watch either live.

**18. Where is the Nginx access log format defined?**

In `/etc/nginx/nginx.conf` inside the `http { }` block: `log_format main '...'` defines the format with variables like `$remote_addr`, `$time_local`, `$request`, `$status`, `$http_user_agent`, and `access_log /var/log/nginx/access.log main;` tells Nginx to use it.

**19. Difference between forward proxy, reverse proxy and load balancer?**

Forward proxy sits on the client side and hides the client (VPN, office proxy). Reverse proxy sits on the server side, hides the server and forwards requests to it (Nginx in front of the backend). A load balancer is a reverse proxy that spreads requests across many servers. Every load balancer is a reverse proxy, but not every reverse proxy is a load balancer.

**20. What is SSL/TLS termination?**

HTTPS traffic stays encrypted over the internet and is decrypted at the reverse proxy (Nginx), which holds the certificate. From there it travels unencrypted inside the private network to the backend. Only the proxy manages certificates, and the backend saves the CPU work of decrypting.

**21. What happens without a load balancer at peak hours?**

All requests hit the same server. CPU and RAM usage goes up, responses get slow, and the server can go down. A load balancer spreads the requests across many servers and stops sending to unhealthy ones.

**22. Public LB vs private (internal) LB?**

The public LB sits before the frontend, has a public IP, and users reach it from the internet. The private LB sits before the backend (and DB) servers, has only a private IP, and only our own servers can reach it. That keeps the backend and DB hidden from the internet.

**23. Why is Nginx called a reverse proxy server?**

It sits in front of our servers, receives every request, and forwards it to the right server behind it, while hiding those servers. It also does SSL termination, caching and load balancing, which is why it's the most popular reverse proxy.

**24. What do you run after changing Nginx config?**

`nginx -t` to check the syntax, then `systemctl restart nginx` to apply the change.

**25. How does an API request travel in a 3-tier app?**

Browser → frontend `/api/transaction` → Nginx forwards it to `http://<backend-private-ip>:8080/transaction` → backend saves or reads the data in the DB → response goes back the same way (for example `201 Created`).

**26. How do you check the backend is healthy?**

`curl http://<backend-ip>:8080/health` should return `{"status":"ok","db":"up"}`.

**27. Why can't you test POST or DELETE from the browser address bar? What do you use instead?**

The address bar only sends GET requests. Use an API testing tool such as Postman, HTTPie or curl to choose the method, add a JSON body and see the status code.

**28. You stop MySQL and open the app. What status code do you expect, and why?**

503 Service Unavailable. The backend is running, but the DB it depends on is down, so it can't serve the request.

**29. What do 301, 304 and 405 mean?**

301: moved permanently, so the browser goes to the new location automatically. 304: not modified, so the browser uses its cached copy. 405: method not allowed, meaning the URL exists but doesn't accept that method.

**30. When does Nginx return 504 Gateway Timeout? What's the default wait time?**

When the backend doesn't reply within `proxy_read_timeout`. The default is 60 seconds; our `expense.conf` sets it to `30s`. `proxy_connect_timeout` limits how long Nginx tries to connect (default 60s, ours `5s`).

**31. The app shows an error. How do you troubleshoot?**

Check the logs first, step by step. Nginx `access.log` shows the status code. `journalctl -u backend` shows the real error. `systemctl status backend`, `ps -ef | grep node` and `netstat -lntp` confirm the backend is running and listening. `curl http://localhost:8080/health` confirms the backend can reach the DB.

**32. Backend logs show `Access denied for user 'expense'`. What's wrong and how do you fix it?**

The backend can't log in to MySQL because the DB credentials are wrong. Correct `DB_USER` / `DB_PWD` / `DB_HOST` in `/etc/systemd/system/backend.service`, then run `systemctl daemon-reload` and `systemctl restart backend`.

**33. Why `systemctl daemon-reload` before restarting?**

The service file changed. `daemon-reload` makes systemd re-read the unit files, otherwise the restart would use the old settings.

**34. Is a 3XX code an error?**

No, it's a redirect: something changed, so go to the new location. For example, `/transactions` → `/transaction` or `/home` → `/` with 301. 304 means the content hasn't changed, so the browser uses its cached copy.

**35. The error says `Access denied for user 'expense'@'<backend-ip>' (using password: YES)`. Is it a network problem?**

No. The backend reached MySQL and MySQL answered, so the network and port 3306 are fine. The login was refused: wrong password, or the user only exists as `'expense'@'localhost'` and not for the backend's host. Test with `mysql -h <mysql-ip> -u expense -p` from the backend, check `SELECT user, host FROM mysql.user;`, and fix with `'expense'@'%'`.

**36. Do you need `daemon-reload` after installing MySQL and running `systemctl enable/start mysqld`?**

No. The package installs its own service file and systemd already knows it. `daemon-reload` is only needed when you create or edit a service file yourself, like `backend.service`.

**37. `ERROR 2003 Can't connect to MySQL server (110)`. What's wrong?**

`110` means connection timed out, so the backend can't reach MySQL at all. It's a network problem, not a password problem. Check the MySQL security group allows 3306 from the backend, the IP is the MySQL private IP, and `mysqld` is running. `111` (connection refused) means the server was reached but MySQL isn't listening.

**38. You launched a new backend from an AMI and now the DB connection times out. Why?**

The new instance got a new private IP, but the MySQL security group still allows 3306 only from the old backend IP. Update the inbound rule, or better, use the backend security group ID as the source. Also check old IPs copied by the AMI in `backend.service` (`DB_HOST`) and `expense.conf` (`proxy_pass`).
