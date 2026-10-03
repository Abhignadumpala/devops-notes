# Day 9 - Interview Questions

[← Back to Day 9 notes](../README.md)

**1. What are the important Nginx directories?**

`/etc/nginx/nginx.conf` (main config), `/usr/share/nginx/html` (website files), `/var/log/nginx` (logs), and `/etc/nginx/default.d/` (our custom config files).

**2. Where is the main Nginx configuration file?**

`/etc/nginx/nginx.conf`. It has the default settings like the listen port, root folder and log format.

**3. Where do you put the website files for Nginx?**

In `/usr/share/nginx/html`. Nginx serves `index.html` from there when you open `http://<public-ip>/`.

**4. Where are the Nginx logs, and what's in them?**

In `/var/log/nginx`. `access.log` has every request (IP, time, URL, status code, browser), and `error.log` has the errors.

**5. Where do you add custom Nginx config like a reverse proxy, and why not in `nginx.conf`?**

In a separate file such as `/etc/nginx/default.d/expense.conf`. The main config stays undisturbed, mistakes stay in our own file, and package updates don't overwrite it. `nginx.conf` loads it with `include /etc/nginx/default.d/*.conf;`.

**6. What do you run after changing Nginx config?**

`nginx -t` to check the syntax, then `systemctl restart nginx` to apply the change.

**7. How does an API request travel in a 3-tier app?**

Browser → frontend `/api/transaction` → Nginx forwards it to `http://<backend-private-ip>:8080/transaction` → backend saves or reads the data in the DB → response goes back the same way (for example `201 Created`).

**8. How do you check the backend is healthy?**

`curl http://<backend-ip>:8080/health` should return `{"status":"ok","db":"up"}`.

**9. Why can't you test POST or DELETE from the browser address bar? What do you use instead?**

The address bar only sends GET requests. Use an API testing tool such as Postman, HTTPie or curl to choose the method, add a JSON body and see the status code.

**10. 401 vs 403?**

401 Unauthorized means no credentials were sent (for example, no admin token). 403 Forbidden means credentials were sent but they're wrong or don't allow this action.

**11. You stop MySQL and open the app. What status code do you expect, and why?**

503 Service Unavailable. The backend is running, but the DB it depends on is down, so it can't serve the request.

**12. 502 vs 503 vs 504?**

502 Bad Gateway means Nginx can't connect to the backend (backend down). 503 Service Unavailable means the service can't work right now (for example, DB down). 504 Gateway Timeout means the backend is up but too slow to answer.

**13. What do 301, 304 and 405 mean?**

301: moved permanently, so the browser goes to the new location automatically. 304: not modified, so the browser uses its cached copy. 405: method not allowed, meaning the URL exists but doesn't accept that method.

**14. When does Nginx return 504 Gateway Timeout? What's the default wait time?**

When the backend doesn't reply within `proxy_read_timeout`. The default is 60 seconds; our `expense.conf` sets it to `30s`. `proxy_connect_timeout` limits how long Nginx tries to connect (default 60s, ours `5s`).
