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
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_subnet" {
    defaults = { id = "subnet-0000000000000000a" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:111111111111:key/1111" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::111111111111:policy/same-run" }
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

# The VPC, subnets, key, policy, client security group and S3 prefix list come from the
# same run, so their IDs are unknown when the module plans. The rules and attachments
# are keyed by names from the inputs, so the plan succeeds. The fixture also passes a
# sensitive admin password, and its own output, not marked sensitive, must still work.
run "same_run_plan" {
  command = plan
  module {
    source = "./tests/fixtures/same_run"
  }
  assert {
    condition     = toset(keys(module.redshift_serverless.metadata.vpc_security_group_ingress_rule)) == toset(["app", "vpc"])
    error_message = "Both rules must be planned."
  }
}

run "same_run_apply" {
  command = apply
  module {
    source = "./tests/fixtures/same_run"
  }
  assert {
    condition     = output.metadata.vpc_security_group_ingress_rule["app"].referenced_security_group_id == aws_security_group.app.id && output.metadata.redshiftserverless_namespace.kms_key_id == aws_kms_key.this.arn
    error_message = "The same-run security group and key must reach the module."
  }
  assert {
    condition     = output.metadata.iam_role_policy_attachment["same_run"].policy_arn == aws_iam_policy.this.arn
    error_message = "The same-run policy must be attached."
  }
}
