#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
export COMPOSE_PROFILES=backup
export BACKUP_MODE=on
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== [1/4] TẠO CHỨNG CHỈ TLS CHO MINIO ==="
bash scripts/gen_certs.sh

echo "=== [2/4] KHỞI ĐỘNG CỤM DOCKER COMPOSE ==="
docker compose up -d

echo "=== [3/4] CHỜ CỤM PATRONI BẦU LEADER VÀ HAPROXY SẴN SÀNG ==="
TRY=0
until docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep -q "Leader" || docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep -q "Leader"; do
  TRY=$((TRY + 1))
  if [ $TRY -gt 40 ]; then
    echo ""
    echo "Quá thời gian chờ bầu Leader. Xem logs: docker logs pg-patroni-1"
    exit 1
  fi
  printf "    >> [Đang chờ Patroni khởi tạo và bầu Leader: %2ds/120s] ...\r" "$((TRY * 3))"
  sleep 3
done
echo ""
echo "    -> Patroni đã bầu Leader thành công!"

echo "Trạng thái cụm Patroni:"
docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null || docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list

docker exec pg-patroni-1 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true
docker exec pg-patroni-2 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true

echo "=== [4/4] KHỞI TẠO STANZA VÀ FULL BACKUP ĐẦU TIÊN ==="
bash scripts/init_backup.sh

echo "=========================================================="
echo "CỤM ĐÃ SẴN SÀNG HOÀN TOÀN CHO NGƯỜI 2!"
echo "- HAProxy Write (Leader):  localhost:5000"
echo "- HAProxy Read (Replica): localhost:5001"
echo "- HAProxy Dashboard:      http://localhost:7000"
echo "- MinIO Console:          https://localhost:9001 (minioadmin / minioadmin)"
echo "=========================================================="
