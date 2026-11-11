#!/bin/bash
export PGPASSWORD=postgrespassword
export PGCONNECT_TIMEOUT=2
 
LAG_FILE=/scripts/logs/lag.csv
mkdir -p /scripts/logs
echo "time,replica,state,sync_state,lag_bytes,replay_lag_seconds" > "$LAG_FILE"
 
while true; do
  RESULT=$(psql -h haproxy -p 5000 -U postgres -d postgres -t -A -F',' -c "SELECT application_name, state, sync_state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)::bigint, coalesce(round(extract(epoch FROM replay_lag)::numeric, 3), 0) FROM pg_stat_replication;" 2>/dev/null)
  NOW=$(date -Is)
  if [ -n "$RESULT" ]; then
    echo "$RESULT" | while read -r LINE; do
      echo "$NOW,$LINE" | tee -a "$LAG_FILE"
    done
  else
    echo "$NOW,không có replica đang kết nối"
  fi
  sleep 1
done
