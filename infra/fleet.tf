# Fleet (compliance plane) — a SEPARATE instance from Tactical RMM.
# Reuses the keypair, SSM instance profile, VPC/subnet, and Ubuntu AMI from the
# rest of the module. Independent EIP so it gets its own DNS name.

resource "aws_security_group" "fleet" {
  name        = "${var.project}-fleet"
  description = "FleetDM control plane: agent + admin access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS - fleetd agents and web UI"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP - Lets Encrypt and one-time installer download"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH - admin only (your IP)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-fleet" }
}

resource "aws_instance" "fleet" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.fleet_instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.fleet.id]
  key_name               = aws_key_pair.trmm.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  root_block_device {
    volume_size = var.fleet_root_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project}-fleet" }
}

resource "aws_eip" "fleet" {
  instance = aws_instance.fleet.id
  domain   = "vpc"
  tags     = { Name = "${var.project}-fleet-eip" }
}

output "fleet_public_ip" {
  description = "Fleet Elastic IP (its sslip.io hostname is <ip>.sslip.io)"
  value       = aws_eip.fleet.public_ip
}

output "fleet_instance_id" {
  value = aws_instance.fleet.id
}
