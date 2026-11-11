#!/bin/bash
export PGPASSWORD=postgrespassword
LOG_DIR=/scripts/logs
 
psql -h haproxy -p 5000 -U postgres -d postgres -t -A -c "SELECT order_code FROM orders_stream;" | LC_ALL=C sort > "$LOG_DIR/db_codes.txt"
LC_ALL=C sort "$LOG_DIR/acked_codes.txt" > "$LOG_DIR/acked_sorted.txt"
LC_ALL=C comm -23 "$LOG_DIR/acked_sorted.txt" "$LOG_DIR/db_codes.txt" > "$LOG_DIR/lost_codes.txt"
 
ACKED=$(wc -l < "$LOG_DIR/acked_sorted.txt")
IN_DB=$(wc -l < "$LOG_DIR/db_codes.txt")
LOST=$(wc -l < "$LOG_DIR/lost_codes.txt")
 
echo "Số giao dịch đã được xác nhận cho ứng dụng : $ACKED"
echo "Số bản ghi hiện có trên Leader mới         : $IN_DB"
echo "Số giao dịch đã xác nhận nhưng bị mất (RPO) : $LOST"
if [ "$LOST" -gt 0 ]; then
  echo "Danh sách mất (tối đa 10 dòng đầu):"
  head -n 10 "$LOG_DIR/lost_codes.txt"
fi
