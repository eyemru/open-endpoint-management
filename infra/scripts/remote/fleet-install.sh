#!/usr/bin/env bash
# Unattended FleetDM install, run ON the box via SSM (as root).
# Stack: Docker Compose (MySQL + Redis + Fleet) with Let's Encrypt TLS (HTTP-01),
# admin + compliance policies via fleetctl, and a signed fleetd MSI served on :80.
#
# Required env (passed by fleet-deploy.sh):
#   FLEET_HOSTNAME      e.g. 54.71.223.118.sslip.io
#   FLEET_ADMIN_EMAIL, FLEET_ADMIN_PASS (>=12 chars), FLEET_ORG
#   LE_EMAIL            Let's Encrypt registration email
#   FLEET_POLICIES_B64  base64 of fleet-policies.yml
set -uo pipefail
export HOME=/root          # pin so fleetctl always uses /root/.fleet/config
mkdir -p /opt/fleet/dl
exec > >(tee /opt/fleet/install.log) 2>&1

: "${FLEET_HOSTNAME:?}"; : "${FLEET_ADMIN_EMAIL:?}"; : "${FLEET_ADMIN_PASS:?}"
FLEET_ORG="${FLEET_ORG:-Northbridge}"
LE_EMAIL="${LE_EMAIL:-$FLEET_ADMIN_EMAIL}"
export DEBIAN_FRONTEND=noninteractive
H="$FLEET_HOSTNAME"

echo ">>> [1/9] packages (docker, certbot, jq) $(date -u)"
apt-get update -y -q
apt-get install -y certbot ca-certificates curl jq
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

echo ">>> [2/9] TLS cert for ${H} (HTTP-01)"
[ -d /etc/letsencrypt/live/fleet ] || certbot certonly --standalone --non-interactive \
  --agree-tos -m "$LE_EMAIL" --preferred-challenges http --cert-name fleet -d "$H"
install -d /opt/fleet/certs
cp -L /etc/letsencrypt/live/fleet/fullchain.pem /opt/fleet/certs/fullchain.pem
cp -L /etc/letsencrypt/live/fleet/privkey.pem  /opt/fleet/certs/privkey.pem
# Fleet container runs as non-root: the key MUST be readable by it.
chmod 0644 /opt/fleet/certs/fullchain.pem /opt/fleet/certs/privkey.pem

echo ">>> [3/9] hairpin: resolve the public name to localhost ON the box"
# The EIP does not hairpin from inside the instance, so point the name at 127.0.0.1
# locally (cert still valid for the name) so healthz/fleetctl work on the box.
grep -q " ${H}\$" /etc/hosts || echo "127.0.0.1 ${H}" >> /etc/hosts

echo ">>> [4/9] compose + secrets"
MYSQL_ROOT="$(openssl rand -hex 16)"; MYSQL_PASS="$(openssl rand -hex 16)"
FLEET_PRIV="$(openssl rand -hex 24)"
cat > /opt/fleet/docker-compose.yml <<'YAML'
services:
  mysql:
    image: mysql:8.0
    command: ["mysqld","--default-authentication-plugin=mysql_native_password"]
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT}
      MYSQL_DATABASE: fleet
      MYSQL_USER: fleet
      MYSQL_PASSWORD: ${MYSQL_PASS}
    volumes: [ "mysql:/var/lib/mysql" ]
    healthcheck:
      test: ["CMD","mysqladmin","ping","-h","localhost","-p${MYSQL_ROOT}"]
      interval: 5s
      timeout: 5s
      retries: 30
  redis:
    image: redis:7-alpine
  fleet:
    image: fleetdm/fleet:latest
    depends_on:
      mysql: { condition: service_healthy }
      redis: { condition: service_started }
    command: sh -c "fleet prepare db --no-prompt=true && fleet serve"
    environment:
      FLEET_MYSQL_ADDRESS: mysql:3306
      FLEET_MYSQL_DATABASE: fleet
      FLEET_MYSQL_USERNAME: fleet
      FLEET_MYSQL_PASSWORD: ${MYSQL_PASS}
      FLEET_REDIS_ADDRESS: redis:6379
      FLEET_SERVER_ADDRESS: 0.0.0.0:443
      FLEET_SERVER_CERT: /certs/fullchain.pem
      FLEET_SERVER_KEY: /certs/privkey.pem
      FLEET_SERVER_PRIVATE_KEY: ${FLEET_PRIV}
      FLEET_LOGGING_JSON: "true"
    ports: [ "443:443" ]
    volumes: [ "/opt/fleet/certs:/certs:ro" ]
    restart: unless-stopped
volumes:
  mysql: {}
YAML
cat > /opt/fleet/.env <<EOF
MYSQL_ROOT=${MYSQL_ROOT}
MYSQL_PASS=${MYSQL_PASS}
FLEET_PRIV=${FLEET_PRIV}
EOF

echo ">>> [5/9] docker compose up"
cd /opt/fleet && docker compose --env-file .env up -d

echo ">>> [6/9] wait for Fleet healthy"
for i in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://${H}/healthz" || true)"
  [ "$code" = "200" ] && { echo "Fleet healthy"; break; }
  echo "  waiting ($i): healthz=$code"; sleep 10
done

echo ">>> [7/9] install matching fleetctl"
CN="$(docker ps --format '{{.Names}}' | grep -m1 fleet-fleet)"
VER="$(docker exec "$CN" fleet version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo "fleet version: $VER"
rm -f /usr/local/bin/fleetctl
curl -fsSL "https://github.com/fleetdm/fleet/releases/download/fleet-v${VER}/fleetctl_v${VER}_linux_amd64.tar.gz" -o /tmp/fc.tgz
tar xzf /tmp/fc.tgz -C /tmp
install -m0755 "$(find /tmp -type f -name fleetctl | head -1)" /usr/local/bin/fleetctl
hash -r; fleetctl --version

echo ">>> [8/9] admin + policies"
fleetctl config set --address "https://${H}" >/dev/null
fleetctl setup --email "$FLEET_ADMIN_EMAIL" --password "$FLEET_ADMIN_PASS" \
  --org-name "$FLEET_ORG" --name "Admin" 2>&1 | tail -2 || echo "(setup may already be done)"
fleetctl login --email "$FLEET_ADMIN_EMAIL" --password "$FLEET_ADMIN_PASS" >/dev/null 2>&1 || true
echo "$FLEET_POLICIES_B64" | base64 -d > /opt/fleet/policies.yml
fleetctl apply -f /opt/fleet/policies.yml
SECRET="$(fleetctl get enroll_secret 2>&1 | grep -oE 'secret: .*' | head -1 | awk '{print $2}')"

echo ">>> [9/9] build + serve fleetd MSI"
cd /opt/fleet/dl
[ -f fleet-osquery.msi ] || fleetctl package --type=msi --fleet-url="https://${H}" --enroll-secret="$SECRET" 2>&1 | tail -3
chmod 0644 /opt/fleet/dl/*.msi 2>/dev/null || true
systemctl is-active --quiet fleetdl 2>/dev/null || \
  systemd-run --unit=fleetdl --collect /usr/bin/python3 -m http.server 80 --directory /opt/fleet/dl >/dev/null 2>&1 || true

echo "==================================================="
echo "FLEET_URL=https://${H}"
echo "FLEET_ADMIN=${FLEET_ADMIN_EMAIL}"
echo "FLEET_ENROLL_SECRET=${SECRET}"
echo "FLEETD_MSI=http://${H}/fleet-osquery.msi"
echo "==================================================="
echo ">>> done $(date -u)"
