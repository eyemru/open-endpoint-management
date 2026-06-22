#!/usr/bin/env bash
# Step 2/5 (local): point the DuckDNS domain (+ wildcard) at the Elastic IP, verify DNS.
. "$(dirname "$0")/lib.sh"
: "${DUCKDNS_SUBDOMAIN:?set in config.env}"
: "${DUCKDNS_TOKEN:?set in config.env}"

EIP="$(get_eip)"; [ -n "$EIP" ] || die "no EIP found — run 10-provision.sh first"

say "Pointing ${DUCKDNS_SUBDOMAIN}.duckdns.org (+ wildcard) -> $EIP"
resp="$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${EIP}")"
[ "$resp" = "OK" ] || die "DuckDNS update failed (response: '$resp') — check token/subdomain"
ok "DuckDNS updated"

sleep 5
say "Verifying resolution (root + rmm/api/mesh must all = $EIP)"
fail=0
for h in "$TRMM_ROOT" "rmm.$TRMM_ROOT" "api.$TRMM_ROOT" "mesh.$TRMM_ROOT"; do
  got="$(dig +short "$h" @1.1.1.1 | tail -1)"
  printf '  %-30s -> %s\n' "$h" "${got:-<none>}"
  [ "$got" = "$EIP" ] || fail=1
done
[ "$fail" -eq 0 ] && ok "DNS verified" || warn "Some names not yet resolving (DNS propagation) — re-run in a minute"
