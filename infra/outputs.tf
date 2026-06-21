output "public_ip" {
  description = "Elastic IP — point your DuckDNS records (rmm./api./mesh.) at this"
  value       = aws_eip.trmm.public_ip
}

output "ssh_command" {
  description = "SSH into the box"
  value       = "ssh -i ${path.module}/${var.project}-key.pem ubuntu@${aws_eip.trmm.public_ip}"
}

output "instance_id" {
  value = aws_instance.trmm.id
}
