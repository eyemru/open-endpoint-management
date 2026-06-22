#!/usr/bin/env bash
# Runs ON the box (via SSM). Prints service health, agent count, and the admin TOTP secret.
set -uo pipefail
ROOT="${TRMM_ROOT:-nbcepm.duckdns.org}"
ADMIN="${TRMM_ADMIN_USER:-nbcadmin}"

echo "--- services ---"
for s in nginx postgresql redis-server nats nats-api meshcentral rmm daphne celery celerybeat; do
  printf '%-14s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null)"
done

echo "--- agents + admin 2FA ---"
cd /rmm/api/tacticalrmm || { echo "TRMM not installed"; exit 1; }
OWNER=$(stat -c '%U' manage.py)
sudo -u "$OWNER" /rmm/api/env/bin/python manage.py shell <<PY
from agents.models import Agent
from accounts.models import User
print("agents registered:", Agent.objects.count())
try:
    u = User.objects.get(username="$ADMIN")
    print("admin user      :", u.username)
    print("TOTP secret     :", u.totp_key)
    print("otpauth URL     : otpauth://totp/TacticalRMM:%s?secret=%s&issuer=TacticalRMM" % (u.username, u.totp_key))
except Exception as e:
    print("admin lookup err:", e)
PY
