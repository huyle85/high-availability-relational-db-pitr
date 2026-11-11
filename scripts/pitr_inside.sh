#!/bin/bash
set -e
mkdir -p /etc/pgbackrest/conf.d
printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf
export PGBACKREST_REPO1_STORAGE_VERIFY_TLS=n
export TZ='ICT-7'
MODE="$1"
TARGET="$2"
DATA=/var/lib/postgresql/data/patroni
CHECK_QUERY="SELECT count(*) || '|' || sum(balance) || '|' || md5(string_agg(owner_name || balance::text, ',' ORDER BY account_id)) FROM bank_accounts;"

echo "pgBackRest restore: type=$MODE target=$TARGET"
pgbackrest --stanza=demo --delta --type="$MODE" --target="$TARGET" --target-action=promote restore

echo "Khởi động PostgreSQL tạm thời (không qua Patroni) để replay WAL..."
if ! pg_ctl start -D "$DATA" -w -t 600 -l /tmp/pitr_postgres.log; then
  tail -n 50 /tmp/pitr_postgres.log
  exit 1
fi

TRY=0
until [ "$(psql -U postgres -d postgres -At -c 'SELECT pg_is_in_recovery()')" = "f" ]; do
  TRY=$((TRY + 1))
  printf "    >> [Đang replay WAL tới mốc an toàn: lần kiểm tra %d] ...\r" "$TRY"
  if ! pg_ctl status -D "$DATA" > /dev/null; then
    echo ""
    echo "PostgreSQL đã dừng trong lúc recovery:"
    tail -n 50 /tmp/pitr_postgres.log
    exit 1
  fi
  if [ $TRY -gt 150 ]; then
    echo ""
    echo "Quá thời gian chờ recovery kết thúc:"
    tail -n 50 /tmp/pitr_postgres.log
    exit 1
  fi
  sleep 2
done
echo ""
echo "    -> Replay WAL hoàn tất! PostgreSQL đã thoát khỏi chế độ recovery."

BEFORE=$(cat /scripts/logs/before.txt 2>/dev/null || echo "")
AFTER=$(psql -U postgres -d postgres -At -c "$CHECK_QUERY" 2>/dev/null || echo "")
echo "Checksum trước thảm họa : $BEFORE"
echo "Checksum sau phục hồi   : $AFTER"
if [ "$BEFORE" = "$AFTER" ] && [ -n "$BEFORE" ]; then
  echo "KẾT QUẢ: KHỚP 100%"
else
  echo "KẾT QUẢ: KHÔNG KHỚP"
fi
psql -U postgres -d postgres -c "SELECT account_id, owner_name, balance FROM bank_accounts ORDER BY account_id;"

psql -U postgres -d postgres -c "ALTER SYSTEM RESET ALL;"
pg_ctl stop -D "$DATA" -m fast -w
echo "Đã dừng PostgreSQL tạm thời. Dữ liệu sẵn sàng để Patroni tiếp quản."
