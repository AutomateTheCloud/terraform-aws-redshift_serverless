# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The workgroup's security group. It allows var.port from the sources in
# security_group_ingress, and connections out only to security_group_egress. The AWS
# provider removes the rule that allows all outbound traffic, which AWS adds to every
# new group.
resource "aws_security_group" "this" {
  region                 = var.region
  name_prefix            = "redshift-${var.name}-"
  description            = local.security_group_description
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(local.tags, { Name = "redshift-${var.name}" })

  # A new name or description replaces the group. Creating the new group first lets
  # the workgroup move to it before the old one, which it still uses, is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
