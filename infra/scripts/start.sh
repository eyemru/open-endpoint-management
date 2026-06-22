#!/usr/bin/env bash
# Start ALL project instances (TRMM + Fleet). EIPs + DNS persist; agents reconnect.
. "$(dirname "$0")/lib.sh"
ids="$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" \
            "Name=instance-state-name,Values=stopped,stopping" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
[ -n "$ids" ] || { ok "No stopped instances to start."; exit 0; }
say "Starting: $ids"
# shellcheck disable=SC2086
aws ec2 start-instances --region "$AWS_REGION" --instance-ids $ids \
  --query 'StartingInstances[].CurrentState.Name' --output text
# shellcheck disable=SC2086
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids $ids
ok "Running. EIPs/DNS unchanged. SSM ready in ~1-2 min; endpoint agents reconnect on their own."
echo "Tip: ./50-verify.sh (TRMM) and the Fleet UI to confirm."
