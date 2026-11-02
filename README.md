# Highly Available Relational Database with Point-in-Time Recovery (PITR)

## Purpose

Design and demonstrate a relational database system (**PostgreSQL**) that **stays online** when a server fails and **does not lose data** when a user makes a mistake (for example, dropping a table by accident).

The project answers the research question: *how should replication and backup work together to reduce downtime while also preventing data loss caused by operator error?*

## Key Ideas

- **Replication:** keeps a standby server continuously in sync with the primary. If the primary fails, the standby takes over within seconds (high availability, low RTO). However, an accidental `DROP` or `DELETE` is replicated to the standby immediately, so replication **cannot** protect data from operator error.
- **Backup + WAL Archive (PITR):** combines periodic full backups with continuous archiving of the write-ahead log (WAL). After a mistake, restore the last backup and replay the WAL up to the moment just before the faulty command (RPO close to zero).

The two mechanisms complement each other: replication handles **infrastructure failures**, while backup + PITR handles **human error, software bugs, and ransomware**.

## Demo Scope

1. A Golang (Gin) backend writes to the Primary, reads from the Replica, and measures replication lag.
2. Simulate a primary crash and fail over to the standby, then measure RTO.
3. Simulate an accidental table drop, show that the Replica loses the data too, then recover with PITR.

## Technologies

PostgreSQL 16, Docker Compose, Golang (Gin), MinIO.

---

> The remaining sections (detailed architecture, setup guide, results) will be added later.
