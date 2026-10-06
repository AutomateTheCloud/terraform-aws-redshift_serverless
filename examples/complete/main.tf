# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A workgroup that loads data from one Amazon S3 bucket: a customer managed KMS key,
# an IAM role that can read only that bucket, HTTPS to Amazon S3 through the VPC, audit
# logs in CloudWatch, a capacity limit, and access only from the application's
# security group.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to create the workgroup in. It needs a gateway endpoint for Amazon S3, or a NAT gateway, on the subnets' route tables."
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets for the workgroup, in at least two Availability Zones"
  type        = list(string)
}

variable "data_bucket_name" {
  description = "Name of the S3 bucket the workgroup loads data from with COPY"
  type        = string
}

data "aws_region" "this" {}

data "aws_s3_bucket" "data" {
  bucket = var.data_bucket_name
}

# The S3 address ranges in this Region, for the outbound rule.
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.this.region}.s3"
}

# The key that encrypts the namespace's data and snapshots, and the admin password's
# secret. Its default key policy lets IAM principals in this account use it, which
# Amazon Redshift and Secrets Manager need.
resource "aws_kms_key" "this" {
  description             = "example-complete Redshift Serverless namespace"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# The application servers that may query the workgroup.
resource "aws_security_group" "app" {
  name_prefix = "example-complete-app-"
  description = "Application servers that query example-complete"
  vpc_id      = var.vpc_id
}

# Read access to the data bucket only, for COPY ... IAM_ROLE default.
data "aws_iam_policy_document" "s3_read" {
  statement {
    sid       = "ListDataBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [data.aws_s3_bucket.data.arn]
  }

  statement {
    sid       = "ReadDataObjects"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.data.arn}/*"]
  }
}

module "redshift_serverless" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Analytics"
    environment = "Production"
  }

  name       = "example-complete"
  db_name    = "analytics"
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  kms_key_id = aws_kms_key.this.arn
  admin_user = {
    username          = "dwadmin"
    secret_kms_key_id = aws_kms_key.this.arn
  }

  base_capacity = 8
  max_capacity  = 32

  config_parameters = {
    max_query_execution_time = "3600"
  }
  cloudwatch_logs = {
    exports           = ["connectionlog", "userlog"]
    retention_in_days = 90
  }

  iam_role = {
    source_policy_documents = [data.aws_iam_policy_document.s3_read.json]
  }

  security_group_ingress = {
    app = { security_group_id = aws_security_group.app.id, description = "Application servers" }
  }
  security_group_egress = {
    s3 = { port = 443, prefix_list_id = data.aws_ec2_managed_prefix_list.s3.id, description = "Amazon S3 over HTTPS" }
  }
}

output "workgroup" {
  description = "Where to connect, the ARN of the Secrets Manager secret that holds the admin password, and the security group to add application servers to"
  value = {
    address               = module.redshift_serverless.metadata.redshiftserverless_workgroup.endpoint[0].address
    port                  = module.redshift_serverless.metadata.redshiftserverless_workgroup.endpoint[0].port
    secret_arn            = module.redshift_serverless.metadata.redshiftserverless_namespace.admin_password_secret_arn
    app_security_group_id = aws_security_group.app.id
    default_iam_role_arn  = module.redshift_serverless.metadata.iam_role.arn
  }
}
