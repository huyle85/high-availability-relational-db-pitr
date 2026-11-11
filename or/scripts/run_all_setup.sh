#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
 
echo "=== [1/4] TẠO CHỨNG CHỈ TLS CHO MINIO ==="
bash scripts/gen_certs.sh
 
echo "=== [2/4] KHỞI ĐỘNG CỤM DOCKER COMPOSE ==="
docker compose up -d
 
echo "=== [3/4] CHỜ CỤM PATRONI BẦU LEADER VÀ HAPROXY SẴN SÀNG ==="
until docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep -q "Leader"; do
  echo "Đang chờ Patroni khởi tạo và bầu Leader..."
  sleep 3
done
 
docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list
 
echo "=== [4/4] KHỞI TẠO STANZA VÀ FULL BACKUP ĐẦU TIÊN ==="
bash scripts/init_backup.sh
 
echo "=========================================================="
echo "CỤM ĐÃ SẴN SÀNG HOÀN TOÀN!"
echo "- HAProxy Write (Leader):  localhost:5000"
echo "- HAProxy Read (Replica): localhost:5001"
echo "- HAProxy Dashboard:      http://localhost:7000"
echo "- MinIO Console:          https://localhost:9001 (minioadmin / minioadmin)"
echo "=========================================================="
