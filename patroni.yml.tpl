scope: pg-cluster
namespace: /service
name: ${PATRONI_NAME}
 
etcd3:
  hosts: etcd:2379
 
restapi:
  listen: 0.0.0.0:8008
  connect_address: ${PATRONI_NAME}:8008
 
bootstrap:
  dcs:
    ttl: 20
    loop_wait: 5
    retry_timeout: 5
    maximum_lag_on_failover: 1048576
    synchronous_mode: false
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_keep_size: 512MB
        archive_mode: "${ARCHIVE_MODE}"
        archive_command: "pgbackrest --stanza=demo archive-push %p"
        archive_timeout: 60
        restore_command: '${RESTORE_COMMAND}'
        unix_socket_directories: "/var/run/postgresql"
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - local all postgres peer
    - host replication replicator 0.0.0.0/0 scram-sha-256
    - host all all 0.0.0.0/0 scram-sha-256
 
postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${PATRONI_NAME}:5432
  data_dir: /var/lib/postgresql/data/patroni
  bin_dir: /usr/lib/postgresql/16/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: rep_password
    superuser:
      username: postgres
      password: postgrespassword
