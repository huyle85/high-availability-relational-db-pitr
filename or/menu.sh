#!/bin/bash
# ==============================================================================
# BANG DIEU KHIEN DEMO DE TAI 13: CSDL SAN SANG CAO (HA) & SAO LUU PITR
# Chuan hoa 100% theo de cuong:
#   - Muc 4: Nguoi 1 (May A) - San sang cao va Failover
#   - Muc 5: Nguoi 2 (May B) - Sao luu va PITR
# Giao dien ro net, chu to thoang, tuong phan cao, khong bao gio loi font
# ==============================================================================
export MSYS_NO_PATHCONV=1
export LC_ALL=C.UTF-8 2>/dev/null || true
export LANG=C.UTF-8 2>/dev/null || true
chcp.com 65001 >/dev/null 2>&1 || true

# Xac dinh thu muc goc project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
  PROJECT_DIR="$SCRIPT_DIR"
else
  PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$PROJECT_DIR"

# Bang mau tuong phan cao (High-Contrast ANSI)
C_OFF='\033[0m'
C_BOLD='\033[1m'
C_WHITE='\033[1;37m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_RED='\033[1;31m'
C_GRAY='\033[0;90m'

VIEW_MODE="ALL"

get_current_leader() {
  for NODE in pg-patroni-1 pg-patroni-2; do
    LEADER=$(docker exec "$NODE" patronictl -c /tmp/patroni.yml list 2>/dev/null \
      | awk -F'|' '/Leader/ {gsub(/ /, "", $2); print $2}')
    if [ -n "$LEADER" ]; then
      echo "$LEADER"
      return 0
    fi
  done
  echo "Chua ket noi"
}

pause_screen() {
  echo ""
  echo -e "${C_GRAY}----------------------------------------------------------------------${C_OFF}"
  read -rp ">> Bam [Enter] de quay lai bang menu..." dummy
}

open_url() {
  URL="$1"
  if command -v start >/dev/null 2>&1; then
    start "$URL" 2>/dev/null || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" 2>/dev/null || true
  elif command -v open >/dev/null 2>&1; then
    open "$URL" 2>/dev/null || true
  else
    echo -e "Trinh duyet: $URL"
  fi
}

while true; do
  clear 2>/dev/null || echo -e "\033c"
  
  CURRENT_LEADER=$(get_current_leader)
  
  echo -e "${C_BOLD}${C_WHITE}========================================================================================${C_OFF}"
  echo -e "   ${C_BOLD}${C_GREEN}DEMO DE TAI 13: CSDL QUAN HE SAN SANG CAO (HA) & SAO LUU PHUC HOI PITR${C_OFF}"
  echo -e "   Leader hien tai: ${C_BOLD}${C_CYAN}${CURRENT_LEADER}${C_OFF}   |   HAProxy: ${C_BOLD}${C_YELLOW}5000 (Ghi) / 5001 (Doc)${C_OFF}"
  echo -e "${C_BOLD}${C_WHITE}========================================================================================${C_OFF}"

  if [ "$VIEW_MODE" = "ALL" ]; then
    echo -e "   ${C_GRAY}Che do: [TAT CA]   (Go ${C_BOLD}a${C_GRAY} de xem Nguoi 1 | Go ${C_BOLD}b${C_GRAY} de xem Nguoi 2)${C_OFF}"
  elif [ "$VIEW_MODE" = "HA" ]; then
    echo -e "   ${C_BOLD}${C_CYAN}>>> CHUYEN DE: MUC 4 - NGUOI 1 (MAY A) : SAN SANG CAO VA FAILOVER <<<${C_OFF}"
    echo -e "   ${C_GRAY}(Go ${C_BOLD}all${C_GRAY} de xem lai tat ca cac muc)${C_OFF}"
  elif [ "$VIEW_MODE" = "PITR" ]; then
    echo -e "   ${C_BOLD}${C_GREEN}>>> CHUYEN DE: MUC 5 - NGUOI 2 (MAY B) : SAO LUU VA PHUC HOI PITR <<<${C_OFF}"
    echo -e "   ${C_GRAY}(Go ${C_BOLD}all${C_GRAY} de xem lai tat ca cac muc)${C_OFF}"
  fi
  echo -e "${C_GRAY}----------------------------------------------------------------------------------------${C_OFF}"

  # ==========================================
  # PHAN 4: NGUOI 1 (MAY A) - HA & FAILOVER
  # ==========================================
  if [ "$VIEW_MODE" = "ALL" ] || [ "$VIEW_MODE" = "HA" ]; then
    echo -e "${C_BOLD}${C_CYAN}[ MUC 4. NGUOI 1 (MAY A) : SAN SANG CAO VA FAILOVER ]${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[ 1]${C_OFF} 4.2 Khoi dong cum & Kiem tra trang thai (patronictl list)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 2]${C_OFF} 4.2 Mo Dashboard HAProxy (http://localhost:7000)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 3]${C_OFF} 4.2 Bat luong ghi lien tuc (scripts/app_write.sh - Do RTO)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 4]${C_OFF} 4.2 Giam sat replication lag moi giay (scripts/monitor_lag.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 5]${C_OFF} 4.2 Doc doi chieu Primary (5000) & Replica (5001) (scripts/app_read.sh)"
    echo -e "  ${C_BOLD}${C_YELLOW}[ 6] 4.3 Thi nghiem A: TAT EM LEADER (scripts/kill_primary.sh stop)${C_OFF}"
    echo -e "  ${C_BOLD}${C_RED}[ 7] 4.3 Thi nghiem B: CRASH THAT LEADER (scripts/kill_primary.sh crash - SIGKILL)${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[ 8]${C_OFF} 4.3 Do so giao dich bi mat sau su co (scripts/check_loss.sh - RPO)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 9]${C_OFF} 4.3 Bat lai Node cu vua bi ha (docker start -> Tu Rejoin lam Replica)"
    echo -e "  ${C_BOLD}${C_WHITE}[10]${C_OFF} 4.4 Thi nghiem C: Bat che do Bat dong bo (Async replication)"
    echo -e "  ${C_BOLD}${C_WHITE}[11]${C_OFF} 4.4 Thi nghiem C: Bat che do Dong bo (Patroni sync_mode=true)"
    echo ""
  fi

  # ==========================================
  # PHAN 5: NGUOI 2 (MAY B) - SAO LUU & PITR
  # ==========================================
  if [ "$VIEW_MODE" = "ALL" ]; then
    echo -e "${C_BOLD}${C_GREEN}[ MUC 5. NGUOI 2 (MAY B) : SAO LUU VA PHUC HOI THAM HOA PITR ]${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[12]${C_OFF} 5.1 Tao chung chi tu ky co SAN cho MinIO S3 (scripts/gen_certs.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[13]${C_OFF} 5.1 Khoi tao Stanza, check archive & Full backup (scripts/init_backup.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[14]${C_OFF} 5.1 Xem kho sao luu pgBackRest tren MinIO S3 (pgbackrest info)"
    echo -e "  ${C_BOLD}${C_WHITE}[15]${C_OFF} 5.1 Mo Web Console MinIO S3 (https://localhost:9001)"
    echo -e "  ${C_BOLD}${C_RED}[16] 5.1 KICH HOAT THAM HOA: DROP TABLE nham (scripts/demo_disaster.sh)${C_OFF}"
    echo -e "  ${C_BOLD}${C_GREEN}[17] 5.1 PHUC HOI THAM HOA: Khoi phuc PITR ve diem an toan (scripts/restore_pitr.sh)${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[18]${C_OFF} 5.1 Kiem tra toan ven sau phuc hoi (scripts/verify_after_restore.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[19]${C_OFF} 5.1 Phuc hoi PITR theo moc thoi gian Timestamp (restore_pitr.sh time)"
    echo ""
  elif [ "$VIEW_MODE" = "PITR" ]; then
    echo -e "${C_BOLD}${C_GREEN}[ MUC 5. NGUOI 2 (MAY B) : SAO LUU VA PHUC HOI THAM HOA PITR ]${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[ 1] (hoac 12)${C_OFF} 5.1 Tao chung chi tu ky co SAN cho MinIO S3 (scripts/gen_certs.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 2] (hoac 13)${C_OFF} 5.1 Khoi tao Stanza, check archive & Full backup (scripts/init_backup.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 3] (hoac 14)${C_OFF} 5.1 Xem kho sao luu pgBackRest tren MinIO S3 (pgbackrest info)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 4] (hoac 15)${C_OFF} 5.1 Mo Web Console MinIO S3 (https://localhost:9001)"
    echo -e "  ${C_BOLD}${C_RED}[ 5] (hoac 16) 5.1 KICH HOAT THAM HOA: DROP TABLE nham (scripts/demo_disaster.sh)${C_OFF}"
    echo -e "  ${C_BOLD}${C_GREEN}[ 6] (hoac 17) 5.1 PHUC HOI THAM HOA: Khoi phuc PITR ve diem an toan (scripts/restore_pitr.sh)${C_OFF}"
    echo -e "  ${C_BOLD}${C_WHITE}[ 7] (hoac 18)${C_OFF} 5.1 Kiem tra toan ven sau phuc hoi (scripts/verify_after_restore.sh)"
    echo -e "  ${C_BOLD}${C_WHITE}[ 8] (hoac 19)${C_OFF} 5.1 Phuc hoi PITR theo moc thoi gian Timestamp (restore_pitr.sh time)"
    echo ""
  fi

  # ==========================================
  # TIEN ICH VA QUAN TRI CHUNG
  # ==========================================
  echo -e "${C_BOLD}${C_YELLOW}[ TIEN ICH QUAN TRI ]${C_OFF}"
  echo -e "  ${C_BOLD}${C_WHITE}[20]${C_OFF} Reset sach se toan bo volumes/certs & Khoi tao lai tu dau"
  echo -e "  ${C_BOLD}${C_WHITE}[ 0]${C_OFF} Thoat chuong trinh"
  echo -e "${C_BOLD}${C_WHITE}========================================================================================${C_OFF}"

  read -rp ">> Nhap so lua chon [0 - 20 | a | b | all]: " raw_choice
  echo ""

  choice=$(echo "$raw_choice" | tr -d '\r\n[:space:]')

  # Xu ly cac phím tat chuyen che do
  case "$choice" in
    a|A|n1|p1|nguoi1)
      VIEW_MODE="HA"
      continue
      ;;
    b|B|n2|p2|nguoi2)
      VIEW_MODE="PITR"
      continue
      ;;
    all|ALL)
      VIEW_MODE="ALL"
      continue
      ;;
  esac

  # Neu dang o che do PITR (Nguoi 2) va bam so 1..8 thi anh xa tuong ung 12..19
  if [ "$VIEW_MODE" = "PITR" ]; then
    case "$choice" in
      1) choice="12" ;;
      2) choice="13" ;;
      3) choice="14" ;;
      4) choice="15" ;;
      5) choice="16" ;;
      6) choice="17" ;;
      7) choice="18" ;;
      8) choice="19" ;;
    esac
  fi

  case "$choice" in
    1)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.2] KIEM TRA & KHOI DONG CUM PATRONI:${C_OFF}"
      docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null \
        || docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list 2>/dev/null \
        || {
          echo "Cum chua chay. Dang khoi dong bang docker compose..."
          docker compose up -d
          sleep 5
          docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list
        }
      pause_screen
      ;;
    2)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.2] DANG MO DASHBOARD HAPROXY TREN TRINH DUYET...${C_OFF}"
      echo -e "URL: ${C_YELLOW}http://localhost:7000${C_OFF}"
      open_url "http://localhost:7000"
      sleep 1
      pause_screen
      ;;
    3)
      echo -e "${C_BOLD}${C_GREEN}>>> [4.2] BAT LUONG GHI LIEN TUC (scripts/app_write.sh)${C_OFF}"
      echo -e "${C_YELLOW}(Nhan Ctrl + C bat cu luc nao de dung ghi)${C_OFF}"
      sleep 1
      docker exec -it pg-client bash /scripts/app_write.sh
      pause_screen
      ;;
    4)
      echo -e "${C_BOLD}${C_GREEN}>>> [4.2] GIAM SAT REPLICATION LAG MOI GIAY (scripts/monitor_lag.sh)${C_OFF}"
      echo -e "${C_YELLOW}(Nhan Ctrl + C bat cu luc nao de dung giam sat)${C_OFF}"
      sleep 1
      docker exec -it pg-client bash /scripts/monitor_lag.sh
      pause_screen
      ;;
    5)
      echo -e "${C_BOLD}${C_GREEN}>>> [4.2] TAI DOC DOI CHIEU PRIMARY (5000) & REPLICA (5001) (scripts/app_read.sh)${C_OFF}"
      echo -e "${C_YELLOW}(Nhan Ctrl + C bat cu luc nao de dung doc)${C_OFF}"
      sleep 1
      docker exec -it pg-client bash /scripts/app_read.sh
      pause_screen
      ;;
    6)
      echo -e "${C_BOLD}${C_YELLOW}>>> [4.3 THI NGHIEM A] TAT EM LEADER (GRACEFUL STOP)${C_OFF}"
      bash scripts/kill_primary.sh stop
      pause_screen
      ;;
    7)
      echo -e "${C_BOLD}${C_RED}>>> [4.3 THI NGHIEM B] CRASH THAT LEADER (SIGKILL CRASH)${C_OFF}"
      bash scripts/kill_primary.sh crash
      pause_screen
      ;;
    8)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.3 BUOC 2] DO SO GIAO DICH BI MAT SAU SU CO (scripts/check_loss.sh - RPO)${C_OFF}"
      docker exec -it pg-client bash /scripts/check_loss.sh
      pause_screen
      ;;
    9)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.3 BUOC 3] BAT LAI NODE CU VA KIEM TRA REJOIN LAM REPLICA${C_OFF}"
      STOPPED_NODE=$(docker ps -a --filter "status=exited" --filter "name=pg-patroni" --format "{{.Names}}" | head -n 1)
      if [ -n "$STOPPED_NODE" ]; then
        echo -e "Dang bat lai container: ${C_YELLOW}$STOPPED_NODE${C_OFF}..."
        docker start "$STOPPED_NODE"
        echo "Cho 5 giay de Patroni khoi dong va ket noi lai cum..."
        sleep 5
      else
        echo "Khong co node pg-patroni nao dang o trang thai tat."
      fi
      echo ""
      echo "Trang thai cum Patroni hien tai:"
      docker exec pg-patroni-1 patronictl -c /tmp/patroni.yml list 2>/dev/null \
        || docker exec pg-patroni-2 patronictl -c /tmp/patroni.yml list 2>/dev/null
      pause_screen
      ;;
    10)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.4 THI NGHIEM C] CHUYEN REPLICATION SANG BAT DONG BO (ASYNC)${C_OFF}"
      LEADER=$(get_current_leader)
      if [ "$LEADER" != "Chua ket noi" ]; then
        docker exec "$LEADER" patronictl -c /tmp/patroni.yml edit-config --set synchronous_mode=false --force
        echo -e "${C_GREEN}Da chuyen cum sang che do Bat dong bo (Async).${C_OFF}"
      else
        echo -e "${C_RED}Khong tim thay Leader.${C_OFF}"
      fi
      pause_screen
      ;;
    11)
      echo -e "${C_BOLD}${C_CYAN}>>> [4.4 THI NGHIEM C] CHUYEN REPLICATION SANG DONG BO (SYNC STANDBY)${C_OFF}"
      LEADER=$(get_current_leader)
      if [ "$LEADER" != "Chua ket noi" ]; then
        docker exec "$LEADER" patronictl -c /tmp/patroni.yml edit-config --set synchronous_mode=true --force
        echo -e "${C_GREEN}Da chuyen cum sang che do Dong bo (synchronous_mode=true).${C_OFF}"
        echo "Kiem tra cot sync_state trong patronictl list hoac monitor_lag.sh de thay 'sync'."
      else
        echo -e "${C_RED}Khong tim thay Leader.${C_OFF}"
      fi
      pause_screen
      ;;
    12)
      echo -e "${C_BOLD}${C_CYAN}>>> [5.1] TAO CHUNG CHI TU KY CO SAN CHO MINIO S3 (scripts/gen_certs.sh)${C_OFF}"
      bash scripts/gen_certs.sh
      pause_screen
      ;;
    13)
      echo -e "${C_BOLD}${C_CYAN}>>> [5.1] KHOI TAO STANZA, CHECK ARCHIVE & FULL BACKUP (scripts/init_backup.sh)${C_OFF}"
      bash scripts/init_backup.sh
      pause_screen
      ;;
    14)
      echo -e "${C_BOLD}${C_CYAN}>>> [5.1] THONG TIN KHO SAO LUU PGBACKREST:${C_OFF}"
      LEADER=$(get_current_leader)
      if [ "$LEADER" != "Chua ket noi" ]; then
        docker exec "$LEADER" pgbackrest --stanza=demo info
      else
        echo -e "${C_RED}Chua co Node Leader nao dang chay.${C_OFF}"
      fi
      pause_screen
      ;;
    15)
      echo -e "${C_BOLD}${C_CYAN}>>> [5.1] DANG MO WEB CONSOLE MINIO S3 TREN TRINH DUYET...${C_OFF}"
      echo -e "URL: ${C_YELLOW}https://localhost:9001${C_OFF}"
      echo -e "User: ${C_BOLD}minioadmin${C_OFF} | Pass: ${C_BOLD}minioadmin${C_OFF}"
      open_url "https://localhost:9001"
      sleep 1
      pause_screen
      ;;
    16)
      echo -e "${C_BOLD}${C_RED}>>> [5.1] KICH HOAT THAM HOA: DROP TABLE NHAM (scripts/demo_disaster.sh)${C_OFF}"
      docker exec -it pg-client bash /scripts/demo_disaster.sh
      pause_screen
      ;;
    17)
      echo -e "${C_BOLD}${C_GREEN}>>> [5.1] TIEN HANH PHUC HOI THAM HOA PITR VE DIEM AN TOAN (scripts/restore_pitr.sh)${C_OFF}"
      bash scripts/restore_pitr.sh
      pause_screen
      ;;
    18)
      echo -e "${C_BOLD}${C_GREEN}>>> [5.1] KIEM THU TOAN VEN DU LIEU SAU PHUC HOI (scripts/verify_after_restore.sh)${C_OFF}"
      docker exec -it pg-client bash /scripts/verify_after_restore.sh
      pause_screen
      ;;
    19)
      echo -e "${C_BOLD}${C_CYAN}>>> [5.1] PHUC HOI PITR THEO MOC THOI GIAN TIMESTAMP${C_OFF}"
      if [ -f "scripts/logs/safe_time.txt" ]; then
        DEFAULT_TIME=$(cat "scripts/logs/safe_time.txt")
        echo -e "Moc thoi gian an toan gan nhat: ${C_GREEN}$DEFAULT_TIME${C_OFF}"
        read -rp "Nhap moc thoi gian PITR (Bam Enter de lay moc tren): " INPUT_TIME
        TARGET_TIME="${INPUT_TIME:-$DEFAULT_TIME}"
        echo -e "Dang phuc hoi PITR toi: $TARGET_TIME"
        bash scripts/restore_pitr.sh time "$TARGET_TIME"
      else
        read -rp "Nhap moc thoi gian (VD: 2026-11-11 08:30:15.123456+00): " TARGET_TIME
        if [ -n "$TARGET_TIME" ]; then
          bash scripts/restore_pitr.sh time "$TARGET_TIME"
        fi
      fi
      pause_screen
      ;;
    20)
      echo -e "${C_RED}CANH BAO: Thao tac nay se tat cum va xoa toan bo du lieu volumes/certs!${C_OFF}"
      read -rp "Ban co chac chan muon reset he thong khong? (y/N): " confirm
      if [[ "$confirm" =~ ^[yY]$ ]]; then
        bash scripts/clean_all.sh
        echo "Dang khoi tao lai tu dau..."
        bash scripts/run_all_setup.sh
      else
        echo "Da huy thao tac reset."
      fi
      pause_screen
      ;;
    0)
      echo -e "${C_GREEN}Cam on ban da su dung bang dieu khien! Chuc buoi bao cao thanh cong.${C_OFF}"
      exit 0
      ;;
    *)
      echo -e "${C_RED}Lua chon khong hop le: '$choice'! Vui long nhap tu 0 den 20.${C_OFF}"
      sleep 1
      ;;
  esac
done
