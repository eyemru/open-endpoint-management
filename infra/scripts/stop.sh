#!/usr/bin/env bash
# Stop the control-plane instance to halt compute charges (keeps data, EIP, DNS).
. "$(dirname "$0")/lib.sh"
IID="$(get_iid)"; [ -n "$IID" ] || die "no instance in Terraform state"
say "Stopping $IID ..."
aws ec2 stop-instances --region "$AWS_REGION" --instance-ids "$IID" \
  --query 'StoppingInstances[0].CurrentState.Name' --output text
ok "Stopping. Compute charges halt; EBS (~\$2/mo) + EIP (~\$3.6/mo) remain. './start.sh' to resume."
