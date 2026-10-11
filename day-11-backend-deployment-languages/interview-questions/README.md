# Day 11 - Interview Questions

[← Back to Day 11 notes](../README.md)

**1. What are the common steps to deploy a backend service, whatever the language?**

Install the runtime → create `/app` and a system user → download and extract the code → install dependencies → create a systemd service → load data if needed → start the service.

**2. Name the build tool and build file for Node.js, Java, Python and Go.**

Node.js: npm, `package.json`. Java: Maven, `pom.xml`. Python: pip, `requirements.txt`. Go: the `go` command, `go.mod` + `go.sum`.

**3. Where does each language store its dependencies?**

Node.js: `node_modules/` inside each app. Java: shared `~/.m2/repository`. Python: shared system folder, or a `venv` per app. Go: shared module cache `$GOPATH/pkg/mod`.

**4. What is GAV in Maven?**

Group-id, Artifact-id, Version (e.g. `com.hdfcbank:netbanking:1.2.0`). It lets many projects share one `~/.m2` cache without version clashes.

**5. What does `mvn clean package` do?**

Deletes the old `target/` folder, then validates, compiles, runs tests and packages the app into a `.jar` in `target/`.

**6. JDK vs JRE?**

JRE only runs compiled Java. JDK = JRE + build tools like the `javac` compiler. Build servers need the JDK; servers that only run the `.jar` need the JRE.

**7. Why use a Python virtual environment (venv)?**

pip installs into a shared folder by default, so two apps needing different versions of a package conflict. A venv gives each app its own Python and libraries.

**8. What is `JAVA_HOME` and why set it?**

It points to the Java version tools like Maven should use. With several Java versions installed, setting it avoids building with the wrong one.

**9. Which languages are compiled and which are interpreted?**

Go compiles to a native binary. Java compiles to bytecode that runs on the JVM. Node.js and Python run the source directly.

**10. Why is a Go service easy to deploy?**

`go build` makes one self-contained binary. The server needs no Go, JRE or interpreter - just copy the file and run it.

**11. Who can write to the production database, and how?**

Nobody connects directly. Users and sellers write through the app's API, admins through an admin client / jump server, and schema or master data is loaded from an allowed app server (or a CI/CD migration). The DB security group allows only those servers.
