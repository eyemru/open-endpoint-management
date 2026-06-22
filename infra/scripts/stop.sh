#!/usr/bin/env bash
# Stop ALL project instances (TRMM + Fleet) to halt compute charges.
. "$(dirname "$0")/lib.sh"
ids="$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" \
            "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
[ -n "$ids" ] || { ok "No running instances to stop."; exit 0; }
say "Stopping: $ids"
# shellcheck disable=SC2086
aws ec2 stop-instances --region "$AWS_REGION" --instance-ids $ids \
  --query 'StoppingInstances[].CurrentState.Name' --output text
ok "Stopping. Compute charges halt; EBS + EIPs remain (a few \$/mo). './start.sh' to resume."
