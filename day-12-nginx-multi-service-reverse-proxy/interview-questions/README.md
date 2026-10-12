# Day 12 - Interview Questions

[← Back to Day 12 notes](../README.md)

**1. How does one Nginx route requests to many backend services?**

One `location` block per service, matched by path prefix - e.g. `/api/catalogue/` → catalogue IP, `/api/cart/` → cart IP.

**2. What does the trailing slash in `proxy_pass http://<ip>:8080/;` do?**

It strips the matched prefix. `/api/catalogue/products` is forwarded as `/products`. Without it, the service gets the full `/api/catalogue/products` path.

**3. Why set `X-Forwarded-For` and `X-Real-IP`?**

Behind a proxy, every request looks like it comes from Nginx. These headers pass the real client IP so service logs show who actually made the request.

**4. What is `X-Request-Id` used for?**

Nginx gives every request a unique ID and passes it to every service it touches and back to the browser - so one request can be traced across all service logs with one ID.

**5. What does `server_tokens off` do and why use it?**

Hides the Nginx version in responses and error pages, so attackers don't get a free hint about which known bugs to try.

**6. 502 vs 504 from Nginx?**

`502 Bad Gateway`: Nginx couldn't reach the service (down / wrong IP or port). `504 Gateway Timeout`: the service was reached but didn't answer within `proxy_read_timeout`.

**7. Why return JSON for Nginx's 502/504 errors?**

API clients expect JSON; Nginx's default HTML error page breaks their parsing. Errors the service returns itself are passed through untouched.

**8. What does `gzip` do, and why not for JPG/PNG?**

Compresses text responses (CSS, JS, JSON) to cut transfer time. JPG/PNG are already compressed, so gzip adds CPU cost for no gain.

**9. Why cache `/assets/` forever but `/images/` only for 1 hour?**

Asset filenames contain a content hash - new content means a new filename, so caching forever is safe. Images can change under the same name, so they get a short cache.

**10. Why `try_files $uri $uri/ /index.html` for a React app?**

React routes like `/cart` exist only in the browser, not as files on the server. Falling back to `index.html` lets React's router render the right page instead of Nginx returning `404`.
