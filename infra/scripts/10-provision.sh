#!/usr/bin/env bash
# Step 1/5 (local): provision AWS infra with Terraform (EC2, SG, EIP, SSM role).
. "$(dirname "$0")/lib.sh"

if [ -z "${ADMIN_CIDR:-}" ]; then
  ip="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')"
  [ -n "$ip" ] || die "could not auto-detect public IP; set ADMIN_CIDR in config.env"
  ADMIN_CIDR="${ip}/32"
  say "Auto-detected admin IP: $ADMIN_CIDR"
fi

cat > "$INFRA_DIR/terraform.tfvars" <<EOF
region        = "$AWS_REGION"
project       = "$PROJECT"
admin_cidr    = "$ADMIN_CIDR"
instance_type = "${INSTANCE_TYPE:-t3.medium}"
EOF

say "terraform init"
tf init -input=false >/dev/null
say "terraform apply"
tf apply -auto-approve -input=false
ok "Provisioned. EIP=$(get_eip)  instance=$(get_iid)"
