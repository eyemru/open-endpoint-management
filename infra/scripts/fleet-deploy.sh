#!/usr/bin/env bash
# Deploy FleetDM (compliance plane) on the separate Fleet instance.
# Prereq: the Fleet instance exists (run ./10-provision.sh or ./deploy.sh first,
# which Terraform-creates both the TRMM and Fleet instances).
. "$(dirname "$0")/lib.sh"
: "${FLEET_ADMIN_EMAIL:?set in config.env}"
: "${FLEET_ADMIN_PASS:?set in config.env (>=12 chars)}"

FIID="$(tf output -raw fleet_instance_id 2>/dev/null || true)"
FEIP="$(tf output -raw fleet_public_ip 2>/dev/null || true)"
[ -n "$FIID" ] || die "no Fleet instance — run ./10-provision.sh (or ./deploy.sh) first"

# DuckDNS is typically maxed at 5 domains, so default Fleet to <eip>.sslip.io.
FLEET_HOSTNAME="${FLEET_HOSTNAME:-${FEIP}.sslip.io}"
say "Fleet instance=$FIID  host=$FLEET_HOSTNAME  eip=$FEIP"

# If using a DuckDNS hostname (and we have a token), point it at the Fleet EIP.
case "$FLEET_HOSTNAME" in
  *.duckdns.org)
    if [ -n "${DUCKDNS_TOKEN:-}" ]; then
      sub="${FLEET_HOSTNAME%.duckdns.org}"
      say "Pointing DuckDNS '$sub' -> $FEIP"
      r="$(curl -s "https://www.duckdns.org/update?domains=${sub}&token=${DUCKDNS_TOKEN}&ip=${FEIP}")"
      [ "$r" = "OK" ] && ok "DuckDNS updated" || warn "DuckDNS update returned: $r"
      sleep 5
    else
      warn "FLEET_HOSTNAME is DuckDNS but DUCKDNS_TOKEN unset — point $FLEET_HOSTNAME -> $FEIP manually."
    fi ;;
esac

ssm_wait_online "$FIID"

POL="$(base64 < "$SCRIPT_DIR/fleet-policies.yml" | tr -d '\n')"
say "Installing Fleet (Docker stack, cert, fleetctl, policies, MSI) ~10-15 min..."
SSM_TIMEOUT=2400 ssm_run_file "$FIID" "$SCRIPT_DIR/remote/fleet-install.sh" \
  "FLEET_HOSTNAME=$FLEET_HOSTNAME" \
  "FLEET_ADMIN_EMAIL=$FLEET_ADMIN_EMAIL" \
  "FLEET_ADMIN_PASS=$FLEET_ADMIN_PASS" \
  "FLEET_ORG=${FLEET_ORG:-Northbridge}" \
  "LE_EMAIL=${LE_EMAIL:-$FLEET_ADMIN_EMAIL}" \
  "FLEET_POLICIES_B64=$POL" | tail -20

echo
ok "Fleet UI: https://${FLEET_HOSTNAME}  (login: ${FLEET_ADMIN_EMAIL})"
ok "Enroll the Windows endpoint with the fleetd MSI: http://${FLEET_HOSTNAME}/fleet-osquery.msi"
echo "See docs/agent-install-guide.md (Fleet section) for the install command."
