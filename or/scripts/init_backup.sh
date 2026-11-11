#!/bin/bash
set -e
source "$(dirname "$0")/common.sh"
 
LEADER=$(get_leader)
echo "Node Leader hiện tại: $LEADER"
 
echo "[1] Tạo stanza trên MinIO S3..."
docker exec "$LEADER" pgbackrest --stanza=demo stanza-create
 
echo "[2] Kiểm tra archive WAL và kết nối kho lưu trữ..."
docker exec "$LEADER" pgbackrest --stanza=demo check
 
echo "[3] Full backup đầu tiên..."
docker exec "$LEADER" pgbackrest --stanza=demo --type=full backup
 
echo "[4] Thông tin backup:"
docker exec "$LEADER" pgbackrest --stanza=demo info
