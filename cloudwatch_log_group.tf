# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The log groups Amazon Redshift writes the namespace's audit logs to. Without them,
# Amazon Redshift creates the groups itself on the first event, outside Terraform, and
# keeps the events forever (seen in AWS). It writes into groups that already exist.
resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(var.cloudwatch_logs.exports)

  region            = var.region
  name              = "/aws/redshift/${var.name}/${each.key}"
  retention_in_days = var.cloudwatch_logs.retention_in_days
  kms_key_id        = var.cloudwatch_logs.kms_key_id

  tags = local.tags
}
