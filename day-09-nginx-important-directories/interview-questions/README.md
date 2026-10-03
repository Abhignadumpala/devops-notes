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
