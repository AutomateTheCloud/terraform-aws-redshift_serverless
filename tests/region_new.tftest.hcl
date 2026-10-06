# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "ap-southeast-7", description = "Asia Pacific (Thailand)" }
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

# Any Region plans, including ones added after this module was written.
run "region_not_in_old_tables" {
  command = plan
  variables { region = "ap-southeast-7" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse7" && aws_security_group.this.description == "Test - Analytics [test] (ap-southeast-7): Redshift Serverless analytics"
    error_message = "Unexpected abbreviation."
  }
}

run "region_mexico" {
  command = plan
  override_data {
    target = data.aws_region.this
    values = { region = "mx-central-1", description = "Mexico (Central)" }
  }
  assert {
    condition     = output.metadata.aws.region.abbr == "mxc1"
    error_message = "Unexpected abbreviation."
  }
}
