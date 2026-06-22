#!/usr/bin/env bash
# Step 3/5 (local -> remote via SSM): obtain a Let's Encrypt cert on the box (HTTP-01).
. "$(dirname "$0")/lib.sh"
IID="$(get_iid)"; [ -n "$IID" ] || die "no instance — run 10-provision.sh first"
ssm_wait_online "$IID"

say "Obtaining Let's Encrypt SAN certificate (api/rmm/mesh + root) via HTTP-01..."
SSM_TIMEOUT=900 ssm_run_file "$IID" "$SCRIPT_DIR/remote/get-cert.sh" \
  "LE_EMAIL=${LE_EMAIL:-admin@$TRMM_ROOT}" "TRMM_ROOT=$TRMM_ROOT" | tail -12
ok "Certificate obtained (/etc/letsencrypt/live/trmm/)"
