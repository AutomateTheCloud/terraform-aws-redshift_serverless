# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The namespace holds the databases, users and data. Deleting it deletes them, with
# no final snapshot.
resource "aws_redshiftserverless_namespace" "this" {
  region         = var.region
  namespace_name = var.name
  db_name        = var.db_name
  kms_key_id     = var.kms_key_id
  log_exports    = var.cloudwatch_logs.exports

  admin_username                   = var.admin_user.username
  admin_user_password              = var.admin_password
  manage_admin_password            = local.manage_admin_password ? true : null
  admin_password_secret_kms_key_id = local.manage_admin_password ? var.admin_user.secret_kms_key_id : null

  iam_roles            = concat([aws_iam_role.this.arn], var.additional_iam_role_arns)
  default_iam_role_arn = aws_iam_role.this.arn

  tags = local.tags

  # The log groups exist before the namespace can write to them.
  depends_on = [aws_cloudwatch_log_group.this]
}
