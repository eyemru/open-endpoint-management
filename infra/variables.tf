variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project tag / name prefix"
  type        = string
  default     = "epm-poc"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (e.g. 1.2.3.4/32) — allowed to SSH to the box"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Tactical RMM (>=4GB RAM recommended)"
  type        = string
  default     = "t3.medium"
}

variable "root_gb" {
  description = "Root EBS volume size (GiB)"
  type        = number
  default     = 30
}
