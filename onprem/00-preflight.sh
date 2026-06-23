#!/usr/bin/env bash
# Sanity-check an on-prem server before installing. Run as root: sudo ./00-preflight.sh
set -uo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SD/config.env" ] && . "$SD/config.env" || { echo "copy config.env.example -> config.env first"; exit 1; }
miss=0
note(){ printf '  %-22s %s\n' "$1" "$2"; }
[ "$(id -u)" -eq 0 ] || { echo "[x] run as root (sudo)"; miss=1; }

echo "=== OS ==="; . /etc/os-release 2>/dev/null; note "distro" "${PRETTY_NAME:-unknown}"
case "${VERSION_ID:-}" in 22.04|24.04|12) : ;; *) echo "  [!] tested on Ubuntu 22.04/24.04 + Debian 12; yours may differ";; esac

echo "=== resources ==="
ram=$(awk '/MemTotal/{printf "%.1f", $2/1024/1024}' /proc/meminfo); note "RAM (GB)" "$ram"
awk -v r="$ram" 'BEGIN{ if (r+0 < 3.5) print "  [!] <4GB RAM — TRMM/Fleet want >=4GB" }'
note "vCPU" "$(nproc)"; note "disk free /" "$(df -h / | awk 'NR==2{print $4}')"

echo "=== tools ==="
for t in curl openssl ca-certificates; do command -v "$t" >/dev/null 2>&1 && note "$t" ok || { note "$t" "MISSING (apt-get install $t)"; }; done

echo "=== ports free (must be free for the installer) ==="
for p in 80 443; do
  if ss -tlnp 2>/dev/null | grep -q ":$p "; then echo "  [!] port $p is already in use:"; ss -tlnp | grep ":$p "; miss=1; else note "port $p" free; fi
done

echo "=== outbound internet (apt/docker/installer downloads) ==="
curl -fsS -o /dev/null --max-time 8 https://raw.githubusercontent.com 2>/dev/null && note "https egress" ok || { note "https egress" "FAILED (need internet to pull packages/images)"; miss=1; }

echo "=== DNS: do your hostnames resolve to THIS server? ==="
myip=$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
note "this server IP" "$myip"
check(){ ip=$(getent hosts "$1" | awk '{print $1}' | head -1); printf '  %-30s -> %s %s\n' "$1" "${ip:-<none>}" "$([ "$ip" = "$myip" ] && echo OK || echo '(must point here)')"; }
[ -n "${TRMM_ROOT:-}" ] && for h in "api.$TRMM_ROOT" "rmm.$TRMM_ROOT" "mesh.$TRMM_ROOT"; do check "$h"; done
[ -n "${FLEET_HOSTNAME:-}" ] && check "$FLEET_HOSTNAME"

echo
[ "$miss" -eq 0 ] && echo "[ok] preflight passed" || { echo "[x] preflight found blockers above"; exit 1; }
