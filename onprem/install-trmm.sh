#!/usr/bin/env bash
# Install Tactical RMM on THIS server (Ubuntu 22.04/Debian 12). Run as root: sudo ./install-trmm.sh
# No AWS / Terraform / SSM — pure on-prem. Cert via get-cert.sh (CERT_MODE in config.env).
set -uo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./install-trmm.sh"; exit 1; }
. "$SD/config.env"

ROOT="${TRMM_ROOT:?set TRMM_ROOT}"; API="api.$ROOT"; RMM="rmm.$ROOT"; MESH="mesh.$ROOT"
U="${TRMM_INSTALL_USER:-tactical}"
: "${TRMM_ADMIN_USER:?}"; : "${TRMM_ADMIN_PASS:?}"
EMAIL="${LE_EMAIL:-admin@$ROOT}"
export DEBIAN_FRONTEND=noninteractive
mkdir -p /opt/epm; exec > >(tee /opt/epm/trmm-install.log) 2>&1
echo ">>> TRMM install start $(date -u)  domains: $API / $RMM / $MESH"

echo ">>> [1/5] packages"
apt-get update -y -q
apt-get install -y expect curl ca-certificates openssl

echo ">>> [2/5] non-root install user '$U' (TRMM refuses to run as root)"
if ! id "$U" &>/dev/null; then adduser --disabled-password --gecos "" "$U"; fi
usermod -aG sudo "$U"
echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-epm-$U; chmod 440 /etc/sudoers.d/90-epm-$U

echo ">>> [3/5] TLS cert (CERT_MODE=${CERT_MODE:-letsencrypt})"
bash "$SD/get-cert.sh" trmm "$API" "$RMM" "$MESH" "$ROOT"
install -d -o "$U" -g "$U" "/home/$U/certs"
cp -L /etc/epm/certs/trmm/fullchain.pem "/home/$U/certs/fullchain.pem"
cp -L /etc/epm/certs/trmm/privkey.pem  "/home/$U/certs/privkey.pem"
chown "$U:$U" "/home/$U/certs/"*.pem
chmod 644 "/home/$U/certs/fullchain.pem"; chmod 600 "/home/$U/certs/privkey.pem"

echo ">>> [4/5] fetch official installer + expect driver"
curl -fsSL https://raw.githubusercontent.com/amidaware/tacticalrmm/master/install.sh -o "/home/$U/getrmm.sh"
chown "$U:$U" "/home/$U/getrmm.sh"; chmod +x "/home/$U/getrmm.sh"
cat > "/home/$U/install_trmm.exp" <<'EXP'
#!/usr/bin/expect -f
set timeout 2400
log_user 1
set api $env(TRMM_API); set web $env(TRMM_WEB); set mesh $env(TRMM_MESH)
set root $env(TRMM_ROOT); set email $env(TRMM_EMAIL)
set fullchain $env(TRMM_FULLCHAIN); set privkey $env(TRMM_PRIVKEY)
set adminuser $env(TRMM_ADMIN_USER); set adminpass $env(TRMM_ADMIN_PASS)
spawn bash [lindex $argv 0] --use-own-cert
expect {
  -re {subdomain for the backend}  { send -- "$api\r";       exp_continue }
  -re {subdomain for the frontend} { send -- "$web\r";       exp_continue }
  -re {subdomain for meshcentral}  { send -- "$mesh\r";      exp_continue }
  -re {Enter the root domain}      { send -- "$root\r";      exp_continue }
  -re {valid email address}        { send -- "$email\r";     exp_continue }
  -re {fullchain.pem file}         { send -- "$fullchain\r"; exp_continue }
  -re {privkey.pem file}           { send -- "$privkey\r";   exp_continue }
  -re {Username:}                  { send -- "$adminuser\r"; exp_continue }
  -re {Password \(again\):}        { send -- "$adminpass\r"; exp_continue }
  -re {Password:}                  { send -- "$adminpass\r"; exp_continue }
  -re {Bypass password validation} { send -- "y\r";          exp_continue }
  -re {Press any key to continue}  { send -- " ";            exp_continue }
  timeout { puts "\n>>> EXPECT TIMEOUT <<<"; exit 2 }
  eof
}
catch wait result
puts "\n>>> INSTALLER EXIT: [lindex $result 3] <<<"
exit [lindex $result 3]
EXP
chown "$U:$U" "/home/$U/install_trmm.exp"

echo ">>> [5/5] run installer as '$U' (~15-30 min; compiles Python)"
sudo -u "$U" env \
  TRMM_API="$API" TRMM_WEB="$RMM" TRMM_MESH="$MESH" TRMM_ROOT="$ROOT" TRMM_EMAIL="$EMAIL" \
  TRMM_FULLCHAIN="/home/$U/certs/fullchain.pem" TRMM_PRIVKEY="/home/$U/certs/privkey.pem" \
  TRMM_ADMIN_USER="$TRMM_ADMIN_USER" TRMM_ADMIN_PASS="$TRMM_ADMIN_PASS" \
  expect "/home/$U/install_trmm.exp" "/home/$U/getrmm.sh"
rc=$?

echo "==================================================="
echo "TRMM_URL=https://$RMM   (admin: $TRMM_ADMIN_USER)"
echo "Retrieve the 2FA secret with:"
echo "  cd /rmm/api/tacticalrmm && sudo -u \$(stat -c '%U' manage.py) /rmm/api/env/bin/python manage.py shell -c \\"
echo "    \"from accounts.models import User; print(User.objects.get(username='$TRMM_ADMIN_USER').totp_key)\""
echo ">>> done rc=$rc $(date -u)"
exit "$rc"
