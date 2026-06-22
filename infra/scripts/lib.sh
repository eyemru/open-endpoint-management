#!/usr/bin/env bash
# Shared helpers for the local deployment scripts. SOURCE this file; don't run it.
# Local scripts run on your machine and drive AWS (CLI) + the box (SSM over 443).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- load config.env ---
if [ -f "$SCRIPT_DIR/config.env" ]; then
  set -a; . "$SCRIPT_DIR/config.env"; set +a
else
  echo "ERROR: $SCRIPT_DIR/config.env not found." >&2
  echo "       cp $SCRIPT_DIR/config.env.example $SCRIPT_DIR/config.env  then edit it." >&2
  exit 1
fi
: "${AWS_REGION:?set in config.env}"
: "${PROJECT:?set in config.env}"
: "${TRMM_ROOT:?set in config.env}"
export AWS_REGION

say()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n'  "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n'  "$*" >&2; exit 1; }

tf()      { terraform -chdir="$INFRA_DIR" "$@"; }
get_eip() { tf output -raw public_ip   2>/dev/null || true; }
get_iid() { tf output -raw instance_id 2>/dev/null || true; }

# Fail fast with a clear message if tooling/creds/config aren't ready.
# Pass the names of config vars that must be set (not empty / not REPLACE_ME).
preflight() {
  local miss=0 t v val
  for t in aws terraform python3 curl dig; do
    command -v "$t" >/dev/null 2>&1 || { warn "missing required tool: $t"; miss=1; }
  done
  if command -v aws >/dev/null 2>&1; then
    aws sts get-caller-identity >/dev/null 2>&1 || { warn "AWS credentials not working (aws sts get-caller-identity failed)"; miss=1; }
  fi
  for v in "$@"; do
    val="${!v:-}"
    case "$val" in ""|REPLACE_ME*) warn "config.env: '$v' is not set"; miss=1 ;; esac
  done
  [ "$miss" -eq 0 ] || die "preflight failed — fix the above, then re-run."
  ok "preflight ok ($(aws sts get-caller-identity --query Arn --output text 2>/dev/null), region $AWS_REGION)"
}

# Wait until the instance is registered + online in SSM.
ssm_wait_online() {
  local iid="$1" tries="${2:-40}" i p
  say "Waiting for SSM agent on $iid to come online..."
  for ((i=1; i<=tries; i++)); do
    p="$(aws ssm describe-instance-information --region "$AWS_REGION" \
        --filters "Key=InstanceIds,Values=$iid" \
        --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)"
    [ "$p" = "Online" ] && { ok "SSM online"; return 0; }
    sleep 15
  done
  die "SSM agent did not come online for $iid (try a reboot: aws ec2 reboot-instances)"
}

# Run a LOCAL script file on the instance via SSM (as root, over 443).
# Extra args are ENV=VALUE pairs passed to the remote script.
# Prints the command's full stdout; returns non-zero on failure.
ssm_run_file() {
  local iid="$1" script="$2"; shift 2
  local timeout="${SSM_TIMEOUT:-3600}"
  local envprefix="" kv k v
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"; envprefix+="$k='$v' "; done

  local b64 tmp params cid st
  b64="$(base64 < "$script" | tr -d '\n')"
  tmp="$(mktemp)"
  {
    echo "umask 022"
    echo "base64 -d > /tmp/_ssm_run.sh <<'B64'"
    echo "$b64"
    echo "B64"
    echo "${envprefix}bash /tmp/_ssm_run.sh"
  } > "$tmp"
  params="$(python3 -c 'import json,sys;print(json.dumps({"commands":[open(sys.argv[1]).read()]}))' "$tmp")"
  rm -f "$tmp"

  cid="$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$iid" \
        --document-name AWS-RunShellScript --timeout-seconds "$timeout" \
        --parameters "$params" --query 'Command.CommandId' --output text)" \
    || die "ssm send-command failed"

  local waited=0 maxwait=$(( timeout + 180 ))
  while :; do
    st="$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$cid" \
          --instance-id "$iid" --query Status --output text 2>/dev/null || echo Pending)"
    case "$st" in
      Success) break ;;
      Failed|Cancelled|TimedOut)
        aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$cid" \
            --instance-id "$iid" --query 'StandardErrorContent' --output text >&2 || true
        die "SSM command $st (command-id=$cid)" ;;
    esac
    sleep 10; waited=$(( waited + 10 ))
    [ "$waited" -ge "$maxwait" ] && die "SSM command still running after ${maxwait}s (command-id=$cid) — check the AWS SSM console"
  done
  aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$cid" \
      --instance-id "$iid" --query 'StandardOutputContent' --output text
}
