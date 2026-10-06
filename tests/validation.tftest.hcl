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

run "details_scope_empty" {
  command = plan
  variables {
    details = { scope = " ", purpose = "Analytics", environment = "test" }
  }
  expect_failures = [var.details]
}

run "details_purpose_empty" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "", environment = "test" }
  }
  expect_failures = [var.details]
}

run "details_environment_empty" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Analytics", environment = "" }
  }
  expect_failures = [var.details]
}

run "name_empty" {
  command = plan
  variables {
    name = ""
  }
  expect_failures = [var.name]
}

run "name_too_short" {
  command = plan
  variables {
    name = "ab"
  }
  expect_failures = [var.name]
}

run "name_uppercase" {
  command = plan
  variables {
    name = "Analytics"
  }
  expect_failures = [var.name]
}

run "name_underscore" {
  command = plan
  variables {
    name = "my_analytics"
  }
  expect_failures = [var.name]
}

run "name_too_long" {
  command = plan
  variables {
    name = "a2345678901234567890123456789012345678901234567890123456789012345"
  }
  expect_failures = [var.name]
}

run "vpc_id_not_vpc" {
  command = plan
  variables {
    vpc_id = "subnet-0123456789abcdef0"
  }
  expect_failures = [var.vpc_id]
}

run "subnet_ids_empty" {
  command = plan
  variables {
    subnet_ids = []
  }
  expect_failures = [var.subnet_ids]
}

run "subnet_ids_one" {
  command = plan
  variables {
    subnet_ids = ["subnet-0000000000000000a"]
  }
  expect_failures = [var.subnet_ids]
}

run "subnet_ids_not_subnet" {
  command = plan
  variables {
    subnet_ids = ["subnet-0000000000000000a", "sg-0123456789abcdef0"]
  }
  expect_failures = [var.subnet_ids]
}

run "base_capacity_3" {
  command = plan
  variables {
    base_capacity = 3
  }
  expect_failures = [var.base_capacity]
}

run "base_capacity_12" {
  command = plan
  variables {
    base_capacity = 12
  }
  expect_failures = [var.base_capacity]
}

run "base_capacity_1032" {
  command = plan
  variables {
    base_capacity = 1032
  }
  expect_failures = [var.base_capacity]
}

run "max_capacity_below_base" {
  command = plan
  variables {
    max_capacity = 4
  }
  expect_failures = [var.max_capacity]
}

run "max_capacity_not_multiple" {
  command = plan
  variables {
    max_capacity = 12
  }
  expect_failures = [var.max_capacity]
}

run "max_capacity_too_high" {
  command = plan
  variables {
    max_capacity = 5640
  }
  expect_failures = [var.max_capacity]
}

run "port_5430" {
  command = plan
  variables {
    port = 5430
  }
  expect_failures = [var.port]
}

run "port_5456" {
  command = plan
  variables {
    port = 5456
  }
  expect_failures = [var.port]
}

run "port_8190" {
  command = plan
  variables {
    port = 8190
  }
  expect_failures = [var.port]
}

run "port_8216" {
  command = plan
  variables {
    port = 8216
  }
  expect_failures = [var.port]
}

run "admin_username_digit" {
  command = plan
  variables {
    admin_user = { username = "1admin" }
  }
  expect_failures = [var.admin_user]
}

run "admin_username_public" {
  command = plan
  variables {
    admin_user = { username = "PUBLIC" }
  }
  expect_failures = [var.admin_user]
}

run "admin_username_rdsdb" {
  command = plan
  variables {
    admin_user = { username = "rdsdb" }
  }
  expect_failures = [var.admin_user]
}

