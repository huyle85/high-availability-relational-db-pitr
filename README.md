# High-Availability PostgreSQL Cluster & Point-in-Time Recovery (PITR)

A containerized, production-oriented PostgreSQL High Availability (HA) and Disaster Recovery (PITR) architecture built with **Docker Compose**, **Patroni**, **etcd**, **HAProxy**, **pgBackRest**, and **MinIO (S3)**.

This project demonstrates how to eliminate single points of failure (SPOF), achieve automated leader election and failover with zero data loss (`RPO = 0`), split Read/Write traffic seamlessly, and recover databases to an exact point in time prior to logical data disasters (such as accidental `DROP TABLE`).

---

## Architecture Overview

The entire infrastructure runs inside an isolated Docker bridge network (`ha-net`) and consists of **7 orchestrated containers**:

```text
                    +-----------------------+
                    |   Client / Backend    |
                    +-----------+-----------+
                                |
                 +--------------+--------------+
                 | Port 5000 (RW) | Port 5001 (RO)
                 v                             v
         +-------+-----------------------------+-------+
         |                  HAProxy                    |
         |        (Health Checks & Routing)            |
         +-------+-----------------------------+-------+
                 |                             |
        +--------+--------+           +--------+--------+
        v                 v           v                 v
+---------------+ +---------------+ +---------------+
| pg-patroni-1  | | pg-patroni-2  | | pg-patroni-3  |  <-- PostgreSQL + Patroni + pgBackRest
|   (Leader)    | |   (Replica)   | |   (Replica)   |
+-------+-------+ +-------+-------+ +-------+-------+
        |                 |                 |
        +-----------------+-----------------+
                          | (Consensus & Leader Lock)
                          v
                  +---------------+
                  |     etcd      |
                  +---------------+
                          
        +-----------------+-----------------+
        | (Continuous WAL Archiving & Full Backups over HTTPS/TLS, lz4)
        v
+---------------+
|   MinIO S3    |
+---------------+
