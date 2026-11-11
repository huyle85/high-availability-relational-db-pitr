#!/bin/bash
export PGPASSWORD=postgrespassword
export PGCONNECT_TIMEOUT=2
 
HOST="haproxy"
 
while true; do
  PRIMARY_MAX=$(psql -h $HOST -p 5000 -U postgres -d postgres -t -A -c "SELECT coalesce(max(id), 0) FROM orders_stream;" 2>/dev/null)
  REPLICA_MAX=$(psql -h $HOST -p 5001 -U postgres -d postgres -t -A -c "SELECT coalesce(max(id), 0) FROM orders_stream;" 2>/dev/null)
 
  if [[ "$PRIMARY_MAX" =~ ^[0-9]+$ ]] && [[ "$REPLICA_MAX" =~ ^[0-9]+$ ]]; then
    DIFF=$((PRIMARY_MAX - REPLICA_MAX))
    echo "[ĐỌC] Primary max id=$PRIMARY_MAX | Replica max id=$REPLICA_MAX | Replica đang chậm $DIFF bản ghi"
  else
    echo "[ĐỌC] primary='$PRIMARY_MAX' replica='$REPLICA_MAX' (một trong hai cổng chưa sẵn sàng)"
  fi
  sleep 1
done
