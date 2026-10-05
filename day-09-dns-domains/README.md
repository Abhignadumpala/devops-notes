# Day 9 - DNS (Domain Name System): How Domain Names Actually Work

## Table of Contents

1. [What this is / why it matters](#what-this-is--why-it-matters)
2. [How it works](#how-it-works)
3. [How a DNS Lookup Works (Step by Step)](#how-a-dns-lookup-works-step-by-step)
4. [What happens when you buy a domain](#what-happens-when-you-buy-a-domain)
5. [DNS Record Types](#dns-record-types)
6. [TTL (Time to Live)](#ttl-time-to-live)
7. [Pointing a Domain at AWS (Route 53)](#pointing-a-domain-at-aws-route-53)
8. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
9. [Key takeaways](#key-takeaways)
10. [Interview Questions](#interview-questions)

---

## What this is / why it matters

**DNS = Domain Name System.**

- **Computers use only IP addresses.** They connect to servers by IP and have no idea what "facebook.com" means.
- **Humans remember only names.** Nobody can remember `104.104.56.87`, but everyone remembers `facebook.com`.

That's why we create **domain names**: humans type the name, and DNS converts it to the IP the computer needs. DNS works like the **phone contacts** on your mobile: you tap a person's name, and the phone dials the number saved behind it.

Understanding how DNS is structured also explains what actually happens when you buy a domain and point it at your server.

## How it works

**The basic translation:**
```
facebook.com  →  104.104.56.87
```

When you enter `facebook.com` in the browser:

1. Your system asks DNS in the background: "what's the IP of `facebook.com`?"
2. DNS answers: `104.104.56.87`.
3. The browser connects to that IP, and Facebook opens.

The browser can't connect to a name. The name always has to be converted (**resolved**) to an IP address first.

**The hierarchy — reading a domain name from right to left:**
```
mydevops   .   com
 (name)       (TLD)
```
Read a domain from **right to left**: the last part is the TLD, the part before it is the name.

- **TLD (Top-Level Domain)** — the last part of the domain: `.com`, `.in`, `.online`, `.edu`, `.us`, `.uk`, `.net`, `.org`, `.ai`, etc.

  | Domain | TLD |
  |--------|-----|
  | `google.com` | `.com` |
  | `mydevops.com` | `.com` |
  | `mydevops.in` | `.in` |
  | `amazon.net` | `.net` |

- **Registry** — every TLD has one owner, called the registry.
  1. The registry keeps the list of all domains under its TLD.
  2. For each domain, it notes **who is managing it** (its nameservers).
  3. It doesn't sell domains to us directly.

  | TLD | Managed by |
  |-----|------------|
  | `.com` | Verisign (also `.net`) |
  | `.in` | Indian government (run by NIXI - India's national internet registry) |
  | `.uk` | UK government's registry (Nominet) |
  | `.ai` | Government of Anguilla - `.ai` is Anguilla's country-code TLD |

  > **Fun fact:** `.ai` became famous because of AI companies. Every `.ai` domain sold earns money for the registry, so a big share of that revenue goes to the small country of Anguilla.
- **Registrar** — the shop where we actually buy a domain: GoDaddy, Namecheap, Hostinger, Cloudflare, AWS, etc.
  - Registry = wholesaler / record-keeper. Registrar = retailer / reseller.
  - We pay the registrar, and the registrar registers the domain with the registry.

| | Registry | Registrar |
|---|----------|-----------|
| Role | Record-keeper for one TLD (wholesaler) | Sells domains to the public (retailer) |
| Examples | Verisign (`.com`, `.net`), NIXI (`.in`) | GoDaddy, Namecheap, Hostinger, Cloudflare, AWS |
| Sells to you directly? | No | Yes |

**Root servers:**

Root servers sit **above every TLD**. They don't know any website's IP. They only know **which registry manages which TLD**.

1. A lookup can't find the IP in any cache.
2. It asks a root server: "who manages `.com`?"
3. The root server answers: "ask Verisign, the `.com` registry."

There are **13 root server addresses**, but each one is copied to many locations around the world. So it's not 13 single machines.

- **Root servers track the TLDs and their details** (which registry manages `.com`, `.in`, `.ai` ...). When a DNS resolver hits them, they send back those TLD details.
- **No root servers → no internet** (by name). Lookups can't start, so domain names stop working once caches expire. That's why there are many copies of them all over the world.
- **13 root servers (named A to M), run by 12 organizations.** Many are in the US, including the US government, the US military and NASA. Others are in Europe and Japan:

  | Root server | Run by |
  |-------------|--------|
  | A, J | Verisign (US) |
  | B | University of Southern California - ISI (US) |
  | C | Cogent Communications (US) |
  | D | University of Maryland (US) |
  | E | **NASA** Ames Research Center (US) |
  | F | Internet Systems Consortium (US) |
  | G | **US Department of Defense** (DISA) |
  | H | **US Army** Research Lab |
  | I | Netnod (Sweden) |
  | K | RIPE NCC (Netherlands) |
  | L | ICANN (US) |
  | M | WIDE Project (Japan) |

**ICANN** (Internet Corporation for Assigned Names and Numbers) is the boss of the whole DNS system.

- It manages the **root** (the list of all TLDs).
- It sets the **rules for TLDs**.
- It decides **which registrars are allowed** to sell domains.
- It's a **nonprofit**, not a government. It started under the US Department of Commerce and became fully independent in 2016.

```text
                ICANN (oversees everything)
                         │
                   Root servers
                         │
        ┌────────────────┼────────────────┐
     .com (Verisign)   .in (NIXI)     .ai (Anguilla)     ← registries
        │
   Registrar (GoDaddy, Namecheap...)   ← where you buy
        │
   Your nameservers  →  A record  →  your server's IP
```

## How a DNS Lookup Works (Step by Step)

When we search a domain, the IP is looked up **nearest first**. Each place keeps a **cache** (memory of recent answers). If one place doesn't know, the next one is asked:

```text
Browser cache → OS cache → ISP DNS resolver cache → Root servers → TLD registry → Nameservers → IP
```

If the IP isn't cached anywhere, it's our **ISP's (Internet Service Provider's) responsibility** to find it. The ISP runs a **DNS resolver** that does the searching:

```text
You type mydevops.com
      │
      ▼
Browser cache ── knows? → use it ✅
      │ no
      ▼
OS cache ─────── knows? → use it ✅
      │ no
      ▼
ISP DNS resolver cache ── knows? → use it ✅
      │ no
      ▼
ISP DNS resolver ── 1. "Who manages .com?" ─────────────▶ Root servers
      │          ◀── 2. "Ask the .com TLD registry" ────
      │
      ├───────── 3. "Who manages mydevops.com?" ────────▶ .com TLD registry
      │          ◀── 4. "I don't know the IP, but these
      │                 nameservers manage it" ─────────
      │
      ├───────── 5. "What's the IP of mydevops.com?" ───▶ Nameservers (e.g. GoDaddy / Route 53)
      │          ◀── 6. "203.0.113.10" ─────────────────
      ▼
Browser connects to 203.0.113.10
```

1. **Browser cache.** The browser first checks its own memory. If we opened this site recently, it already knows the IP.
2. **OS cache.** If the browser doesn't know, it asks the operating system (Windows / Linux / Mac), which keeps its own DNS cache.
3. **ISP DNS resolver cache.** If the OS doesn't know, the request goes to the ISP's DNS resolver. If anyone using that ISP looked up this domain recently, it already knows the IP and answers right away.
4. **Root servers.** If the resolver doesn't have the IP, it asks a root server. The root doesn't know the IP either, but it knows **which TLD registry** to ask (`.com`, `.in` ...).
5. **TLD registry.** The resolver asks the `.com` registry. It says: "I don't know your IP address, but I know **who is managing your domain**" and gives the **nameservers'** names.
6. **Nameservers.** The ISP DNS resolver checks with those nameservers. They hold the domain's records, so they give the actual **IP address**.
7. **Connect.** The resolver hands the IP back to the OS and the browser (each saves it in its cache for next time), and the request goes to that IP.

All of this runs in the **background** within milliseconds - the user only sees the website open.

**Most lookups never reach the root servers.** The browser, the OS or the ISP resolver usually has the answer in cache already. That's the whole point of caching: skip the full trip when a recent answer is on hand.

```text
TLD → Nameservers → who manages your domain → IP
```

## What happens when you buy a domain
1. You go to a registrar (GoDaddy, Namecheap, etc.) and search for a domain, e.g. `mydevops.com`.
2. The registrar checks with the TLD's registry whether it's already taken.
3. If it's free, you provide your name, contact details and payment to the registrar.
4. The registrar registers the domain and updates the TLD's registry with which **nameservers** manage it - usually the registrar's own nameservers, unless you point it elsewhere (e.g. Cloudflare or AWS Route 53).
5. From then on, anyone looking up `mydevops.com` gets routed: root servers → `.com` registry → your nameservers → the IP address you've configured.

The registrar earns a commission for handling the sale and paperwork on behalf of the registry - registries don't sell directly to the public.

**Which registrar to pick - long-term vs short-term domain:**

| | Permanent (long-term) domain | Temporary (short-term) domain |
|---|------------------------------|-------------------------------|
| Example registrar | GoDaddy | Hostinger |
| First-year (initial) price | Higher | Cheap - big first-year discounts |
| Renewal price | Reasonable | Higher - renewals cost much more than year one |
| Good for | A domain you'll keep for years (company / product site) | Practice, demos, a project you'll drop after a year |

Rule of thumb: **check the renewal price, not just the first-year price.** If you'll keep the domain for years, the cheap first year doesn't matter - the renewals do. Prices change often, so compare before buying.

The registrar earns a commission for handling the sale and paperwork on behalf of the registry — registries don't sell directly to the public.

## DNS Record Types
A domain can hold several kinds of DNS records, each pointing to a different kind of destination:

| Record | Points to | Example use |
|---|---|---|
| **A** | An IPv4 address | `mydevops.online → <frontend-public-ip>` — the most common record, points a domain straight at a server |
| **AAAA** | An IPv6 address | Same idea as A, for IPv6 |
| **CNAME** | Another domain name (an alias) | `www.mydevops.online → mydevops.online` |
| **NS** | The nameservers responsible for the domain | Points to whichever provider is actually managing the records — the registrar's own nameservers, or a different one like AWS Route 53, Cloudflare, etc. |
| **MX** | A mail server | Routes email sent to the domain to the right mail provider |
| **TXT** | Arbitrary text | Domain ownership verification, SPF/DKIM records for email |
| **SOA** | Start of Authority - metadata about the domain's zone | Which nameserver is the primary source of truth, plus settings like TTL defaults |

## TTL (Time to Live)
Every DNS record has a **TTL** - how long a resolver (and the browser / OS) can keep a cached answer before it has to ask the nameservers again. It's a trade-off:

| | High TTL (e.g. 1 day) | Low TTL (e.g. 1 minute) |
|---|---|---|
| Lookup speed | Faster - most requests are answered from cache | Slower - more requests go back to the nameservers |
| Change propagation | Slow - an IP change can take up to the full TTL to reach everyone | Fast - a change is visible almost everywhere within the TTL |

**Changing a record safely** (e.g. moving a domain from an on-premise server's IP to a new cloud IP):

```text
1. Lower TTL (e.g. 1 day → 1 min) a day or two BEFORE the change
2. Wait for the old long TTL to expire everywhere
3. Change the A record to the new IP  → spreads within ~1 min
4. Confirm the new server works
5. Raise TTL back to normal
```

If you skip step 1, anyone whose resolver cached the old record under the long TTL keeps going to the **old IP** until that TTL expires - even though the record was already changed.

## Pointing a Domain at AWS (Route 53)
Buying a domain from a registrar doesn't mean that registrar has to manage its DNS records — they can be delegated elsewhere. A common setup for a domain whose server lives on AWS:
1. Create a **hosted zone** for the domain in AWS Route 53 — AWS hands back a set of its own nameservers for that domain.
2. Go back to the registrar and update the domain's **NS record** to point at those AWS nameservers instead of the registrar's default ones.
3. Once that change propagates, Route 53 becomes authoritative for the domain — any record created there is what the world actually sees when it looks up the domain.
4. Add an **A record** in Route 53 pointing the domain at the server's public IP.

```text
Registrar (NS → AWS nameservers)  →  Route 53 hosted zone  →  A record  →  <frontend-public-ip>
```

From then on, `http://mydevops.online` resolves straight to the server — nobody needs to remember or share the IP, and if the server's IP ever changes, only that one A record needs updating rather than every place the IP was shared.

## Common problems and how to solve them
A common misconception is that the registrar "owns" your DNS — it doesn't. The registrar just manages which nameservers the registry has on file for your domain. You can register a domain at one registrar and point its nameservers at a completely different provider (Cloudflare, AWS Route 53, etc.) to actually manage the DNS records.

Another common confusion: thinking a domain name *is* the server. It isn't — it's just a pointer. Changing a DNS record (e.g. an A record pointing to a new IP) doesn't move or change your server; it just changes where the name resolves to, and that change can take time to propagate depending on DNS caching (TTL).

## Key takeaways
- DNS exists because computers route by IP, not by name — it's purely a name-to-IP translation layer.
- Lookup: browser cache → OS cache → ISP DNS resolver cache → root servers → TLD registry → nameservers → IP. The TLD doesn't know the IP, only who manages the domain (nameservers).
- The hierarchy is root servers → TLD registry → registrar → your nameservers → the IP address.
- Registry vs registrar: the registry (e.g. Verisign for `.com`) is the authoritative record-keeper for a TLD; the registrar (e.g. GoDaddy) is who you actually buy from — a retailer, not the record-keeper.
- ICANN oversees the whole system but is an independent nonprofit, not a government body, despite having originated under U.S. government oversight decades ago.
- Buying a domain doesn't give you a server — it gives you a name you can point at one, and that pointer is exactly what DNS records control.
- Different record types do different jobs: **A** points a domain at an IP, **CNAME** aliases one domain to another, **NS** says who manages the records, **MX** routes email.
- A domain's DNS doesn't have to stay with the registrar it was bought from — updating its NS record lets another provider (e.g. AWS Route 53) take over managing its records entirely.
- TTL controls the trade-off between lookup speed and how fast a change propagates — lower it before a planned IP change, then raise it back once the change has settled.
- Picking a registrar: check renewal price, not just year one. Long-term domain → e.g. GoDaddy (higher initial price); short-term / practice → e.g. Hostinger (cheap first year, costly renewals).

See also: [Day 7 - 3-Tier Expense App](../day-07-3tier-nodejs-expense-app/README.md) (the frontend public IP a domain's A record points to)

---

## Interview Questions

17 questions with short answers → [interview-questions/](interview-questions/README.md)
