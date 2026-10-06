# Day 10 - Interview Questions

[← Back to Day 10 notes](../README.md)

**1. SQL vs NoSQL?**

SQL stores data in tables with fixed columns and mandatory primary/foreign key relationships - best for strict, transactional data. NoSQL stores flexible JSON documents in collections, relationships optional - best for data whose shape varies or that must scale fast.

**2. Map SQL terms to NoSQL (MongoDB) terms.**

Table → Collection, Row → Document, fixed columns → fields that can vary per document.

**3. Give examples of SQL and NoSQL databases.**

SQL: MySQL, PostgreSQL, Oracle, MSSQL. NoSQL: MongoDB, Cassandra, DynamoDB.

**4. Can one app use both SQL and NoSQL? Example?**

Yes. In e-commerce, the product catalog (fields differ per product) goes in MongoDB, and orders and payments (strict, need transactions) go in MySQL.

**5. What is the default MongoDB port, and how do you secure it?**

27017. Give each service its own security group, and allow 27017 on MongoDB's SG only from the SGs of the services that need it - not from the whole network.

**6. What is a cache and why is it fast?**

A key-value store kept in RAM (e.g. Redis). RAM is faster than disk, and a cache hit skips the DB query and connection overhead entirely.

**7. Cache hit vs cache miss?**

Hit: the value is in the cache → App → Cache → User. Miss: not in the cache → App → Cache → DB → Cache → User, and the value is saved in the cache for next time.

**8. Users see old data after an update. Why, and how do you fix it?**

The cache entry wasn't invalidated, so users get the stale value until the TTL expires. Invalidate the entry on write, or use a shorter TTL for data that changes often.

**9. Synchronous vs asynchronous communication?**

Synchronous (HTTP): the client waits for a response, and no reply within the timeout is an error. Asynchronous (message queue): the client sends a message and moves on; the receiver processes it later.

**10. Point-to-point vs publish/subscribe?**

Point-to-point: exactly one consumer gets the message. Publish/subscribe: every subscriber interested in it gets a copy. Examples: RabbitMQ, ActiveMQ, Kafka.
