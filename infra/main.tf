# Endpoint Management POC — Tactical RMM control plane (M1)
# Minimal, default-VPC footprint for the POC. Tear down with `terraform destroy`.

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
