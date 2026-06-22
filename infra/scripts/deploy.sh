#!/usr/bin/env bash
# One-shot deployment: runs all steps in order. Idempotent-ish (Terraform is; the
# install step assumes a fresh box — re-running on an installed box is not supported).
#
# Usage:  ./deploy.sh
# Prereq: config.env filled in; awscli + terraform installed; AWS creds active.
. "$(dirname "$0")/lib.sh"

say "================  Tactical RMM full deployment  ================"
say "Region=$AWS_REGION  Project=$PROJECT  Domain=$TRMM_ROOT"
preflight DUCKDNS_TOKEN TRMM_ADMIN_PASS
echo

"$SCRIPT_DIR/10-provision.sh"
"$SCRIPT_DIR/20-dns.sh"
"$SCRIPT_DIR/30-cert.sh"
"$SCRIPT_DIR/40-install.sh"
"$SCRIPT_DIR/50-verify.sh"

echo
ok "================  Deployment complete  ================"
echo "Next: enroll an endpoint — see docs/agent-install-guide.md"
