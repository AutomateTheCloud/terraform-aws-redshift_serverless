# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.security_group_ingress

  region            = var.region
  security_group_id = aws_security_group.this.id
  description       = coalesce(each.value.description, each.key)
  ip_protocol       = "tcp"
  from_port         = var.port
  to_port           = var.port

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  referenced_security_group_id = each.value.security_group_id
  prefix_list_id               = each.value.prefix_list_id

  tags = merge(local.tags, { Name = "redshift-${var.name}-${each.key}" })

  # When the security group is replaced, the new group gets its rules before the
  # workgroup moves to it, and the old rules stay until it has (with depends_on in
  # redshiftserverless_workgroup.tf).
  lifecycle {
    create_before_destroy = true
  }
}
