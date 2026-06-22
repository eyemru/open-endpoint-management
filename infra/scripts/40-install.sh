#!/usr/bin/env bash
# Step 4/5 (local -> remote via SSM): unattended Tactical RMM install (~15-30 min).
. "$(dirname "$0")/lib.sh"
: "${TRMM_ADMIN_USER:?set in config.env}"
: "${TRMM_ADMIN_PASS:?set in config.env}"
IID="$(get_iid)"; [ -n "$IID" ] || die "no instance — run 10-provision.sh first"
ssm_wait_online "$IID"

say "Installing Tactical RMM (compiles Python, sets up Postgres/Mesh/etc.) — be patient..."
SSM_TIMEOUT=2700 ssm_run_file "$IID" "$SCRIPT_DIR/remote/install-trmm.sh" \
  "TRMM_ROOT=$TRMM_ROOT" \
  "TRMM_EMAIL=${LE_EMAIL:-admin@$TRMM_ROOT}" \
  "TRMM_ADMIN_USER=$TRMM_ADMIN_USER" \
  "TRMM_ADMIN_PASS=$TRMM_ADMIN_PASS" | tail -25
ok "Tactical RMM install finished"
