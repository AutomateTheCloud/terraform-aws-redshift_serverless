# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A configuration that creates the network, the key, a policy and the client security
# group in the same run as the workgroup, so that their IDs are unknown when the module
# plans. Used only by tests/same_run.tftest.hcl, against a mocked provider.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "this" {
  for_each = { a = "10.0.1.0/24", b = "10.0.2.0/24", c = "10.0.3.0/24" }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = "us-east-1${each.key}"
}

resource "aws_kms_key" "this" {
  description         = "Same-run test key"
  enable_key_rotation = true
}

resource "aws_iam_policy" "this" {
  name = "same-run"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "s3:GetObject", Resource = "arn:aws:s3:::example/*" }]
  })
}

resource "aws_security_group" "app" {
  name   = "app"
  vpc_id = aws_vpc.this.id
}

resource "aws_ec2_managed_prefix_list" "s3" {
  name           = "same-run"
  address_family = "IPv4"
  max_entries    = 1
}

module "redshift_serverless" {
  source = "../../.."

  details        = { scope = "Test", purpose = "Same Run", environment = "test" }
  name           = "same-run"
  vpc_id         = aws_vpc.this.id
  subnet_ids     = [for s in aws_subnet.this : s.id]
  kms_key_id     = aws_kms_key.this.arn
  admin_password = sensitive("Example-Passw0rd")

  iam_role = {
    policy_arns = { same_run = aws_iam_policy.this.arn }
  }

  security_group_ingress = {
    app = { security_group_id = aws_security_group.app.id }
    vpc = { cidr_ipv4 = aws_vpc.this.cidr_block }
  }
  security_group_egress = {
    s3 = { port = 443, prefix_list_id = aws_ec2_managed_prefix_list.s3.id }
  }
}

output "metadata" {
  value = module.redshift_serverless.metadata
}
