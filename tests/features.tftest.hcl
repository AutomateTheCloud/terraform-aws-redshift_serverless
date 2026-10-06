# Copyright 2025 Automate the Cloud Inc.
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

run "admin_password_given" {
  command = plan
  variables {
    admin_password = "Example-Passw0rd"
    admin_user     = { secret_kms_key_id = "alias/unused" }
  }
  assert {
    condition     = aws_redshiftserverless_namespace.this.manage_admin_password == null
    error_message = "With a password, Secrets Manager must not be used."
  }
  assert {
    condition     = nonsensitive(aws_redshiftserverless_namespace.this.admin_user_password == "Example-Passw0rd")
    error_message = "The password must be passed through."
  }
}

run "details_characters_aws_refuses" {
  command = plan
  variables {
    details = { scope = "Tëst – Scope", purpose = "Analytics", environment = "test" }
  }
  assert {
    condition     = aws_security_group.this.description == "Tst  Scope - Analytics [test] (us-east-1): Redshift Serverless analytics"
    error_message = "Characters a security group description refuses must be dropped."
  }
  assert {
    condition     = aws_iam_role.this.description == "Tëst  Scope - Analytics [test] (us-east-1): Redshift Serverless analytics"
    error_message = "Only characters outside Latin-1 must be dropped from the IAM description."
  }
}

run "every_option" {
  command = apply
  variables {
    db_name                       = "warehouse"
    kms_key_id                    = "arn:aws:kms:us-east-1:111111111111:key/1111"
    admin_user                    = { username = "dwadmin", secret_kms_key_id = "alias/redshift-secret" }
    base_capacity                 = 16
    max_capacity                  = 64
    port                          = 5440
    enhanced_vpc_routing          = false
    cloudwatch_logs               = { exports = ["connectionlog", "userlog"], retention_in_days = 30, kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/2222" }
    config_parameters             = { max_query_execution_time = "3600", require_ssl = "false" }
    additional_security_group_ids = ["sg-0000000000000000e"]
    additional_iam_role_arns      = ["arn:aws:iam::111111111111:role/spectrum"]
    iam_role = {
      policy_arns             = { spectrum = "arn:aws:iam::111111111111:policy/spectrum" }
      source_policy_documents = ["{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::data/*\"}]}"]
    }
    security_group_ingress = {
      vpc  = { cidr_ipv4 = "10.0.0.0/16" }
      ipv6 = { cidr_ipv6 = "2001:db8::/56", description = "IPv6 clients" }
      app  = { security_group_id = "sg-0000000000000000f" }
      list = { prefix_list_id = "pl-00000000000000000" }
    }
    security_group_egress = {
      s3 = { port = 443, prefix_list_id = "pl-63a5400a" }
    }
  }

  assert {
    condition     = aws_redshiftserverless_namespace.this.db_name == "warehouse" && aws_redshiftserverless_namespace.this.kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/1111"
    error_message = "db_name or kms_key_id not passed through."
  }
  assert {
    condition     = nonsensitive(aws_redshiftserverless_namespace.this.admin_username == "dwadmin") && aws_redshiftserverless_namespace.this.admin_password_secret_kms_key_id == "alias/redshift-secret" && output.metadata.redshiftserverless_namespace.admin_username == "dwadmin"
    error_message = "admin_user not passed through."
  }
  assert {
    condition     = aws_redshiftserverless_namespace.this.log_exports == toset(["connectionlog", "userlog"])
    error_message = "cloudwatch_logs.exports not passed through."
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["userlog"].name == "/aws/redshift/analytics/userlog" && aws_cloudwatch_log_group.this["connectionlog"].retention_in_days == 30 && aws_cloudwatch_log_group.this["connectionlog"].kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/2222" && length(aws_cloudwatch_log_group.this) == 2
    error_message = "The log groups must be created with the retention and key given."
  }
  assert {
    condition     = output.metadata.cloudwatch_log_group["userlog"].name == "/aws/redshift/analytics/userlog"
    error_message = "The log groups must be in the output, keyed by log type."
  }
  assert {
    condition     = aws_redshiftserverless_workgroup.this.base_capacity == 16 && aws_redshiftserverless_workgroup.this.max_capacity == 64 && aws_redshiftserverless_workgroup.this.port == 5440 && aws_redshiftserverless_workgroup.this.enhanced_vpc_routing == false
    error_message = "Workgroup settings not passed through."
  }
  assert {
    condition     = toset([for p in aws_redshiftserverless_workgroup.this.config_parameter : "${p.parameter_key}=${p.parameter_value}"]) == toset(["auto_mv=true", "datestyle=ISO, MDY", "enable_case_sensitive_identifier=false", "enable_user_activity_logging=true", "max_query_execution_time=3600", "query_group=default", "require_ssl=false", "search_path=$user, public", "use_fips_ssl=false"])
    error_message = "config_parameters not passed through."
  }
  assert {
    condition     = length(aws_redshiftserverless_workgroup.this.security_group_ids) == 2 && contains(aws_redshiftserverless_workgroup.this.security_group_ids, "sg-0000000000000000e")
    error_message = "additional_security_group_ids not attached."
  }
  assert {
    condition     = contains(aws_redshiftserverless_namespace.this.iam_roles, "arn:aws:iam::111111111111:role/spectrum") && length(aws_redshiftserverless_namespace.this.iam_roles) == 2
    error_message = "additional_iam_role_arns not associated."
  }
  assert {
    condition     = aws_iam_role_policy_attachment.this["spectrum"].policy_arn == "arn:aws:iam::111111111111:policy/spectrum" && length(aws_iam_role_policy.this) == 1
    error_message = "iam_role permissions not applied."
  }
  assert {
    condition = alltrue([
      for k, r in aws_vpc_security_group_ingress_rule.this : r.from_port == 5440 && r.to_port == 5440 && r.ip_protocol == "tcp"
    ])
    error_message = "Ingress rules must allow the workgroup's port only."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["ipv6"].cidr_ipv6 == "2001:db8::/56" && aws_vpc_security_group_ingress_rule.this["ipv6"].referenced_security_group_id == null && aws_vpc_security_group_ingress_rule.this["ipv6"].description == "IPv6 clients"
    error_message = "IPv6 source not passed as an IPv6 range."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["app"].referenced_security_group_id == "sg-0000000000000000f" && aws_vpc_security_group_ingress_rule.this["vpc"].description == "vpc" && aws_vpc_security_group_ingress_rule.this["list"].prefix_list_id == "pl-00000000000000000"
    error_message = "Ingress sources not passed through."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.this["s3"].from_port == 443 && aws_vpc_security_group_egress_rule.this["s3"].prefix_list_id == "pl-63a5400a"
    error_message = "Egress rule not passed through."
  }
}
