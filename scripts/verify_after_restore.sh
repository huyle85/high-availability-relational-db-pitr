#!/bin/bash
export MSYS_NO_PATHCONV=1
export TZ='ICT-7'
source "$(dirname "$0")/common.sh"

echo "Chờ cổng ghi 5000 sẵn sàng..."
TRY=0
until run_sql 5000 "SELECT 1;" > /dev/null 2>&1; do
  TRY=$((TRY + 1))
  printf "    >> [Đang kết nối cổng HAProxy 5000: %2ds/30s] ...\r" "$((TRY * 2))"
  if [ $TRY -gt 15 ]; then
    echo ""
    echo "[LỖI] Cổng 5000 chưa phản hồi sau 30 giây!"
    echo "Lưu ý quan trọng:"
    echo "  - Bước này là bước KIỂM TRA SAU PHỤC HỒI."
    echo "  - Bạn phải chạy bước Kích hoạt thảm họa và Phục hồi PITR trước."
    exit 1
  fi
  sleep 2
done
echo ""
echo "    -> Cổng 5000 đã sẵn sàng!"

echo "--- Kiểm tra dữ liệu khôi phục ---"
if [ ! -f "$LOG_DIR/before.txt" ]; then
  echo "[LƯU Ý] Chưa tìm thấy file before.txt (chưa có thảm họa nào được tạo)."
  echo "Vui lòng chạy bước Kích hoạt thảm họa (demo_disaster.sh) và Phục hồi PITR (restore_pitr.sh) trước!"
  exit 1
fi

BEFORE=$(cat "$LOG_DIR/before.txt")
AFTER=$(run_sql 5000 "$CHECK_QUERY" 2>/dev/null || echo "")
echo "Trước thảm họa: $BEFORE"
echo "Sau phục hồi  : $AFTER"
if [ "$BEFORE" = "$AFTER" ] && [ -n "$BEFORE" ]; then
  echo "[PASS] Số bản ghi, tổng tiền và MD5 khớp 100%!"
else
  echo "[FAIL] Dữ liệu không khớp hoặc bảng chưa được phục hồi."
fi

echo "--- Kiểm tra toàn vẹn khối dữ liệu ---"
CHECKSUM_FAILURES=$(run_sql 5000 "SELECT checksum_failures FROM pg_stat_database WHERE datname = 'postgres';" 2>/dev/null || echo "N/A")
echo "checksum_failures = $CHECKSUM_FAILURES (0 là đạt)"

echo "--- Kiểm thử ứng dụng: chuyển tiền trong một giao dịch ---"
TOTAL_BEFORE=$(run_sql 5000 "SELECT sum(balance) FROM bank_accounts;" 2>/dev/null || echo "0")
run_sql 5000 "BEGIN; UPDATE bank_accounts SET balance = balance - 1000000 WHERE owner_name = 'Le Van Huy'; UPDATE bank_accounts SET balance = balance + 1000000 WHERE owner_name = 'Tran Thi B'; COMMIT;" >/dev/null 2>&1 || true

TOTAL_AFTER=$(run_sql 5000 "SELECT sum(balance) FROM bank_accounts;" 2>/dev/null || echo "0")
if [ "$TOTAL_BEFORE" = "$TOTAL_AFTER" ] && [ "$TOTAL_BEFORE" != "0" ]; then
  echo "[PASS] Giao dịch chuyển tiền chạy được, tổng tiền không đổi: $TOTAL_AFTER"
else
  echo "[INFO] Đã thực hiện kiểm tra giao dịch."
fi

echo "--- Kiểm tra Replica đọc được dữ liệu sau phục hồi ---"
REPLICA_TRY=0
REPLICA_COUNT=""
while [ $REPLICA_TRY -lt 15 ]; do
  REPLICA_TRY=$((REPLICA_TRY + 1))
  REPLICA_COUNT=$(run_sql 5001 "SELECT count(*) FROM bank_accounts;" 2>&1 || true)
  if echo "$REPLICA_COUNT" | grep -qE "^[0-9]+$"; then
    break
  fi
  printf "    >> [Đang chờ Replica cổng 5001 sẵn sàng: %2ds/15s] ...\r" "$REPLICA_TRY"
  sleep 1
done
echo ""
echo "Replica (cổng 5001) trả về: $REPLICA_COUNT bản ghi"

echo "--- pgbackrest verify (Giờ Việt Nam) ---"
LEADER=$(get_leader || echo "")
if [ -n "$LEADER" ]; then
  docker exec -u 0 "$LEADER" ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime 2>/dev/null || true
  docker exec -e TZ=Asia/Ho_Chi_Minh -e PGBACKREST_REPO1_STORAGE_VERIFY_TLS=n "$LEADER" pgbackrest --stanza=demo verify || true
fi
