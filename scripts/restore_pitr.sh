#!/bin/bash
set -e
set -o pipefail
export MSYS_NO_PATHCONV=1
export COMPOSE_PROFILES=backup
export BACKUP_MODE=on
source "$(dirname "$0")/common.sh"
cd "$PROJECT_DIR"

MODE="$1"
TARGET="$2"
if [ -z "$MODE" ]; then
  MODE="name"
  if [ -f "$LOG_DIR/restore_point.txt" ]; then
    TARGET=$(cat "$LOG_DIR/restore_point.txt")
  else
    echo "[LỖI] Không tìm thấy file restore_point.txt!"
    echo "Gợi ý: Bạn cần chạy bước Kích hoạt thảm họa (scripts/demo_disaster.sh) trước!"
    exit 1
  fi
fi
if [ "$MODE" != "name" ] && [ "$MODE" != "time" ]; then
  echo "Cách dùng: ./scripts/restore_pitr.sh                      (dùng restore point vừa ghi)"
  echo "           ./scripts/restore_pitr.sh time '2026-11-11 08:30:15.123456+00'"
  exit 1
fi

TOTAL_START=$(date +%s)

echo "[1/6] Dừng HAProxy và 2 node Patroni..."
docker compose stop haproxy pg-patroni-1 pg-patroni-2

echo "[2/6] Xóa trạng thái cụm cũ trong etcd và dữ liệu node 2..."
docker compose rm -sf etcd pg-patroni-1 pg-patroni-2
docker volume rm patroni_pg2_data || true
docker compose up -d --wait etcd

echo "[3/6] Restore bằng pgBackRest vào volume node 1 (Patroni đang tắt)..."
RESTORE_START=$(date +%s)
docker compose run --rm --no-deps -e PGBACKREST_REPO1_STORAGE_VERIFY_TLS=n -T --entrypoint bash pg-patroni-1 \
  -c "tr -d '\r' < /scripts/pitr_inside.sh | bash -s -- '$MODE' '$TARGET'" | tee "$LOG_DIR/pitr_restore.log"
RESTORE_END=$(date +%s)

echo "[4/6] Khởi động node 1, Patroni nhận dữ liệu đã PITR làm Leader..."
docker compose up -d pg-patroni-1
TRY=0
until docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep -q Leader; do
  TRY=$((TRY + 1))
  if [ $TRY -gt 60 ]; then
    echo "Node 1 chưa lên Leader sau 2 phút. Xem: docker logs pg-patroni-1"
    exit 1
  fi
  printf "    >> [Đang chờ Patroni khởi tạo và bầu Leader: %2ds/60s] ...\r" "$((TRY * 2))"
  sleep 2
done
echo ""
echo "    -> Patroni Node 1 đã lên Leader thành công!"
docker exec pg-patroni-1 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true

echo "[5/6] Khởi động node 2 (clone lại từ node 1) và HAProxy..."
docker compose up -d pg-patroni-2 haproxy
TRY=0
until docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep pg-patroni-2 | grep -q "running"; do
  TRY=$((TRY + 1))
  if [ $TRY -gt 30 ]; then
    echo ""
    echo "    [LƯU Ý] Node 2 đang đồng bộ dữ liệu trong nền."
    break
  fi
  printf "    >> [Đang đồng bộ Replica pg-patroni-2: %2ds/30s] ...\r" "$TRY"
  sleep 1
done
echo ""
echo "    -> Node 2 và HAProxy đã sẵn sàng!"
docker exec pg-patroni-2 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true

echo "[6/6] Tạo Full backup mới trên timeline mới sau phục hồi..."
echo "    -> Đang tiến hành pgBackRest full backup..."
docker exec -e PGBACKREST_REPO1_STORAGE_VERIFY_TLS=n pg-patroni-1 pgbackrest --stanza=demo --type=full backup

TOTAL_END=$(date +%s)
echo "=========================================================="
echo "PHỤC HỒI THẢM HỌA PITR THÀNH CÔNG!"
echo "- Thời gian restore và replay WAL (bước 3): $((RESTORE_END - RESTORE_START)) giây"
echo "- Tổng thời gian đưa cụm hoạt động lại      : $((TOTAL_END - TOTAL_START)) giây"
echo "Chạy tiếp bước Kiểm tra toàn vẹn (scripts/verify_after_restore.sh)"
echo "=========================================================="
