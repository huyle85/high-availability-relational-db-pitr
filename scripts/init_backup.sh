#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
export TZ='ICT-7'
source "$(dirname "$0")/common.sh"
 
LEADER=$(get_leader)
echo "Node Leader hiện tại: $LEADER"

# Đảm bảo các node container sử dụng múi giờ Việt Nam (ICT / UTC+7) để tên thư mục backup và log chuẩn Giờ VN
docker exec -u 0 "$LEADER" ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime 2>/dev/null || true
docker exec -u 0 pg-patroni-1 ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime 2>/dev/null || true
docker exec -u 0 pg-patroni-2 ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime 2>/dev/null || true
docker exec -u 0 minio ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime 2>/dev/null || true
 
echo "[1] Tạo stanza trên MinIO S3..."
docker exec -e TZ=Asia/Ho_Chi_Minh "$LEADER" pgbackrest --stanza=demo stanza-create
 
echo "[2] Kiểm tra archive WAL và kết nối kho lưu trữ..."
docker exec -e TZ=Asia/Ho_Chi_Minh "$LEADER" pgbackrest --stanza=demo check
 
echo "[3] Full backup đầu tiên (đặt tên thư mục và log theo Giờ Việt Nam)..."
docker exec -e TZ=Asia/Ho_Chi_Minh "$LEADER" pgbackrest --stanza=demo --type=full backup
 
echo "[4] Thông tin backup (Giờ Việt Nam +07):"
docker exec -e TZ=Asia/Ho_Chi_Minh "$LEADER" pgbackrest --stanza=demo info
