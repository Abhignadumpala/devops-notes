# Day 6 - 3-Tier Architecture & Databases

## Table of Contents

1. [3-Tier Architecture - Food Analogy](#3-tier-architecture---food-analogy)
2. [1-Tier, 2-Tier, 3-Tier](#1-tier-2-tier-3-tier)
3. [Tier Technologies](#tier-technologies)
4. [Practice Server Setup](#practice-server-setup)
5. [Types of Data](#types-of-data)
6. [DBMS vs RDBMS](#dbms-vs-rdbms)
7. [Summary](#summary)
8. [Interview Questions](#interview-questions)

---

## 3-Tier Architecture - Food Analogy

**Cooking = converting raw materials into an eatable format.**
**An application = converting data into a usable format.**

### Stage 1: Road-Side Cart (~5 customers)

One person does everything:

1. Take the order
2. Cook it
3. Serve the order
4. Get the payment

### Stage 2: Hotel (~10 customers)

Staff hired, work is split:

- **Owner** - gives tokens, takes payment
- **Cook** - takes tokens, keeps them in a queue, cooks and serves

### Stage 3: Restaurant (~15+ customers)

| Role | Job | Tech Equivalent |
|------|-----|-----------------|
| Captain | Welcomes you, shows you a table | **Load Balancer** |
| Waiter | Takes the order, brings food, garnishes it (onion, lemon, salad) | **Frontend** |
| Chef | Reads the order, cooks it | **Backend** |
| Raw materials | Ingredients | **Database (data)** |
| Customer | Eats | **User** |

As customers grow, work is split into specialised roles - same with applications.

---

## 1-Tier, 2-Tier, 3-Tier

| Architecture | Servers | Layout |
|--------------|---------|--------|
| 1-tier | 1 Linux server | Frontend + Backend + Database on one server |
| 2-tier | 2 Linux servers | App (frontend + backend) + Database |
| 3-tier | 3 Linux servers | Frontend + Backend + Database, each separate |

### 3-Tier Flow

```text
User → Load Balancer → Frontend → Backend → Database
```

| Tier | Also Called |
|------|-------------|
| Frontend | Web / HTTP tier |
| Backend | App / Middleware tier |
| Database | DB / Data tier |

Benefits: each tier can be scaled, secured and updated separately.

---

## Tier Technologies

### Frontend

HTML, CSS, JavaScript, ReactJS, mobile apps

### Backend

Java, Node.js, Python, PHP, .NET, Groovy

Backend does **CRUD** (Create, Read, Update, Delete) on the database.

### Database

| Database | Type |
|----------|------|
| MySQL | Relational (RDBMS) |
| PostgreSQL | Relational (RDBMS) |
| MS SQL | Relational (RDBMS) |
| Oracle | Relational (RDBMS) |
| MongoDB | NoSQL (documents) |
| Kafka | Message streaming (often used alongside databases) |

### Database Admin Tasks

Install, upgrade, backup, restore, create schemas, monitor, scale, clustering.

---

## Practice Server Setup

| Setting | Value |
|---------|-------|
| AMI name | `Redhat-9-DevOps-Practice` |
| AMI ID | `ami-0220d79f3f480ecf5` |
| Username | `ec2-user` |

---

## Types of Data

| Type | Description | Example |
|------|-------------|---------|
| Structured | Fixed rows and columns | Database tables, Excel |
| Semi-structured | Has a pattern but not fixed tables | Logs, JSON, XML |
| Unstructured | No fixed format | Images, videos, PDFs |

### Semi-Structured Example - Web Server Log

```text
127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326
```

Converted to key → value:

| Key | Value |
|-----|-------|
| Client IP | `127.0.0.1` |
| Client name | `frank` |
| Timestamp | `10/Oct/2000:13:55:36 -0700` |
| Method | `GET` |
| Resource | `/apache_pb.gif` |
| Status | `200` |
| Size (bytes) | `2326` |

---

## DBMS vs RDBMS

| | DBMS | RDBMS |
|---|------|-------|
| Stores data as | Files / documents | Tables (rows & columns) |
| Relations between data | No | **Yes** - tables linked by IDs |
| Examples | MongoDB | MySQL, PostgreSQL, Oracle |

### RDBMS Example - Training Institute

```text
Institute ─1:many→ Courses ─1:many→ Batches ─1:many→ Students
                     ↑
               Trainers ─1:many
```

**trainer** table:

| trainer_id | name | email | mobile |
|------------|------|-------|--------|
| 1 | Ravi | ravi@example.com | 9XXXXXXXXX |

**course** table:

| course_id | course_name | course_description | course_code | trainer_id |
|-----------|-------------|--------------------|-------------|------------|
| 1 | AIOps with DevSecOps | Linux, admin, DevOps | DEVOPS-01 | 1 |

`trainer_id` in the **course** table points to `trainer_id` in the **trainer** table - that link is the **relation**.

| Term | Meaning |
|------|---------|
| Primary key | Unique ID of each row (`trainer_id` in trainer table) |
| Foreign key | Column that refers to another table's primary key (`trainer_id` in course table) |

---

## Summary

- **3-tier** = Load Balancer → Frontend → Backend → Database.
- Restaurant analogy: Captain = LB, Waiter = Frontend, Chef = Backend, Raw materials = Data.
- **Data types**: structured (tables), semi-structured (logs, JSON), unstructured (images, videos).
- **RDBMS** = tables related by IDs (primary key ↔ foreign key).

---

## Interview Questions

10 questions with short answers → [interview-questions/](interview-questions/README.md)
