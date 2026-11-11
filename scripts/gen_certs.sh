#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p certs

OPENSSL_BIN="openssl"
if ! command -v openssl >/dev/null 2>&1; then
  if [ -f "/c/Program Files/Git/usr/bin/openssl.exe" ]; then
    OPENSSL_BIN="/c/Program Files/Git/usr/bin/openssl.exe"
  elif [ -f "C:/Program Files/Git/usr/bin/openssl.exe" ]; then
    OPENSSL_BIN="C:/Program Files/Git/usr/bin/openssl.exe"
  fi
fi

echo "Đang tạo chứng chỉ TLS tự ký có SAN cho MinIO S3..."

# 1. Tạo Root CA nội bộ
"$OPENSSL_BIN" req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout certs/ca.key -out certs/ca.crt \
  -subj "/CN=MinIO-Local-CA"

# 2. Tạo Private Key cho MinIO Server và CSR chứa SAN
"$OPENSSL_BIN" req -nodes -newkey rsa:2048 \
  -keyout certs/private.key -out certs/server.csr \
  -subj "/CN=minio" \
  -addext "subjectAltName=DNS:minio,DNS:localhost,IP:127.0.0.1"

# 3. Dùng Root CA ký Server Certificate chứa đầy đủ SAN
"$OPENSSL_BIN" x509 -req -days 365 \
  -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -out certs/server.crt \
  -copy_extensions copyall

# 4. Gộp Server Cert và Root CA thành public.crt chuẩn (Full Chain)
cat certs/server.crt certs/ca.crt > certs/public.crt

# Dọn dẹp file tạm
rm -f certs/server.csr certs/ca.key certs/ca.crt certs/ca.srl certs/server.crt 2>/dev/null || true
chmod 644 certs/private.key certs/public.crt 2>/dev/null || true

echo "Thành công: Đã tạo certs/public.crt và certs/private.key hợp lệ cho MinIO và pgBackRest!"
