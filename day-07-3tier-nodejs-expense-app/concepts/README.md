# Day 7 - Concepts Learned

[← Back to Day 7 notes](../README.md)

## 1. System User

- **Human user** → for people, logs in with username/password or key, has a shell.
- **System user** → for apps/services, no login, no credentials, no shell.
- Running apps as a human/root user means more privileges, bigger blast radius, files under a person's name, breaks when the person resigns, and poor auditing.
- So we run apps as a system user → smaller blast radius and least privilege.

Full explanation → [Part 2, Step 2](../README.md#2-create-a-system-user).

## 2. Build Tools

Developers write a lot of files. Before the app can run, the same steps have to be repeated every time. A **build tool** automates them.

**What a build tool does:**

1. **Installs dependencies** (libraries the code needs).
2. **Automates repeating steps**: clean old output → download new code → compile the code → install dependencies → create the application.
3. **Gives a standard project structure**, so every project is organised the same way.
4. **Runs test cases** automatically and **creates the artifact**, the packaged app (`.zip`, `.tar.gz`, `.jar`, `.war`, `.ear`).

A **build file** holds info about the application: name, description, version, dependencies, and how to start it.

| Language | Build Tool | Build File | Code Extension |
|----------|------------|------------|----------------|
| Java | Maven | `pom.xml` | `.java` |
| Node.js | npm | `package.json` | `.js` |
| Python | pip | `requirements.txt` | `.py` |

In this project: Node.js 24, `npm`, `package.json`, dependencies in `node_modules/`, exact versions in `package-lock.json`.

## 3. Systemd Service Files

### Package vs Service

- **Package** → the app's compiled code that we download and store on the server. It just sits on disk. Example: `dnf install nginx -y` downloads the Nginx package.
- **Service** → when that package is **running** in the background, it's called a service. Example: `systemctl start nginx` → Nginx is now a running service.

| | Package | Service |
|---|---------|---------|
| What it is | Code/files stored on disk | The app running in the background |
| How we get it | `dnf install nginx -y` | `systemctl start nginx` |
| Doing work? | No, just stored | Yes, serving requests |
| Our backend | Code in `/app` | Running via `backend.service` |

Nginx and MySQL come with service files, so `systemctl start nginx` just works. Our backend is **custom code** - we write `/etc/systemd/system/backend.service` to tell Linux:
- **Who** runs it (`User=`)
- **How** to run it (`ExecStart=`)
- **What settings** it needs (`Environment=`)

A service file answers 3 questions:
1. **Who** has to run this application?
2. **How** to run the application?
3. Does the application need any **environment** (DB URL, credentials, etc.)?

What happens on `systemctl start backend`:
1. Goes to `/etc/systemd/system`
2. Searches for `backend.service`
3. Runs the start command (`ExecStart`) and injects the environment
4. Uses the `User` info to decide who runs the service

### systemctl Commands

Works the same for packages (`nginx`) and our custom service (`backend`):

```bash
systemctl start backend      # start now
systemctl stop backend       # stop
systemctl restart backend    # stop + start
systemctl status backend     # is it running?
systemctl enable backend     # start automatically on boot
systemctl disable backend    # don't start on boot
```

Example with a package: `dnf install nginx -y` → `systemctl start nginx` works straight away, because the package brings its own service file. Our backend is a customised application developed by us, so it can't start through systemctl until we write its service file.

## 4. Server vs Client Packages

| | Server | Client |
|---|--------|--------|
| Web | facebook.com | Chrome |
| MySQL | `mysql-server` (DB server) | `mysql` (backend server) |

## 5. Public IP vs Private IP

| | Public IP | Private IP |
|---|-----------|------------|
| Reachable from | Internet | Only inside the network |
| Example | `106.205.31.68` | `192.168.1.13`, `172.31.x.x` |
| Changes on EC2 stop/start | Yes | No |
| Use for | Users, SSH from laptop | Server-to-server |

**IPv4** = 2^32 ≈ 4 billion addresses - not enough for every device, so private IPs are reused inside networks.

## 6. Reverse Proxy

Nginx on the frontend forwards `/api/` requests to the backend. The user never talks to the backend directly, so the backend stays private.
