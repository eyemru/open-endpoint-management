#!/usr/bin/env bash
# Obtain a Let's Encrypt SAN certificate (HTTP-01) for the Tactical RMM hostnames.
# Runs as root via SSM. Requires: port 80 open to the internet and the four names
# already resolving to this host (DuckDNS wildcard).
#
# Why HTTP-01 (not the installer's wildcard DNS-01): HTTP-01 is fully non-interactive
# and needs no DuckDNS API token. The resulting SAN cert covers exactly the hostnames
# Tactical RMM serves, which is all `--use-own-cert` needs.
set -euo pipefail

EMAIL="${LE_EMAIL:-m.ephrem@gmail.com}"
ROOT="${TRMM_ROOT:-nbcepm.duckdns.org}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y certbot

certbot certonly --standalone --non-interactive --agree-tos -m "$EMAIL" \
  --preferred-challenges http --cert-name trmm \
  -d "api.${ROOT}" -d "rmm.${ROOT}" -d "mesh.${ROOT}" -d "${ROOT}"

echo "---- cert lineage ----"
ls -l /etc/letsencrypt/live/trmm/
echo "---- SAN names ----"
openssl x509 -in /etc/letsencrypt/live/trmm/fullchain.pem -noout -text \
  | grep -A1 "Subject Alternative Name"
