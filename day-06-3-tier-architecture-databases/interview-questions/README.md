# Day 6 - Interview Questions

[← Back to Day 6 notes](../README.md)

**1. What is 3-tier architecture?**

Splitting an app into three layers on separate servers: **Frontend** (web/UI), **Backend** (app/business logic), **Database** (data). Usually a load balancer sits in front.

**2. Why 3-tier instead of 1-tier?**

Each tier can be scaled, secured and updated independently. The database is not exposed to the internet, and one tier failing doesn't take down everything.

**3. What is a load balancer?**

It receives user traffic and distributes it across multiple servers, so no single server is overloaded and the app stays available if one fails.

**4. Frontend vs backend technologies?**

Frontend: HTML, CSS, JavaScript, React. Backend: Java, Node.js, Python, .NET, PHP.

**5. What is CRUD?**

Create, Read, Update, Delete - the basic operations the backend does on the database.

**6. Structured vs semi-structured vs unstructured data?**

Structured: fixed tables (MySQL, Excel). Semi-structured: has a pattern but no fixed table (logs, JSON, XML). Unstructured: no format (images, videos, PDFs).

**7. DBMS vs RDBMS?**

RDBMS stores data in tables with relations between them (MySQL, PostgreSQL, Oracle). A plain DBMS stores data without enforced relations.

**8. Primary key vs foreign key?**

Primary key uniquely identifies each row in a table. Foreign key is a column that refers to another table's primary key - it creates the relation.

**9. SQL vs NoSQL?**

SQL: relational tables with a fixed schema (MySQL, PostgreSQL). NoSQL: flexible formats like documents or key-value (MongoDB, DynamoDB).

**10. What database tasks does a DevOps engineer handle?**

Install, upgrade, backup, restore, create schemas, monitor, scale and set up clustering/replication.
