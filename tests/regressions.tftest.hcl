# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_service_principal" {
    defaults = { name = "redshift.amazonaws.com" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/redshift-serverless-0001", name = "redshift-serverless-0001" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0000000000000000d" }
  }
  mock_resource "aws_redshiftserverless_namespace" {
    defaults = {
      arn                       = "arn:aws:redshift-serverless:us-east-1:111111111111:namespace/0000"
      admin_password_secret_arn = "arn:aws:secretsmanager:us-east-1:111111111111:secret:redshift!analytics-admin-abcdef"
      kms_key_id                = "AWS_OWNED_KMS_KEY"
    }
  }
}

variables {
  details    = { scope = "Test", purpose = "Analytics", environment = "test" }
  name       = "analytics"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0000000000000000a", "subnet-0000000000000000b", "subnet-0000000000000000c"]
}

# Each run is a bug in the module before 1.0.0.

# The default security group rules were null, and every plan failed.
run "defaults_plan" {
  command = plan
}

# port only reached the security group rule; the workgroup kept listening on 5439.
run "port_reaches_workgroup" {
  command = plan
  variables {
    port                   = 5440
    security_group_ingress = { vpc = { cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition     = aws_redshiftserverless_workgroup.this.port == 5440 && aws_vpc_security_group_ingress_rule.this["vpc"].from_port == 5440
    error_message = "The workgroup and its rule must use the same port."
  }
}

# IPv6 ranges were sent as source security group IDs.
run "ipv6_is_a_range" {
  command = plan
  variables {
    security_group_ingress = { v6 = { cidr_ipv6 = "2001:db8::/56" } }
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["v6"].cidr_ipv6 == "2001:db8::/56" && aws_vpc_security_group_ingress_rule.this["v6"].referenced_security_group_id == null
    error_message = "IPv6 range sent as a security group."
  }
}

# Without credentials, a generated password was sent with no user name, which AWS
# refuses; and a generated password was never readable.
run "admin_user_always_complete" {
  command = plan
  assert {
    condition     = aws_redshiftserverless_namespace.this.admin_username == "admin" && aws_redshiftserverless_namespace.this.admin_user_password == null && aws_redshiftserverless_namespace.this.manage_admin_password == true
    error_message = "The admin user must have a name and a password kept in Secrets Manager."
  }
}

# The workgroup allowed all outbound traffic, and the role had broad managed policies.
run "least_privilege" {
  command = plan
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0 && length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No egress and no managed policies by default."
  }
}

# Provider 6.0.0 saves every parameter AWS reports, so sending only some made every
# later plan try to remove the others (seen in AWS). All of them are sent.
run "config_parameters_complete" {
  command = plan
  variables {
    config_parameters = { max_query_execution_time = "7200" }
  }
  assert {
    condition     = length(aws_redshiftserverless_workgroup.this.config_parameter) == 9 && contains([for p in aws_redshiftserverless_workgroup.this.config_parameter : "${p.parameter_key}=${p.parameter_value}"], "max_query_execution_time=7200")
    error_message = "Every parameter must be sent, with the caller's values."
  }
}
