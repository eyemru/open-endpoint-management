#!/usr/bin/env bash
# Start the (stopped) control-plane instance. EIP + DNS persist; agents reconnect.
. "$(dirname "$0")/lib.sh"
IID="$(get_iid)"; [ -n "$IID" ] || die "no instance in Terraform state"
say "Starting $IID ..."
aws ec2 start-instances --region "$AWS_REGION" --instance-ids "$IID" \
  --query 'StartingInstances[0].CurrentState.Name' --output text
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$IID"
ok "Running. EIP=$(get_eip) (DNS unchanged). SSM ready in ~1-2 min; the laptop agent reconnects on its own."
echo "Tip: ./50-verify.sh  to re-check health and reprint login."
