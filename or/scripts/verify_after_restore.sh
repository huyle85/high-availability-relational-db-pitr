#!/bin/bash
source "$(dirname "$0")/common.sh"
 
echo "Chờ cổng ghi 5000 sẵn sàng..."
until run_sql 5000 "SELECT 1;" > /dev/null 2>&1; do
  sleep 2
done
 
echo "--- Kiểm tra dữ liệu ---"
BEFORE=$(cat "$LOG_DIR/before.txt")
AFTER=$(run_sql 5000 "$CHECK_QUERY")
echo "Trước thảm họa: $BEFORE"
echo "Sau phục hồi  : $AFTER"
if [ "$BEFORE" = "$AFTER" ]; then
  echo "[PASS] Số bản ghi, tổng tiền và MD5 khớp."
else
  echo "[FAIL] Dữ liệu không khớp."
fi
 
echo "--- Kiểm tra toàn vẹn khối dữ liệu ---"
CHECKSUM_FAILURES=$(run_sql 5000 "SELECT checksum_failures FROM pg_stat_database WHERE datname = 'postgres';")
echo "checksum_failures = $CHECKSUM_FAILURES (0 là đạt)"
 
echo "--- Kiểm thử ứng dụng: chuyển tiền trong một giao dịch ---"
TOTAL_BEFORE=$(run_sql 5000 "SELECT sum(balance) FROM bank_accounts;")
docker exec -i -e PGPASSWORD=postgrespassword pg-client \
  psql -h haproxy -p 5000 -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
BEGIN;
UPDATE bank_accounts SET balance = balance - 1000000 WHERE owner_name = 'Le Van Huy';
UPDATE bank_accounts SET balance = balance + 1000000 WHERE owner_name = 'Tran Thi B';
COMMIT;
SQL
TOTAL_AFTER=$(run_sql 5000 "SELECT sum(balance) FROM bank_accounts;")
if [ "$TOTAL_BEFORE" = "$TOTAL_AFTER" ]; then
  echo "[PASS] Giao dịch chuyển tiền chạy được, tổng tiền không đổi: $TOTAL_AFTER"
else
  echo "[FAIL] Tổng tiền thay đổi: $TOTAL_BEFORE -> $TOTAL_AFTER"
fi
 
echo "--- Kiểm tra Replica đọc được dữ liệu sau phục hồi ---"
sleep 5
REPLICA_COUNT=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
echo "Replica (cổng 5001) trả về: $REPLICA_COUNT"
 
echo "--- pgbackrest verify ---"
LEADER=$(get_leader)
docker exec "$LEADER" pgbackrest --stanza=demo verify || true
