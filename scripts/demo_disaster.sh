#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
export COMPOSE_PROFILES=backup
source "$(dirname "$0")/common.sh"

echo "[1] Tạo bảng bank_accounts và chèn dữ liệu..."
run_sql 5000 "DROP TABLE IF EXISTS bank_accounts; CREATE TABLE bank_accounts (account_id SERIAL PRIMARY KEY, owner_name VARCHAR(100), balance NUMERIC(15,2), updated_at TIMESTAMPTZ DEFAULT clock_timestamp());" > /dev/null
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
echo "    -> Restore point: $RESTORE_POINT"
echo "    -> Mốc thời gian: $SAFE_TIME"
sleep 2

REPLICA_BEFORE=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
echo "    -> Replica (cổng 5001) đang thấy: $REPLICA_BEFORE bản ghi"

echo "[4] MÔ PHỎNG LỖI THAO TÁC: xóa nhầm bảng (DROP TABLE)..."
run_sql 5000 "DROP TABLE bank_accounts;"
echo "    -> Đã DROP TABLE lúc: $(date -Is)"
sleep 2

REPLICA_AFTER=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
echo "    -> Replica (cổng 5001) sau khi DROP: $REPLICA_AFTER"

echo "[5] Ép đẩy WAL chứa lệnh DROP lên MinIO S3 và chờ xác nhận..."
docker exec pg-patroni-1 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true
docker exec pg-patroni-2 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true
WAL_FILE=$(run_sql 5000 "SELECT pg_walfile_name(pg_current_wal_lsn());")
run_sql 5000 "SELECT pg_switch_wal();" > /dev/null
echo "    -> File WAL cần đẩy: $WAL_FILE"

ARCHIVED="f"
TRY=0
while [ "$ARCHIVED" != "t" ] && [ $TRY -lt 60 ]; do
  TRY=$((TRY + 1))
  LAST_WAL=$(run_sql 5000 "SELECT coalesce(last_archived_wal, 'đang xử lý') FROM pg_stat_archiver;" 2>/dev/null || echo "đang thử")
  printf "    >> [Đang đẩy WAL lên MinIO: %2ds/60s] Đã archive đến: %-30s\r" "$TRY" "$LAST_WAL"
  ARCHIVED=$(run_sql 5000 "SELECT coalesce(last_archived_wal, '') >= '$WAL_FILE' FROM pg_stat_archiver;" 2>/dev/null || echo "f")
  if [ "$ARCHIVED" = "t" ]; then
    echo ""
    echo "    -> XÁC NHẬN THÀNH CÔNG: WAL $WAL_FILE đã nằm an toàn trên MinIO S3! (sau ${TRY}s)"
    break
  fi
  sleep 1
done

if [ "$ARCHIVED" = "t" ]; then
  echo ""
  echo ">>> THẢM HỌA ĐÃ ĐƯỢC TẠO XONG VÀ LƯU TRỮ AN TOÀN TRÊN MINIO."
  echo "    Sẵn sàng chuyển sang bước phục hồi PITR (scripts/restore_pitr.sh)"
else
  echo ""
  echo "CẢNH BÁO: chưa thấy WAL được archive sau 60 giây. Kiểm tra pgbackrest check trước khi restore."
fi
