#!/bin/bash
set -e
set -o pipefail
source "$(dirname "$0")/common.sh"
cd "$PROJECT_DIR"
 
MODE="$1"
TARGET="$2"
if [ -z "$MODE" ]; then
  MODE="name"
  TARGET=$(cat "$LOG_DIR/restore_point.txt")
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
docker compose run --rm --no-deps -T --entrypoint bash pg-patroni-1 \
  /scripts/pitr_inside.sh "$MODE" "$TARGET" | tee "$LOG_DIR/pitr_restore.log"
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
  sleep 2
done
 
echo "[5/6] Khởi động node 2 (clone lại từ node 1) và HAProxy..."
docker compose up -d pg-patroni-2 haproxy
 
echo "[6/6] Full backup mới trên timeline mới..."
docker exec pg-patroni-1 pgbackrest --stanza=demo --type=full backup
 
TOTAL_END=$(date +%s)
echo "Thời gian restore và replay WAL (bước 3): $((RESTORE_END - RESTORE_START)) giây"
echo "Tổng thời gian đưa cụm hoạt động lại      : $((TOTAL_END - TOTAL_START)) giây"
echo "Chạy tiếp: ./scripts/verify_after_restore.sh"