run "admin_username_too_long" {
  command = plan
  variables {
    admin_user = { username = "abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
  }
  expect_failures = [var.admin_user]
}

run "admin_username_space" {
  command = plan
  variables {
    admin_user = { username = "db admin" }
  }
  expect_failures = [var.admin_user]
}

run "admin_password_short" {
  command = plan
  variables {
    admin_password = "Abc1234"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_long" {
  command = plan
  variables {
    admin_password = "Abc1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_no_lower" {
  command = plan
  variables {
    admin_password = "ABCDEFGH1234"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_no_upper" {
  command = plan
  variables {
    admin_password = "abcdefgh1234"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_no_digit" {
  command = plan
  variables {
    admin_password = "Abcdefghijkl"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_slash" {
  command = plan
  variables {
    admin_password = "Abcdefgh12/34"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_at" {
  command = plan
  variables {
    admin_password = "Abcdefgh12@34"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_space" {
  command = plan
  variables {
    admin_password = "Abcdefgh12 34"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_quote" {
  command = plan
  variables {
    admin_password = "Abcdefgh12\"34"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_apostrophe" {
  command = plan
  variables {
    admin_password = "Abcdefgh12'34"
  }
  expect_failures = [var.admin_password]
}

run "admin_password_backslash" {
  command = plan
  variables {
    admin_password = "Abcdefgh12\\34"
  }
  expect_failures = [var.admin_password]
}

run "db_name_space" {
  command = plan
  variables {
    db_name = "my db"
  }
  expect_failures = [var.db_name]
}

run "db_name_empty" {
  command = plan
  variables {
    db_name = ""
  }
  expect_failures = [var.db_name]
}

run "kms_key_id_alias" {
  command = plan
  variables {
    kms_key_id = "alias/aws/redshift"
  }
  expect_failures = [var.kms_key_id]
}

run "cloudwatch_logs_unknown" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["auditlog"] }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "cloudwatch_logs_retention" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["userlog"], retention_in_days = 2 }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "cloudwatch_logs_kms_alias" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["userlog"], kms_key_id = "alias/logs" }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "cloudwatch_logs_twice" {
  command = plan
  variables {
    cloudwatch_logs = { exports = ["userlog", "userlog"] }
  }
  expect_failures = [var.cloudwatch_logs]
}

run "config_parameters_unknown" {
  command = plan
  variables {
    config_parameters = { wlm_json_configuration = "[]" }
  }
  expect_failures = [var.config_parameters]
}

run "additional_sg_not_sg" {
  command = plan
  variables {
    additional_security_group_ids = ["vpc-0123456789abcdef0"]
  }
  expect_failures = [var.additional_security_group_ids]
}

run "additional_role_not_role" {
  command = plan
  variables {
    additional_iam_role_arns = ["arn:aws:iam::111111111111:policy/x"]
  }
  expect_failures = [var.additional_iam_role_arns]
}

run "ingress_no_source" {
  command = plan
  variables {
    security_group_ingress = { a = { description = "none" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "ingress_two_sources" {
  command = plan
  variables {
    security_group_ingress = { a = { cidr_ipv4 = "10.0.0.0/16", security_group_id = "sg-0000000000000000f" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "ingress_bad_ipv4" {
  command = plan
  variables {
    security_group_ingress = { a = { cidr_ipv4 = "10.0.0.0" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "ingress_ipv4_as_ipv6" {
  command = plan
  variables {
    security_group_ingress = { a = { cidr_ipv6 = "10.0.0.0/16" } }
  }
  expect_failures = [var.security_group_ingress]
}

run "egress_no_destination" {
  command = plan
  variables {
    security_group_egress = { a = { port = 443 } }
  }
  expect_failures = [var.security_group_egress]
}

run "egress_bad_port" {
  command = plan
  variables {
    security_group_egress = { a = { port = 70000, cidr_ipv4 = "10.0.0.0/16" } }
  }
  expect_failures = [var.security_group_egress]
}

run "egress_bad_ipv6" {
  command = plan
  variables {
    security_group_egress = { a = { port = 443, cidr_ipv6 = "2001:db8::" } }
  }
  expect_failures = [var.security_group_egress]
}

run "accepted_limits" {
  command = plan
  variables {
    base_capacity  = 4
    max_capacity   = 4
    port           = 8215
    admin_user     = { username = "a.b+c@d-e_f" }
    admin_password = "Ab1!#$%^&*()-_=+[]{}:?~"
  }
}

run "accepted_largest" {
  command = plan
  variables {
    base_capacity = 1024
    max_capacity  = 5632
    port          = 5431
    name          = "a23"
    db_name       = "My-DB"
  }
}
