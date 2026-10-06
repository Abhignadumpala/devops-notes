# Day 10 - Databases: SQL, NoSQL, Caching and Message Queues

> **In short:** One app usually uses several kinds of storage. **SQL** for strict data (orders, payments), **NoSQL** for flexible data (product catalog), a **cache** (Redis) for speed, and a **message queue** (RabbitMQ) for work that doesn't need an answer right away.

## Table of Contents

1. [What this is / why it matters](#what-this-is--why-it-matters)
2. [SQL (Relational) Databases](#sql-relational-databases)
3. [NoSQL Databases](#nosql-databases)
4. [Using Both in the Same App](#using-both-in-the-same-app)
5. [Redis: Caching](#redis-caching)
6. [Message Queues: Sync vs Async](#message-queues-sync-vs-async)
7. [Common problems and how to solve them](#common-problems-and-how-to-solve-them)
8. [Key takeaways](#key-takeaways)
9. [Interview Questions](#interview-questions)

**More in this folder:** [Interview questions](interview-questions/README.md)

---

## What this is / why it matters

"Database" isn't one single thing. A real app combines different kinds of storage, each for a different job:

| Need | Tool | Example |
|------|------|---------|
| Strict structure, relationships, transactions | SQL database | MySQL, PostgreSQL |
| Flexible data, shape changes per record | NoSQL database | MongoDB, DynamoDB |
| Fast reads | Cache | Redis, Memcached |
| Work that doesn't need an immediate answer | Message queue | RabbitMQ, Kafka |

Pick the right tool for each job, instead of forcing everything into one database that's bad at most of it.

## SQL (Relational) Databases

Structure: **Database → Tables → Rows and Columns**.

- Every **row** is one record (e.g. one customer).
- **Columns** are fixed per table.
- **Primary keys** and **foreign keys** link tables. Example: `customers` and `payments` are linked by customer ID - payment info is not stuffed into the customer table.

**Best for:** data that must stay strict and consistent - orders, payments.

**Examples:** MySQL, PostgreSQL, Oracle, MSSQL.

## NoSQL Databases

Structure: **Database → Collections → Documents (JSON)**.

A document holds whatever fields it needs - **no fixed schema**:

```json
{
  "_id": "123456",
  "name": "<name>",
  "mobile": "<mobile>",
  "email": "<email>",
  "address": "<city>",
  "experience": "5 years",
  "skills": "devops"
}
```

- Another document in the same collection can look different - one has `address`, another skips it.
- Relationships between documents (e.g. `student` and `student_skills` linked by `student_id`) are **possible but optional**.

| SQL | NoSQL |
|---|---|
| Table | Collection |
| Row | Document |
| Primary / foreign keys: **mandatory** | Relationships: **optional** |
| Fixed columns per table | Fields can vary per document |

**Best for:** data whose shape varies, or that must scale fast - product catalogs, user profiles, logs.

**Examples:** MongoDB, Cassandra, DynamoDB.

## Using Both in the Same App

Most apps use both, each where it fits. Example - an e-commerce app:

| Data | Database | Why |
|------|----------|-----|
| Product catalog (name, description, ratings, reviews, specs - different per product) | NoSQL (MongoDB) | Fields vary per product |
| Orders and payments | SQL (MySQL) | Strict structure, needs transactions |

**Security groups at the DB tier:**

1. A `catalogue` service uses MongoDB on its default port **27017**.
2. A `user` service also needs the same MongoDB.
3. Each service has its **own security group**.
4. MongoDB's SG allows **27017 only from the SGs of `catalogue` and `user`** - not from every server in the network.

Same least-privilege idea as the MySQL SG (3306 only from the backend) in [Day 7](../day-07-3tier-nodejs-expense-app/README.md).

## Redis: Caching

A **cache** is a key-value store kept in **RAM**, not on disk. RAM is faster than disk, so a cache is faster than going to the database.

**Without a cache,** every read does the full trip: get a connection from the pool → open it → run the query → close it. Slow if it happens on every read.

**With a cache:**

```text
Cache hit:   App → Cache → User                (fast)
Cache miss:  App → Cache → DB → Cache → User   (goes to the DB, then saves in cache for next time)
```

**TTL** - how long a cached value is trusted (e.g. 1 hour).

- Data changed before the TTL ends? → the app must **invalidate** (clear) that cache entry.
- If not, users see the **old (stale)** value until the TTL expires.

**Examples:** Redis, Memcached.

## Message Queues: Sync vs Async

| | Synchronous (HTTP) | Asynchronous (message queue) |
|---|---|---|
| How | Client sends a request and **waits** for the response | Client sends a message and **moves on** ("fire and forget") |
| No answer? | Error after a timeout | Fine - the receiver processes it when it can |
| Use for | Things that need an answer now | Work that can happen later (emails, order processing) |

**Two delivery patterns:**

| Pattern | Who gets the message |
|---|---|
| **Point-to-point** | Exactly **one** consumer |
| **Publish/subscribe** | **Every** subscriber interested in it |

**Examples:** RabbitMQ, ActiveMQ, Kafka.

> Kafka is really an event-streaming platform, not a classic message broker like RabbitMQ, but it's grouped with them because it solves the same "don't make the sender wait" problem.

## Common problems and how to solve them

| Problem | Why it happens | Fix |
|---------|----------------|-----|
| **Stale cache reads** | Cache not invalidated after an update → old data until TTL expires | Invalidate on write, or keep the TTL short for data that changes often |
| **Wrong database for the data** | Flexible data (catalog) forced into rigid SQL tables, or payments in a schema-less NoSQL store | Match the DB type to the data's shape and consistency needs |
| **Expecting a queue to act like HTTP** | A queue never promises an immediate response | If you need an answer right now, use HTTP, not a queue |

## Key takeaways

- **SQL** - tables, rows/columns, mandatory primary/foreign keys. Best for orders and payments.
- **NoSQL** (e.g. MongoDB) - flexible JSON documents in collections, optional relationships. Best for varying data and fast scaling.
- **Cache** (e.g. Redis) - in RAM in front of the DB for fast reads; TTL decides how long a value is trusted, invalidate it when data changes.
- **Message queue** (e.g. RabbitMQ) - sender doesn't wait; for async, fire-and-forget work that HTTP isn't built for.

See also: [Day 6 - 3-Tier Architecture & Databases](../day-06-3-tier-architecture-databases/README.md) · [Day 7 - Expense App](../day-07-3tier-nodejs-expense-app/README.md)

---

## Interview Questions

10 questions with short answers → [interview-questions/](interview-questions/README.md)
