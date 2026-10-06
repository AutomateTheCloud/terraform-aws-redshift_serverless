# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The namespace's default IAM role, which SQL commands such as COPY use with
# IAM_ROLE default. It has only the permissions given in var.iam_role. IAM names are
# global, so a prefix with a unique suffix lets the module be used with the same name
# in several Regions.
resource "aws_iam_role" "this" {
  name_prefix = "redshift-serverless-"
  description = local.iam_role_description
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = data.aws_service_principal.redshift.name }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

data "aws_iam_policy_document" "this" {
  count = length(var.iam_role.source_policy_documents) > 0 ? 1 : 0

  source_policy_documents = var.iam_role.source_policy_documents
}

resource "aws_iam_role_policy" "this" {
  count = length(var.iam_role.source_policy_documents) > 0 ? 1 : 0

  name   = "redshift-serverless"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this[0].json
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.iam_role.policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
