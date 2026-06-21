#!/usr/bin/env bash
# Unattended Tactical RMM install, driven over SSM (runs as root).
#
# Strategy: the official installer is interactive and refuses to run as root, and its
# Let's Encrypt path uses an interactive wildcard DNS-01 challenge. So we:
#   1) reuse the cert already obtained by 01-get-cert.sh (HTTP-01),
#   2) run the installer AS the `ubuntu` user via `expect`, which allocates a PTY and
#      answers every prompt (domains, --use-own-cert paths, admin login + Django getpass).
#
# Required env (set at send time, not committed):
#   TRMM_ADMIN_USER, TRMM_ADMIN_PASS
# Optional env (have sane defaults):
#   TRMM_ROOT (default nbcepm.duckdns.org), TRMM_EMAIL
set -uo pipefail

ROOT="${TRMM_ROOT:-nbcepm.duckdns.org}"
export TRMM_API="api.${ROOT}"
export TRMM_WEB="rmm.${ROOT}"
export TRMM_MESH="mesh.${ROOT}"
export TRMM_ROOT="$ROOT"
export TRMM_EMAIL="${TRMM_EMAIL:-m.ephrem@gmail.com}"
export TRMM_FULLCHAIN="/home/ubuntu/certs/fullchain.pem"
export TRMM_PRIVKEY="/home/ubuntu/certs/privkey.pem"
: "${TRMM_ADMIN_USER:?set TRMM_ADMIN_USER}"
: "${TRMM_ADMIN_PASS:?set TRMM_ADMIN_PASS}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y expect curl

# Make the cert readable by the ubuntu user (installer checks/copies it as ubuntu).
install -d -o ubuntu -g ubuntu /home/ubuntu/certs
cp -L /etc/letsencrypt/live/trmm/fullchain.pem "$TRMM_FULLCHAIN"
cp -L /etc/letsencrypt/live/trmm/privkey.pem  "$TRMM_PRIVKEY"
chown ubuntu:ubuntu "$TRMM_FULLCHAIN" "$TRMM_PRIVKEY"
chmod 644 "$TRMM_FULLCHAIN"; chmod 600 "$TRMM_PRIVKEY"

# Fetch the official installer.
curl -fsSL https://raw.githubusercontent.com/amidaware/tacticalrmm/master/install.sh \
  -o /home/ubuntu/getrmm.sh
chown ubuntu:ubuntu /home/ubuntu/getrmm.sh
chmod +x /home/ubuntu/getrmm.sh

# Expect driver (reads all values from the environment; no secrets baked in).
cat > /home/ubuntu/install_trmm.exp <<'EXP'
#!/usr/bin/expect -f
set timeout 2400
log_user 1
set api       $env(TRMM_API)
set web       $env(TRMM_WEB)
set mesh      $env(TRMM_MESH)
set root      $env(TRMM_ROOT)
set email     $env(TRMM_EMAIL)
set fullchain $env(TRMM_FULLCHAIN)
set privkey   $env(TRMM_PRIVKEY)
set adminuser $env(TRMM_ADMIN_USER)
set adminpass $env(TRMM_ADMIN_PASS)

spawn bash /home/ubuntu/getrmm.sh --use-own-cert
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
set ec [lindex $result 3]
puts "\n>>> INSTALLER EXIT CODE: $ec <<<"
exit $ec
EXP
chown ubuntu:ubuntu /home/ubuntu/install_trmm.exp

# Run as ubuntu (env explicitly passed through sudo), tee to a log we can peek at.
echo ">>> starting installer at $(date -u) <<<"
sudo -u ubuntu env \
  TRMM_API="$TRMM_API" TRMM_WEB="$TRMM_WEB" TRMM_MESH="$TRMM_MESH" TRMM_ROOT="$TRMM_ROOT" \
  TRMM_EMAIL="$TRMM_EMAIL" TRMM_FULLCHAIN="$TRMM_FULLCHAIN" TRMM_PRIVKEY="$TRMM_PRIVKEY" \
  TRMM_ADMIN_USER="$TRMM_ADMIN_USER" TRMM_ADMIN_PASS="$TRMM_ADMIN_PASS" \
  expect /home/ubuntu/install_trmm.exp 2>&1 | tee /home/ubuntu/trmm_install.log
rc=${PIPESTATUS[0]}
echo ">>> installer wrapper finished rc=$rc at $(date -u) <<<"
exit "$rc"
