#!/usr/bin/env bash
# Install FleetDM on THIS server (Docker Compose). Run as root: sudo ./install-fleet.sh
# No AWS — pure on-prem. Cert via get-cert.sh (CERT_MODE). Port configurable for co-hosting.
set -uo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./install-fleet.sh"; exit 1; }
. "$SD/config.env"
: "${FLEET_HOSTNAME:?}"; : "${FLEET_ADMIN_EMAIL:?}"; : "${FLEET_ADMIN_PASS:?}"
H="$FLEET_HOSTNAME"; PORT="${FLEET_HTTPS_PORT:-443}"
[ "$PORT" = "443" ] && FURL="https://$H" || FURL="https://$H:$PORT"
export DEBIAN_FRONTEND=noninteractive
mkdir -p /opt/fleet/dl; exec > >(tee /opt/fleet/install.log) 2>&1
echo ">>> Fleet install start $(date -u)  url=$FURL"

echo ">>> [1/8] packages + docker"
apt-get update -y -q; apt-get install -y ca-certificates curl jq openssl
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

echo ">>> [2/8] TLS cert (CERT_MODE=${CERT_MODE:-letsencrypt})"
bash "$SD/get-cert.sh" fleet "$H"
install -d /opt/fleet/certs
cp -L /etc/epm/certs/fleet/fullchain.pem /opt/fleet/certs/fullchain.pem
cp -L /etc/epm/certs/fleet/privkey.pem  /opt/fleet/certs/privkey.pem
chmod 0644 /opt/fleet/certs/*.pem        # non-root container must read the key

echo ">>> [3/8] hairpin (resolve own name to localhost on this box)"
grep -q " ${H}\$" /etc/hosts || echo "127.0.0.1 ${H}" >> /etc/hosts

echo ">>> [4/8] compose + secrets"
MYSQL_ROOT="$(openssl rand -hex 16)"; MYSQL_PASS="$(openssl rand -hex 16)"; FLEET_PRIV="$(openssl rand -hex 24)"
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
    healthcheck: { test: ["CMD","mysqladmin","ping","-h","localhost","-p${MYSQL_ROOT}"], interval: 5s, timeout: 5s, retries: 30 }
  redis: { image: redis:7-alpine }
  fleet:
    image: fleetdm/fleet:latest
    depends_on: { mysql: { condition: service_healthy }, redis: { condition: service_started } }
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
    ports: [ "${FLEET_PORT}:443" ]
    volumes: [ "/opt/fleet/certs:/certs:ro" ]
    restart: unless-stopped
volumes: { mysql: {} }
YAML
cat > /opt/fleet/.env <<EOF
MYSQL_ROOT=${MYSQL_ROOT}
MYSQL_PASS=${MYSQL_PASS}
FLEET_PRIV=${FLEET_PRIV}
FLEET_PORT=${PORT}
EOF

echo ">>> [5/8] docker compose up"
cd /opt/fleet && docker compose --env-file .env up -d

echo ">>> [6/8] wait for Fleet healthy"
for i in $(seq 1 60); do c=$(curl -s -o /dev/null -w '%{http_code}' "$FURL/healthz" || true); [ "$c" = "200" ] && { echo "healthy"; break; }; echo "  ($i) healthz=$c"; sleep 10; done

echo ">>> [7/8] fleetctl (matching version) + admin + policies"
CN=$(docker ps --format '{{.Names}}' | grep -m1 fleet-fleet)
VER=$(docker exec "$CN" fleet version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
rm -f /usr/local/bin/fleetctl
curl -fsSL "https://github.com/fleetdm/fleet/releases/download/fleet-v${VER}/fleetctl_v${VER}_linux_amd64.tar.gz" -o /tmp/fc.tgz
tar xzf /tmp/fc.tgz -C /tmp; install -m0755 "$(find /tmp -type f -name fleetctl | head -1)" /usr/local/bin/fleetctl; hash -r
export HOME=/root
fleetctl config set --address "$FURL" >/dev/null
fleetctl setup --email "$FLEET_ADMIN_EMAIL" --password "$FLEET_ADMIN_PASS" --org-name "${FLEET_ORG:-MyOrg}" --name Admin 2>&1 | tail -2 || echo "(setup may already be done)"
fleetctl login --email "$FLEET_ADMIN_EMAIL" --password "$FLEET_ADMIN_PASS" >/dev/null 2>&1 || true
fleetctl apply -f "$SD/fleet-policies.yml"
SECRET=$(fleetctl get enroll_secret 2>&1 | grep -oE 'secret: .*' | head -1 | awk '{print $2}')

echo ">>> [8/8] build fleetd MSI (for Windows enrollment)"
cd /opt/fleet/dl
fleetctl package --type=msi --fleet-url="$FURL" --enroll-secret="$SECRET" 2>&1 | tail -2
chmod 0644 /opt/fleet/dl/*.msi 2>/dev/null || true

echo "==================================================="
echo "FLEET_URL=$FURL   (admin: $FLEET_ADMIN_EMAIL)"
echo "ENROLL_SECRET=$SECRET"
echo "FLEETD_MSI=/opt/fleet/dl/fleet-osquery.msi"
echo "Get the MSI to endpoints: scp it off, OR serve temporarily:"
echo "  python3 -m http.server 8080 --directory /opt/fleet/dl   # then http://$H:8080/fleet-osquery.msi"
echo ">>> done $(date -u)"
