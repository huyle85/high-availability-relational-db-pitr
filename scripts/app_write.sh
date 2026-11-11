#!/bin/bash
export PGPASSWORD=postgrespassword
export PGCONNECT_TIMEOUT=2
export PGOPTIONS="-c statement_timeout=5000"
 
HOST="haproxy"
PORT=5000
LOG_DIR=/scripts/logs
ACK_FILE="$LOG_DIR/acked_codes.txt"
EVENT_FILE="$LOG_DIR/write_events.log"
 
mkdir -p "$LOG_DIR"
: > "$ACK_FILE"
: > "$EVENT_FILE"
 
until psql -h $HOST -p $PORT -U postgres -d postgres -q -c "CREATE TABLE IF NOT EXISTS orders_stream (id BIGSERIAL PRIMARY KEY, order_code TEXT UNIQUE NOT NULL, created_at TIMESTAMPTZ DEFAULT clock_timestamp());" 2>/dev/null; do
  echo "Chờ cụm sẵn sàng..."
  sleep 2
done
 
echo "=== BẮT ĐẦU GHI LIÊN TỤC QUA HAPROXY CỔNG $PORT ==="
COUNTER=1
LAST_OK_MS=0
IN_OUTAGE=0
FAIL_COUNT=0
 
while true; do
  ORDER_CODE="ORDER_$COUNTER"
  START_MS=$(date +%s%3N)
  OUTPUT=$(psql -h $HOST -p $PORT -U postgres -d postgres -t -A -c "INSERT INTO orders_stream (order_code) VALUES ('$ORDER_CODE') ON CONFLICT (order_code) DO NOTHING RETURNING id;" 2>&1)
  STATUS=$?
  END_MS=$(date +%s%3N)
  LATENCY=$((END_MS - START_MS))
 
  if [ $STATUS -eq 0 ]; then
    if [ $IN_OUTAGE -eq 1 ]; then
      RTO_MS=$((END_MS - LAST_OK_MS))
      echo "=========================================================="
      echo ">>> GHI ĐƯỢC TRỞ LẠI. Gián đoạn nhìn từ ứng dụng: ${RTO_MS} ms (${FAIL_COUNT} lần thử lỗi) <<<"
      echo "=========================================================="
      echo "$(date -Is) RTO_MS=$RTO_MS FAILED_ATTEMPTS=$FAIL_COUNT" >> "$EVENT_FILE"
      IN_OUTAGE=0
      FAIL_COUNT=0
    fi
    echo "$ORDER_CODE" >> "$ACK_FILE"
    LAST_OK_MS=$END_MS
    echo "[OK] $ORDER_CODE đã commit, id=$OUTPUT, độ trễ ${LATENCY}ms"
    COUNTER=$((COUNTER + 1))
  else
    IN_OUTAGE=1
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[GIÁN ĐOẠN] $ORDER_CODE chưa ghi được, đang chờ Leader mới..."
  fi
  sleep 0.2
done
