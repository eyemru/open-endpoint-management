#!/usr/bin/env bash
# Produce a TLS cert for the given hostname(s) into /etc/epm/certs/<name>/.
# Honors CERT_MODE from config.env: letsencrypt | byo | selfsigned.
# Usage (as root):  CERT_MODE=... ./get-cert.sh <name> <domain1> [domain2 ...]
set -euo pipefail
NAME="${1:?cert name}"; shift
DOMAINS=("$@"); [ "${#DOMAINS[@]}" -ge 1 ] || { echo "need >=1 domain"; exit 1; }
OUT="/etc/epm/certs/$NAME"; mkdir -p "$OUT"
MODE="${CERT_MODE:-letsencrypt}"
export DEBIAN_FRONTEND=noninteractive

case "$MODE" in
  letsencrypt)
    command -v certbot >/dev/null || apt-get install -y certbot
    args=(); for d in "${DOMAINS[@]}"; do args+=(-d "$d"); done
    echo ">>> Let's Encrypt (HTTP-01) for: ${DOMAINS[*]}  (port 80 must be reachable)"
    certbot certonly --standalone --non-interactive --agree-tos -m "${LE_EMAIL:?set LE_EMAIL}" \
      --preferred-challenges http --cert-name "$NAME" "${args[@]}"
    cp -L "/etc/letsencrypt/live/$NAME/fullchain.pem" "$OUT/fullchain.pem"
    cp -L "/etc/letsencrypt/live/$NAME/privkey.pem"  "$OUT/privkey.pem"
    ;;
  byo)
    : "${CERT_FULLCHAIN:?set CERT_FULLCHAIN}"; : "${CERT_PRIVKEY:?set CERT_PRIVKEY}"
    echo ">>> Using bring-your-own cert: $CERT_FULLCHAIN"
    cp "$CERT_FULLCHAIN" "$OUT/fullchain.pem"; cp "$CERT_PRIVKEY" "$OUT/privkey.pem"
    openssl x509 -in "$OUT/fullchain.pem" -noout >/dev/null || { echo "invalid cert"; exit 1; }
    ;;
  selfsigned)
    command -v openssl >/dev/null || apt-get install -y openssl
    san=""; for d in "${DOMAINS[@]}"; do san+="DNS:$d,"; done; san="${san%,}"
    echo ">>> Self-signed (LAB ONLY) for: ${DOMAINS[*]}"
    openssl req -x509 -newkey rsa:4096 -nodes -days 825 \
      -keyout "$OUT/privkey.pem" -out "$OUT/fullchain.pem" \
      -subj "/CN=${DOMAINS[0]}" -addext "subjectAltName=$san" >/dev/null 2>&1
    echo "!!! Self-signed: install $OUT/fullchain.pem as trusted on every endpoint, or agents will refuse TLS."
    ;;
  *) echo "unknown CERT_MODE='$MODE'"; exit 1 ;;
esac

chmod 644 "$OUT/fullchain.pem"; chmod 600 "$OUT/privkey.pem"
echo ">>> cert ready: $OUT/{fullchain,privkey}.pem"
