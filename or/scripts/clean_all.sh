#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
 
echo "=== DỪNG VÀ XÓA TOÀN BỘ CỤM CONTAINER & NAMED VOLUMES ==="
docker compose down -v --remove-orphans
rm -rf certs/*.key certs/*.crt scripts/logs/*
echo "Đã dọn dẹp sạch sẽ toàn bộ môi trường!"
