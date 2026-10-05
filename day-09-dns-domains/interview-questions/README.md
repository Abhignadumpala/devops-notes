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
