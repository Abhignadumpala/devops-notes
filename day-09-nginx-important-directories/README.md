# Day 9 - Nginx Important Directories

## Table of Contents

1. [Why Know These Paths](#why-know-these-paths)
2. [The 4 Important Paths](#the-4-important-paths)
   - [/etc/nginx/nginx.conf - Main Configuration](#etcnginxnginxconf---main-configuration)
   - [/usr/share/nginx/html - HTML Directory](#usrsharenginxhtml---html-directory)
   - [/var/log/nginx - Logs Directory](#varlognginx---logs-directory)
   - [/etc/nginx/default.d/expense.conf - Our Custom Config](#etcnginxdefaultdexpenseconf---our-custom-config)
3. [Never Edit the Main Config - Use a Separate File](#never-edit-the-main-config---use-a-separate-file)
4. [Summary](#summary)
5. [Interview Questions](#interview-questions)

---

## Why Know These Paths

When Nginx is installed, it keeps its files in fixed places. Everything we do with Nginx - changing settings, putting our website, checking errors - happens in one of these 4 paths. If you know them, you can set up and troubleshoot Nginx on any server.

## The 4 Important Paths

| Path | What's there | We use it to |
|------|--------------|--------------|
| `/etc/nginx/nginx.conf` | Main Nginx configuration file | Check the default settings (port, root folder, log format) |
| `/usr/share/nginx/html` | Nginx HTML directory | Put our website files (HTML/CSS/JS) |
| `/var/log/nginx` | Nginx logs directory | See requests and errors |
| `/etc/nginx/default.d/expense.conf` | Our expense reverse proxy config | Add our own custom settings |

```text
/etc/nginx/
├── nginx.conf              ← main config (don't edit)
└── default.d/
    └── expense.conf        ← our custom config (edit here)

/usr/share/nginx/html/      ← website files (index.html ...)

/var/log/nginx/
├── access.log              ← every request
└── error.log               ← errors
```

### /etc/nginx/nginx.conf - Main Configuration

The **main** Nginx configuration file. Nginx reads it when it starts. It has the default settings, for example:

- `listen 80;` → which port Nginx listens on
- `root /usr/share/nginx/html;` → which folder the website files are served from
- `log_format` / `access_log` → how and where requests are logged
- `include /etc/nginx/default.d/*.conf;` → load our extra config files

We **read** this file to understand the setup, but we **don't edit** it.

### /usr/share/nginx/html - HTML Directory

The folder where the **website files** live. Whatever we put here, Nginx serves to the browser.

- After install it has the default Nginx test page (`index.html`).
- For our app, we delete the default content and extract our expense frontend files here.
- `http://<public-ip>/` → Nginx serves `/usr/share/nginx/html/index.html`.

### /var/log/nginx - Logs Directory

Where Nginx writes its **logs**:

| File | What's in it |
|------|--------------|
| `access.log` | Every request - client IP, time, URL, status code, browser |
| `error.log` | Errors - when something fails, the reason is here |

```bash
tail -f /var/log/nginx/access.log    # watch requests live
tail -f /var/log/nginx/error.log     # watch errors live
```

### /etc/nginx/default.d/expense.conf - Our Custom Config

Our **own** config file for the expense app. When we need **extra configuration**, we add it here. In our case, it has the **reverse proxy** settings - send every `/api/` request to the backend:

```nginx
location /api/ {
    proxy_pass http://<backend-private-ip>:8080/;
}
```

The main `nginx.conf` automatically loads every `.conf` file in `/etc/nginx/default.d/`, so we just create the file - no need to touch the main config.

## Never Edit the Main Config - Use a Separate File

If we need any **custom config**, we add it in a **separate file** (`/etc/nginx/default.d/<name>.conf`) - we **do not edit** the main `nginx.conf`.

Why:

- The **main configuration does not get disturbed** - the default setup keeps working.
- If our custom config has a mistake, we only fix or delete **our own file**.
- All our changes are in one place - easy to find, copy or remove.
- Package updates can replace the main file, but our file stays.

Same idea as sudo: we add a file in `/etc/sudoers.d/` instead of editing the main `/etc/sudoers`.

After adding or changing any config file:

```bash
nginx -t                     # check the syntax is correct
systemctl restart nginx      # apply the change
```

## Summary

- `/etc/nginx/nginx.conf` → main Nginx config (read it, don't edit it).
- `/usr/share/nginx/html` → website files Nginx serves.
- `/var/log/nginx` → `access.log` (requests) and `error.log` (errors).
- `/etc/nginx/default.d/expense.conf` → our custom reverse proxy config.
- Custom configs always go in a separate file, so the main config is never disturbed. Then `nginx -t` and `systemctl restart nginx`.

## Interview Questions

Quick revision questions for this day are in [interview-questions/README.md](interview-questions/README.md).
