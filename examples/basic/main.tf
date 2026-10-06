# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A private Amazon Redshift Serverless workgroup in the subnets you give, reachable on
# its port from anywhere in the VPC. Amazon Redshift keeps the admin password in AWS
# Secrets Manager.

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
  description = "ID of the VPC to create the workgroup in"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of private subnets for the workgroup, in at least two Availability Zones"
  type        = list(string)
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

module "redshift_serverless" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Analytics"
    environment = "Development"
  }

  name       = "example-basic"
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  security_group_ingress = {
    vpc = { cidr_ipv4 = data.aws_vpc.this.cidr_block, description = "Anything in the VPC" }
  }
}

output "workgroup" {
  description = "Where to connect, and the ARN of the Secrets Manager secret that holds the admin password"
  value = {
    address    = module.redshift_serverless.metadata.redshiftserverless_workgroup.endpoint[0].address
    port       = module.redshift_serverless.metadata.redshiftserverless_workgroup.endpoint[0].port
    secret_arn = module.redshift_serverless.metadata.redshiftserverless_namespace.admin_password_secret_arn
  }
}
