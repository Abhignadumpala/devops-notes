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

`401` = wrong/no credentials (we don't know who you are). `403` = we know who you are, but you're not allowed.

**11. 502 vs 504?**

`502 Bad Gateway` - Nginx can't connect to the backend (backend down/unreachable). `504 Gateway Timeout` - backend is reachable but didn't respond in time.

**12. A POST body has `descrition` instead of `description`. Which status code range do you expect?**

4XX (e.g. `400 Bad Request`) - the mistake is in what the client sent, not on the server.

**13. Why put Nginx config in `/etc/nginx/default.d/expense.conf` instead of editing `nginx.conf`?**

Same idea as `/etc/sudoers.d/` vs `/etc/sudoers`: never edit the main default file. A separate file keeps the main config untouched, keeps mistakes isolated to our own file, keeps all our changes in one place, and survives package updates. `nginx.conf` loads it automatically with `include /etc/nginx/default.d/*.conf;`.

**14. Where do you change Nginx's default port number?**

In `/etc/nginx/nginx.conf` - change `listen 80;` in the `server` block, then run `nginx -t` and `systemctl restart nginx`.

**15. How can you quickly check Nginx is running?**

Open `http://<public-ip>/` - if the default page (`/usr/share/nginx/html/index.html`) loads, Nginx is up. On the server: `systemctl status nginx`.

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
