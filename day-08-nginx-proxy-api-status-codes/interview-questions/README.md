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

**13. Two ways to give a user sudo access?**

Edit `/etc/sudoers` directly (with `visudo`), or drop an individual file into `/etc/sudoers.d/` - the second is cleaner to add/remove.
