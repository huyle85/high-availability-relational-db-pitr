#!/bin/bash
export MSYS_NO_PATHCONV=1
export COMPOSE_PROFILES=backup
export BACKUP_MODE=on
export TZ='ICT-7'
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
source "$PROJECT_DIR/scripts/common.sh"

get_current_leader() {
  get_leader 2>/dev/null || echo "Chua ket noi"
}

pause_screen() {
  echo ""
  echo "----------------------------------------------------------------------"
  read -rp ">> Bam [Enter] de quay lai bang menu..." _dummy
}

while true; do
  clear 2>/dev/null || printf "\033c"
  LEADER_INFO=$(get_current_leader)
  VN_TIME=$(date '+%Y-%m-%d %H:%M:%S (%Z)')

  echo "========================================================================================"
  echo "   DEMO DE TAI 13: CSDL QUAN HE SAN SANG CAO (HA) & SAO LUU PHUC HOI PITR"
  echo "   PHAN DANH CHO: NGUOI 2 (MAY B) - SAO LUU VA PHUC HOI THAM HOA PITR"
  echo "   Leader hien tai: $LEADER_INFO   |   HAProxy: 5000 (Ghi) / 5001 (Doc)"
  echo "   Gio Viet Nam   : $VN_TIME"
  echo "========================================================================================"
  echo "[ QUY TRINH SAO LUU VA PHUC HOI THAM HOA PITR (MUC 5) ]"
  echo "  [ 1] 5.1 Tao chung chi tu ky co SAN cho MinIO S3 (scripts/gen_certs.sh)"
  echo "  [ 2] 5.1 Khoi tao Stanza, check archive & Full backup (scripts/init_backup.sh)"
  echo "  [ 3] 5.1 Xem kho sao luu pgBackRest tren MinIO S3 (pgbackrest info)"
  echo "  [ 4] 5.1 Mo Web Console MinIO S3 (https://localhost:9001)"
  echo "  [ 5] 5.1 KICH HOAT THAM HOA: DROP TABLE nham (scripts/demo_disaster.sh)"
  echo "  [ 6] 5.1 PHUC HOI THAM HOA: Khoi phuc PITR ve diem an toan (scripts/restore_pitr.sh)"
  echo "  [ 7] 5.1 Kiem tra toan ven sau phuc hoi (scripts/verify_after_restore.sh)"
  echo "  [ 8] 5.1 Phuc hoi PITR theo moc thoi gian Timestamp (restore_pitr.sh time)"
  echo ""
  echo "[ TIEN ICH QUAN TRI ]"
  echo "  [ 9] Khoi dong cum & Kiem tra trang thai (patronictl list)"
  echo "  [10] Reset sach se toan bo volumes/certs & Khoi tao lai tu dau (clean_all.sh)"
  echo "  [ 0] Thoat chuong trinh"
  echo "========================================================================================"
  read -rp ">> Nhap so lua chon [0 - 10]: " RAW_CHOICE
  CHOICE=$(echo "$RAW_CHOICE" | tr -d '\r\n[:space:]')

  case "$CHOICE" in
    1)
      echo ""
      echo ">>> [5.1] TAO CHUNG CHI TLS CHO MINIO S3 (scripts/gen_certs.sh)"
      bash scripts/gen_certs.sh
      pause_screen
      ;;
    2)
      echo ""
      echo ">>> [5.1] KHOI TAO STANZA VA FULL BACKUP (scripts/init_backup.sh)"
      docker exec pg-patroni-1 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true
      docker exec pg-patroni-2 bash -c "mkdir -p /etc/pgbackrest/conf.d && printf '[global]\nrepo1-storage-verify-tls=n\n' > /etc/pgbackrest/conf.d/tls.conf" 2>/dev/null || true
      bash scripts/init_backup.sh
      pause_screen
      ;;
    3)
      echo ""
      echo ">>> [5.1] THONG TIN KHO SAO LUU PGBACKREST (pgbackrest info)"
      LEADER=$(get_leader || echo "")
      if [ -n "$LEADER" ]; then
        docker exec -e PGBACKREST_REPO1_STORAGE_VERIFY_TLS=n "$LEADER" pgbackrest --stanza=demo info
      else
        echo "[LỖI] Chưa tìm thấy node Leader. Hãy kiểm tra trạng thái cụm bằng mục [9]!"
      fi
      pause_screen
      ;;
    4)
      echo ""
      echo ">>> [5.1] MO TRINH DUYET VAO MINIO WEB CONSOLE"
      echo "URL: https://localhost:9001"
      echo "Tai khoan / Mat khau mac dinh: minioadmin / minioadmin"
      if command -v start >/dev/null 2>&1; then
        start https://localhost:9001 2>/dev/null || true
      elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open https://localhost:9001 2>/dev/null || true
      elif command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c start https://localhost:9001 2>/dev/null || true
      fi
      pause_screen
      ;;
    5)
      echo ""
      echo ">>> [5.1] KICH HOAT THAM HOA: DROP TABLE NHAM (scripts/demo_disaster.sh)"
      bash scripts/demo_disaster.sh
      pause_screen
      ;;
    6)
      echo ""
      echo ">>> [5.1] PHUC HOI THAM HOA PITR (scripts/restore_pitr.sh)"
      bash scripts/restore_pitr.sh
      pause_screen
      ;;
    7)
      echo ""
      echo ">>> [5.1] KIEM THU TOAN VEN DU LIEU SAU PHUC HOI (scripts/verify_after_restore.sh)"
      bash scripts/verify_after_restore.sh
      pause_screen
      ;;
    8)
      echo ""
      echo ">>> [5.1] PHUC HOI PITR THEO MOC THOI GIAN TIMESTAMP (GIO VIET NAM)"
      DEFAULT_TS=""
      if [ -f "$LOG_DIR/safe_time.txt" ]; then
        DEFAULT_TS=$(cat "$LOG_DIR/safe_time.txt")
      fi
      echo "Moc thoi gian an toan da luu (Gio VN): $DEFAULT_TS"
      read -rp "Nhap timestamp [Bam Enter de dung '$DEFAULT_TS']: " USER_TS
      USER_TS=$(echo "$USER_TS" | tr -d '\r\n')
      FINAL_TS="${USER_TS:-$DEFAULT_TS}"
      if [ -z "$FINAL_TS" ]; then
        echo "[LỖI] Ban chua nhap timestamp va chua co file safe_time.txt!"
      else
        bash scripts/restore_pitr.sh time "$FINAL_TS"
      fi
      pause_screen
      ;;
    9)
      echo ""
      echo ">>> KHOI DONG CUM & KIEM TRA TRANG THAI PATRONI"
      docker compose up -d
      sleep 2
      LEADER=$(get_leader || echo "")
      if [ -n "$LEADER" ]; then
        docker exec "$LEADER" patronictl -c /tmp/patroni.yml list
      else
        docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null || docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list 2>/dev/null || echo "[LỖI] Chua ket noi duoc den node Patroni."
      fi
      pause_screen
      ;;
    10)
      echo ""
      echo "======================================================================"
      echo "[CANH BAO QUAN TRONG] LUA CHON RESET SACH SE TOAN BO MOI TRUONG"
      echo "Thao tac nay se:"
      echo "  1. Xoa toan bo container va named volumes (etcd, pg1_data, pg2_data, minio_data)"
      echo "  2. Xoa toan bo chung chi trong certs/ va lich su trong scripts/logs/"
      echo "  3. Khoi tao cum moi hoan toan tu dau va tao lai Full Backup"
      echo "======================================================================"
      read -rp "Ban co CHAC CHAN muon reset sach se khong? [y/N]: " RAW_CONFIRM
      CONFIRM=$(echo "$RAW_CONFIRM" | tr -d '\r\n[:space:]')
      if [[ "$CONFIRM" =~ ^[yY]|co|yes$ ]]; then
        echo ""
        echo ">>> [1/2] Dang tien hanh don dep toan bo..."
        bash scripts/clean_all.sh
        echo ""
        echo ">>> [2/2] Dang khoi tao lai toan bo moi truong tu dau..."
        bash scripts/run_all_setup.sh
      else
        echo "-> Da HUY thao tac reset. Du lieu giu nguyen!"
      fi
      pause_screen
      ;;
    0)
      echo ""
      echo "Tam biet!"
      exit 0
      ;;
    *)
      echo ""
      echo "[LỖI] Lua chon khong hop le: '$RAW_CHOICE'. Vui long nhap so tu 0 den 10."
      pause_screen
      ;;
  esac
done
