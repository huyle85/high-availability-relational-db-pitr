#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p certs
 
# Tìm openssl nếu không có sẵn trực tiếp trong PATH
OPENSSL_BIN="openssl"
if ! command -v openssl >/dev/null 2>&1; then
  if [ -f "/c/Program Files/Git/usr/bin/openssl.exe" ]; then
    OPENSSL_BIN="/c/Program Files/Git/usr/bin/openssl.exe"
  elif [ -f "C:/Program Files/Git/usr/bin/openssl.exe" ]; then
    OPENSSL_BIN="C:/Program Files/Git/usr/bin/openssl.exe"
  fi
fi
 
"$OPENSSL_BIN" req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout certs/private.key -out certs/public.crt \
  -subj "/CN=minio" \
  -addext "subjectAltName=DNS:minio,DNS:localhost,IP:127.0.0.1"
 
chmod 644 certs/private.key certs/public.crt
echo "Đã tạo certs/public.crt và certs/private.key"
