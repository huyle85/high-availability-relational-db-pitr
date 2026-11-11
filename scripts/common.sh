#!/bin/bash
export MSYS_NO_PATHCONV=1
export TZ='ICT-7'
 
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/scripts/logs"
mkdir -p "$LOG_DIR"
 
CHECK_QUERY="SELECT count(*) || '|' || sum(balance) || '|' || md5(string_agg(owner_name || balance::text, ',' ORDER BY account_id)) FROM bank_accounts;"
 
run_sql() {
  PORT="$1"
  QUERY="$2"
  docker exec -i -e PGPASSWORD=postgrespassword pg-client \
    psql -h haproxy -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -At -c "$QUERY"
}
 
run_sql_table() {
  PORT="$1"
  QUERY="$2"
  docker exec -i -e PGPASSWORD=postgrespassword pg-client \
    psql -h haproxy -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -c "$QUERY"
}
 
get_leader() {
  for NODE in pg-patroni-1 pg-patroni-2; do
    LEADER=$(docker exec "$NODE" patronictl -c /tmp/patroni.yml list 2>/dev/null \
      | awk -F'|' '/Leader/ {gsub(/ /, "", $2); print $2}')
    if [ -n "$LEADER" ]; then
      echo "$LEADER"
      return 0
    fi
  done
  return 1
}
