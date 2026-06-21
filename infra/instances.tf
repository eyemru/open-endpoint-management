# SSH keypair (generated locally; private key written to infra/ and gitignored).

resource "tls_private_key" "trmm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "trmm" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.trmm.public_key_openssh
}

resource "local_sensitive_file" "trmm_key" {
  content         = tls_private_key.trmm.private_key_pem
  filename        = "${path.module}/${var.project}-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "trmm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.trmm.id]
  key_name               = aws_key_pair.trmm.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  root_block_device {
    volume_size = var.root_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project}-tactical-rmm" }
}

resource "aws_eip" "trmm" {
  instance = aws_instance.trmm.id
  domain   = "vpc"
  tags     = { Name = "${var.project}-trmm-eip" }
}
