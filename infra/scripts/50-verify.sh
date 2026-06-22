#!/usr/bin/env bash
# Step 5/5 (local): verify services + HTTPS, and print the login + 2FA secret.
. "$(dirname "$0")/lib.sh"
IID="$(get_iid)"; [ -n "$IID" ] || die "no instance"
ssm_wait_online "$IID"

say "Server-side health + admin login / 2FA"
ssm_run_file "$IID" "$SCRIPT_DIR/remote/verify.sh" \
  "TRMM_ROOT=$TRMM_ROOT" "TRMM_ADMIN_USER=${TRMM_ADMIN_USER:-nbcadmin}"

say "HTTPS reachability from here"
for h in rmm api; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$h.$TRMM_ROOT/" || echo ERR)"
  printf '  https://%-18s -> HTTP %s\n' "$h.$TRMM_ROOT" "$code"
done
echo
ok "Web UI: https://rmm.$TRMM_ROOT   (user: ${TRMM_ADMIN_USER:-nbcadmin})"
echo "Add the TOTP secret above to your authenticator app, then log in."
