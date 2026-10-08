# Day 9 - Interview Questions

[← Back to Day 9 notes](../README.md)

**1. What is DNS and why do we need it?**

DNS (Domain Name System) translates domain names into IP addresses. Computers route traffic only by IP, but people remember names - DNS bridges the two.

**2. What is a TLD? Give examples.**

The Top-Level Domain is the last part of a domain name: `.com`, `.in`, `.org`, `.net`, `.online`, `.ai`.

**3. Registry vs registrar?**

The registry is the record-keeper for one TLD (Verisign for `.com`, NIXI for `.in`) and doesn't sell to the public. The registrar (GoDaddy, Namecheap, Route 53) is the retailer you buy the domain from.

**4. What are root servers?**

The top of the DNS hierarchy - 13 well-known root server addresses, served from many locations worldwide. They tell a lookup which registry manages a TLD (e.g. who manages `.com`).

**5. What is ICANN?**

An independent nonprofit that oversees the whole naming system - the root zone, TLD policy and accredited registrars. Not a government body; fully independent of U.S. government oversight since 2016.

**6. What happens when you buy a domain?**

The registrar checks availability with the registry, takes your details and payment, registers the domain and tells the registry which nameservers manage it. Lookups then go root servers → TLD registry → your nameservers → IP.

**7. Explain the common DNS record types.**

A = domain → IPv4, AAAA = domain → IPv6, CNAME = alias to another domain, NS = which nameservers manage the domain, MX = mail server, TXT = text for verification / SPF / DKIM.

**8. A record vs CNAME?**

An A record points a name directly to an IP address. A CNAME points a name to another name (e.g. `www.mydevops.online → mydevops.online`), which then resolves to the IP.

**9. How do you point a domain bought elsewhere to AWS Route 53?**

Create a hosted zone in Route 53, copy its nameservers, update the NS records at the registrar to those nameservers, then add an A record in Route 53 pointing the domain to the server's public IP.

**10. I changed the A record but the site still goes to the old server. Why?**

DNS caching - resolvers keep the old answer until its TTL expires, so changes take time to propagate. The domain is only a pointer; changing it doesn't move the server.

**11. What happens step by step when you type a domain in the browser?**

First the browser cache is checked, then the OS cache, then the ISP DNS resolver cache. If the IP isn't cached anywhere, the ISP DNS resolver asks a root server, which points to the TLD registry (for example `.com`). The TLD doesn't know the IP but says which nameservers manage the domain. The resolver asks those nameservers, gets the IP, and the browser connects to it.

**12. Who manages `.com`, `.in` and `.ai`?**

`.com`: Verisign. `.in`: the Indian government (run by NIXI). `.ai`: the government of Anguilla, since it's Anguilla's country-code TLD, so `.ai` sales bring revenue to Anguilla.

**13. What happens if the root servers go down? Who runs them?**

New DNS lookups can't start, so domain names stop working once caches expire ("no root servers, no internet"). There are 13 root servers (A to M) run by 12 organizations. Many are in the US, such as Verisign, NASA, the US Department of Defense and the US Army Research Lab, and others are in Sweden, the Netherlands and Japan. Each one has many copies around the world, so they rarely go down.

**14. What is TTL in DNS?**

Time to Live - how long a resolver can cache a DNS record before asking the nameservers again. High TTL = faster lookups but slow changes; low TTL = changes spread fast but more lookups hit the nameservers.

**15. You're moving a domain to a new server IP. How do you avoid users hitting the old IP?**

Lower the TTL (e.g. to 1 minute) a day or two before the change and wait for the old TTL to expire. Then change the A record, verify the new server, and raise the TTL back to normal.

**16. What is an SOA record?**

Start of Authority - metadata for the domain's zone: which nameserver is the primary source of truth, plus settings like default TTL.

**17. Which registrar would you choose - GoDaddy or Hostinger?**

Depends on how long you'll keep the domain. Check the renewal price, not just the first year. GoDaddy usually costs more up front, so it suits a long-term (permanent) domain. Hostinger is cheap in year one but renewals cost more, so it suits a short-term / practice domain.

**18. What is a DNS propagation failure?**

You change a domain's IP in the hosted zone, but resolvers still have the old IP cached until the TTL expires (up to 1 day). Users keep hitting the old server. Avoid it by lowering the TTL to 1 min at least 2 days before the change, then raising it back after.

**19. Why buy a domain at Hostinger but manage DNS in AWS Route 53?**

Buying in AWS is costly, so we buy at Hostinger. EC2 public IPs change when instances restart or are recreated, and Route 53 makes the A record easy to update (even automatically). Steps: create a hosted zone with the same domain name, copy its NS records to Hostinger, and Hostinger updates the TLD within 24 hours.

**20. After moving DNS to Route 53, who manages what?**

Hostinger keeps the registration and renewal. Route 53 manages the nameservers and records (A, MX...). Email MX records live in Route 53 but point to Google's mail servers.

**21. What is negative caching in DNS?**

Resolvers also cache "not found" (NXDOMAIN) answers, for the time set in the zone's SOA record (900s in Route 53). If a server looks up a name before you create it, it keeps getting "not found" for up to 15 minutes. Create records before anything queries them.

**22. A record vs CNAME?**

A maps a name to an IPv4 address (`frontend-1` → `172.31.2.206`). CNAME maps a name to another name (`www` → `abhignadevops.store`), so `www` follows the root automatically when its IP changes.

**23. Why use private IPs in Route 53 records for backend and DB?**

Only servers inside the VPC talk to them, and private IPs don't change on stop/start. Only the server users open (the load balancer) gets a record with a public IP.

**24. You changed a DNS record, Route 53 shows the new IP, but your browser still opens the old site. Why?**

A cache along the way still has the old answer - browser, OS, home router or ISP resolver - until its TTL runs out. Check with `dig @8.8.8.8` vs `dig @<your-resolver>`, and `curl` vs the browser, to find which layer.

**25. Nginx uses `backend.example.com` in `proxy_pass`. The backend's IP changes and you update DNS. Does Nginx follow?**

Not by itself - Nginx resolves names only when it starts or reloads. Run `systemctl reload nginx` after changing the record.
