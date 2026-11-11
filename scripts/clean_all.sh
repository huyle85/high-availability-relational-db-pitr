#!/bin/bash
export MSYS_NO_PATHCONV=1
export COMPOSE_PROFILES=backup
export TZ='ICT-7'
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== DỪNG VÀ XÓA TOÀN BỘ CỤM CONTAINER & NAMED VOLUMES ==="
docker compose --profile backup down -v --remove-orphans 2>/dev/null || docker compose down -v --remove-orphans 2>/dev/null || true
docker volume rm -f patroni_minio_data minio_data patroni_pg1_data patroni_pg2_data high-availability-relational-db-pitr_backup_store high-availability-relational-db-pitr_wal_archive 2>/dev/null || true
rm -rf certs/*.key certs/*.crt certs/*.srl scripts/logs/*
echo "Đã dọn dẹp sạch sẽ toàn bộ môi trường (volumes, certs, logs, kho MinIO S3)!"
