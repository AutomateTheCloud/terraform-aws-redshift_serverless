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

run "defaults_as_documented" {
  command = plan

  assert {
    condition     = aws_redshiftserverless_namespace.this.namespace_name == "analytics" && aws_redshiftserverless_workgroup.this.workgroup_name == "analytics"
    error_message = "The namespace and workgroup must be named after var.name."
  }
  assert {
    condition     = aws_redshiftserverless_workgroup.this.base_capacity == 8 && aws_redshiftserverless_workgroup.this.max_capacity == null && aws_redshiftserverless_workgroup.this.port == 5439
    error_message = "Unexpected capacity or port defaults."
  }
  assert {
    condition     = aws_iam_role.this.name_prefix == "redshift-serverless-" && aws_security_group.this.name_prefix == "redshift-analytics-"
    error_message = "Unexpected name prefixes."
  }
  assert {
    condition     = aws_security_group.this.description == "Test - Analytics [test] (us-east-1): Redshift Serverless analytics" && aws_security_group.this.tags["Name"] == "redshift-analytics"
    error_message = "Unexpected security group description or Name tag."
  }
  assert {
    condition     = aws_redshiftserverless_workgroup.this.tags == tomap({ Scope = "Test", Purpose = "Analytics", Environment = "test" }) && aws_redshiftserverless_namespace.this.tags == aws_redshiftserverless_workgroup.this.tags
    error_message = "Unexpected tags."
  }
  assert {
    condition     = output.metadata.iam_role_policy == null && output.metadata.iam_role_policy_attachment == null && output.metadata.vpc_security_group_ingress_rule == null && output.metadata.vpc_security_group_egress_rule == null
    error_message = "Resources not created must be null in the output."
  }
  assert {
    condition     = length(aws_redshiftserverless_namespace.this.log_exports) == 0 && length(aws_cloudwatch_log_group.this) == 0 && output.metadata.cloudwatch_log_group == null
    error_message = "No audit logs by default."
  }
  assert {
    condition     = toset([for p in aws_redshiftserverless_workgroup.this.config_parameter : "${p.parameter_key}=${p.parameter_value}"]) == toset(["auto_mv=true", "datestyle=ISO, MDY", "enable_case_sensitive_identifier=false", "enable_user_activity_logging=true", "max_query_execution_time=14400", "query_group=default", "require_ssl=true", "search_path=$user, public", "use_fips_ssl=false"])
    error_message = "Every parameter must be sent, with the AWS defaults, including require_ssl = true."
  }
}

run "defaults_are_secure" {
  command = apply

  assert {
    condition     = aws_redshiftserverless_workgroup.this.publicly_accessible == false
    error_message = "The workgroup must not be public by default."
  }
  assert {
    condition     = aws_redshiftserverless_workgroup.this.enhanced_vpc_routing == true
    error_message = "Enhanced VPC routing must be on by default."
  }
  assert {
    condition     = aws_redshiftserverless_namespace.this.manage_admin_password == true && aws_redshiftserverless_namespace.this.admin_user_password == null && aws_redshiftserverless_namespace.this.admin_username == "admin"
    error_message = "The admin password must be managed by Amazon Redshift in Secrets Manager, never set by the module."
  }
  assert {
    condition     = output.metadata.redshiftserverless_namespace.admin_password_secret_arn != null && output.metadata.redshiftserverless_namespace.admin_username == "admin"
    error_message = "The secret's ARN and the user name must be in the output."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0 && length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "The security group must allow nothing by default."
  }
  assert {
    condition     = length(aws_iam_role_policy.this) == 0 && length(aws_iam_role_policy_attachment.this) == 0
    error_message = "The IAM role must have no permissions by default."
  }
  assert {
    condition     = aws_redshiftserverless_namespace.this.default_iam_role_arn == aws_iam_role.this.arn && aws_redshiftserverless_namespace.this.iam_roles == toset([aws_iam_role.this.arn])
    error_message = "The module's role must be the namespace's only and default role."
  }
  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Service == "redshift.amazonaws.com"
    error_message = "Only Amazon Redshift may assume the role."
  }
}
