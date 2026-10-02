# Day 7 - Troubleshooting

[← Back to Day 7 notes](../README.md)

Check from **frontend to database**, one tier at a time.

| # | Check | Command |
|---|-------|---------|
| 1 | Service running? | `systemctl status nginx` / `backend` / `mysqld` |
| 2 | Port listening? | `netstat -lntp` |
| 3 | Process running? | `ps -ef \| grep node` |
| 4 | Logs | `journalctl -u backend -f` / `/var/log/nginx/error.log` |
| 5 | Can backend reach DB? | `mysql -h <mysql-private-ip> -u root -p` |
| 6 | Can frontend reach backend? | `curl http://<backend-private-ip>:8080/health` |
| 7 | Security group allows the port? | AWS console |

## Common Mistakes

| Problem | Fix |
|---------|-----|
| Backend fails to start after editing the service file | `systemctl daemon-reload` |
| Backend can't connect to DB | Wrong `DB_HOST` IP, or DB security group missing 3306 |
| Page loads but no data | Wrong backend IP in `expense.conf`, or backend SG missing 8080 |
| Nginx won't restart | Run `nginx -t` to find the config error |
| Used public IP between servers | Use **private** IPs |
| `nginx -t` → `host not found in upstream "<backend-private-ip>"` | Placeholder not replaced. Put the real backend private IP in `proxy_pass` |
| `curl localhost/api/health` → **404** even though `expense.conf` is correct | Nginx wasn't restarted. `systemctl restart nginx` and check again |

## The Error Tells You the Layer

Run `curl http://localhost/api/health` on the frontend and read the result:

| You See | Problem Is At | Fix |
|---------|---------------|-----|
| **404 Not Found** (HTML page) | **Nginx** - no `/api/` rule loaded, so Nginx looks for a file `api/health` and doesn't find it | Check `/etc/nginx/default.d/expense.conf`, `nginx -t`, **restart nginx** |
| **502 Bad Gateway** | Backend app not running on 8080 | `systemctl status backend` on the backend |
| **504 Gateway Timeout** (after a delay) | Frontend → backend blocked, or wrong backend IP | `backend-sg` must allow 8080 from `frontend-sg` |
| `"db":"down"` | Backend → DB blocked, or wrong DB details | `mysql-sg` must allow 3306 from backend, check `DB_HOST` |
| `{"status":"ok"}` | Nothing - all working ✅ | |

> **Always restart after changing config.** Nginx reads its config only when it starts. Even if everything in `expense.conf` is written correctly, if you don't restart Nginx you'll still get **404 Page Not Found**. Restart and check again - the page works.
>
> ```bash
> nginx -t                  # check syntax first
> systemctl restart nginx   # load the new config
> curl http://localhost/api/health
> ```
>
> Same idea for the backend: after editing `backend.service` → `systemctl daemon-reload` + `systemctl restart backend`.
