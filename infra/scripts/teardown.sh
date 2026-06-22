#!/usr/bin/env bash
# DESTROY everything: terminates the instance and removes ALL cost-incurring AWS
# objects (EC2, EBS root volume, Elastic IP, security group, IAM role/profile, keypair),
# then sweeps for anything left tagged with the project.
#
# Usage:  ./teardown.sh        (interactive confirm)
#         ./teardown.sh -y     (no prompt)
. "$(dirname "$0")/lib.sh"

warn "This DESTROYS all AWS resources for project '$PROJECT' in $AWS_REGION:"
warn "  EC2 instance, EBS volume, Elastic IP, security group, IAM role/profile, SSH keypair."
if [ "${1:-}" != "-y" ]; then
  read -r -p "Type 'destroy' to confirm: " ans
  [ "$ans" = "destroy" ] || die "aborted"
fi

say "terraform destroy"
tf destroy -auto-approve

echo
say "Post-teardown sweep (anything below = leftover to remove manually)"
echo "Instances:"
aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text
echo "Elastic IPs:"
aws ec2 describe-addresses --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" --query 'Addresses[].PublicIp' --output text
echo "Volumes:"
aws ec2 describe-volumes --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT" --query 'Volumes[].VolumeId' --output text
echo "Security groups:"
aws ec2 describe-security-groups --region "$AWS_REGION" \
  --filters "Name=group-name,Values=${PROJECT}-*" --query 'SecurityGroups[].GroupId' --output text

echo
ok "Teardown complete. Empty lists above = clean (no remaining cost)."
warn "Note: this does NOT touch DuckDNS or the agent on your endpoint."
warn "  - DuckDNS: optionally repoint/remove the record at duckdns.org."
warn "  - Endpoint: uninstall the agent and re-enable Windows Update (see agent-install-guide.md)."
