#!/bin/bash
set -e
source "$(dirname "$0")/common.sh"
 
echo "[1] Tạo bảng bank_accounts và chèn dữ liệu..."
run_sql 5000 "CREATE TABLE bank_accounts (account_id SERIAL PRIMARY KEY, owner_name VARCHAR(100), balance NUMERIC(15,2), updated_at TIMESTAMPTZ DEFAULT clock_timestamp());" > /dev/null
run_sql 5000 "INSERT INTO bank_accounts (owner_name, balance) VALUES ('Le Van Huy', 50000000.00), ('Nguyen Van A', 120000000.00), ('Tran Thi B', 85000000.00);" > /dev/null
run_sql_table 5000 "SELECT account_id, owner_name, balance FROM bank_accounts ORDER BY account_id;"
 
echo "[2] Số bản ghi và checksum trước thảm họa:"
BEFORE=$(run_sql 5000 "$CHECK_QUERY")
echo "$BEFORE" > "$LOG_DIR/before.txt"
echo "$BEFORE"
 
echo "[3] Ghi mốc an toàn (restore point và thời gian)..."
RESTORE_POINT="truoc_drop_$(date +%s)"
run_sql 5000 "SELECT pg_create_restore_point('$RESTORE_POINT');" > /dev/null
SAFE_TIME=$(run_sql 5000 "SELECT clock_timestamp();")
echo "$RESTORE_POINT" > "$LOG_DIR/restore_point.txt"
echo "$SAFE_TIME" > "$LOG_DIR/safe_time.txt"
echo "Restore point: $RESTORE_POINT"
echo "Mốc thời gian: $SAFE_TIME"
sleep 3
 
REPLICA_BEFORE=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
echo "Replica (cổng 5001) đang thấy số bản ghi: $REPLICA_BEFORE"
 
echo "[4] MÔ PHỎNG LỖI THAO TÁC: xóa nhầm bảng"
run_sql 5000 "DROP TABLE bank_accounts;"
echo "Đã DROP TABLE lúc: $(date -Is)"
sleep 3
 
REPLICA_AFTER=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
echo "Replica (cổng 5001) sau khi DROP: $REPLICA_AFTER"
 
echo "[5] Ép đẩy WAL chứa lệnh DROP lên MinIO và chờ xác nhận..."
WAL_FILE=$(run_sql 5000 "SELECT pg_walfile_name(pg_current_wal_lsn());")
run_sql 5000 "SELECT pg_switch_wal();" > /dev/null
ARCHIVED="f"
TRY=0
while [ "$ARCHIVED" != "t" ] && [ $TRY -lt 60 ]; do
  ARCHIVED=$(run_sql 5000 "SELECT coalesce(last_archived_wal, '') >= '$WAL_FILE' FROM pg_stat_archiver;")
  TRY=$((TRY + 1))
  sleep 1
done
 
if [ "$ARCHIVED" = "t" ]; then
  echo "WAL $WAL_FILE đã nằm trên MinIO. Sẵn sàng chạy ./scripts/restore_pitr.sh"
else
  echo "CẢNH BÁO: chưa thấy WAL được archive sau 60 giây. Kiểm tra pgbackrest check trước khi restore."
fi
