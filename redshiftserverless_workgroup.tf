# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The workgroup is the compute that runs queries on the namespace's data, and the
# endpoint clients connect to.
resource "aws_redshiftserverless_workgroup" "this" {
  region         = var.region
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name = var.name

  base_capacity        = var.base_capacity
  max_capacity         = var.max_capacity
  port                 = var.port
  enhanced_vpc_routing = var.enhanced_vpc_routing
  publicly_accessible  = var.publicly_accessible

  subnet_ids         = var.subnet_ids
  security_group_ids = concat([aws_security_group.this.id], var.additional_security_group_ids)

  dynamic "config_parameter" {
    for_each = local.config_parameters

    content {
      parameter_key   = config_parameter.key
      parameter_value = config_parameter.value
    }
  }

  tags = local.tags

  # AWS refuses to delete a namespace that still has a workgroup, so a change that
  # replaces the namespace, such as a new db_name, replaces the workgroup with it
  # (seen in AWS). namespace_id changes only when the namespace is created again.
  lifecycle {
    replace_triggered_by = [aws_redshiftserverless_namespace.this.namespace_id]
  }

  # When the security group is replaced, its old rules are deleted only after the
  # workgroup has moved to the new group.
  depends_on = [
    aws_vpc_security_group_ingress_rule.this,
    aws_vpc_security_group_egress_rule.this,
  ]
}
