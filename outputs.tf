# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `redshiftserverless_namespace` - The namespace: its `arn`, `namespace_name`, `namespace_id`, `db_name`, `admin_username`, `admin_password_secret_arn` (the Secrets Manager secret with the admin password, `null` when `admin_password` is set), `kms_key_id` (`AWS_OWNED_KMS_KEY` without `kms_key_id`), `iam_roles`, `default_iam_role_arn`, and the rest of its attributes.
    - `redshiftserverless_workgroup` - The workgroup: its `endpoint` (a list with the `address` clients connect to, the `port`, and the `vpc_endpoint` with its network interfaces), `arn`, `workgroup_name`, `workgroup_id`, `base_capacity`, `max_capacity`, `config_parameter`, and the rest of its attributes.
    - `cloudwatch_log_group` - The log groups, keyed by log type, each with its `name`, `arn` and `retention_in_days`, or `null` when no logs are sent.
    - `iam_role` - The namespace's default IAM role, with its `arn` and `name`.
    - `iam_role_policy` - The role's inline policy, built from `iam_role.source_policy_documents`, or `null` when there is none.
    - `iam_role_policy_attachment` - The managed policy attachments, keyed like `iam_role.policy_arns`, or `null` when there are none.
    - `security_group` - The workgroup's security group, with its `id`, `arn` and `name`.
    - `vpc_security_group_ingress_rule` - The ingress rules, keyed like `security_group_ingress`, or `null` when there are none.
    - `vpc_security_group_egress_rule` - The egress rules, keyed like `security_group_egress`, or `null` when there are none.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource. Resources that are not created are null.
    cloudwatch_log_group            = local.output_resources.cloudwatch_log_group
    iam_role                        = local.output_resources.iam_role
    iam_role_policy                 = local.output_resources.iam_role_policy
    iam_role_policy_attachment      = local.output_resources.iam_role_policy_attachment
    redshiftserverless_namespace    = local.output_resources.redshiftserverless_namespace
    redshiftserverless_workgroup    = local.output_resources.redshiftserverless_workgroup
    security_group                  = local.output_resources.security_group
    vpc_security_group_egress_rule  = local.output_resources.vpc_security_group_egress_rule
    vpc_security_group_ingress_rule = local.output_resources.vpc_security_group_ingress_rule
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource, or
  # iterating over it, would also reference its deprecated and sensitive attributes, and
  # every caller's plan would print deprecation warnings or the output would become
  # sensitive. Keyed and counted resources are indexed from the inputs for the same
  # reason. The provider marks the namespace's admin_username as sensitive, so it is
  # taken from the input instead. The namespace's log_exports is left out: when empty,
  # the provider saves it as null and reads it back as [], so the first plan after a
  # create showed the output changing (seen in AWS). The log types are in
  # var.cloudwatch_logs.
  output_resources = {
    cloudwatch_log_group = length(var.cloudwatch_logs.exports) == 0 ? null : {
      for k in var.cloudwatch_logs.exports : k => {
        arn               = aws_cloudwatch_log_group.this[k].arn
        id                = aws_cloudwatch_log_group.this[k].id
        kms_key_id        = aws_cloudwatch_log_group.this[k].kms_key_id
        log_group_class   = aws_cloudwatch_log_group.this[k].log_group_class
        name              = aws_cloudwatch_log_group.this[k].name
        name_prefix       = aws_cloudwatch_log_group.this[k].name_prefix
        region            = aws_cloudwatch_log_group.this[k].region
        retention_in_days = aws_cloudwatch_log_group.this[k].retention_in_days
        skip_destroy      = aws_cloudwatch_log_group.this[k].skip_destroy
        tags              = aws_cloudwatch_log_group.this[k].tags
        tags_all          = aws_cloudwatch_log_group.this[k].tags_all
      }
    }

    iam_role = {
      arn                   = aws_iam_role.this.arn
      assume_role_policy    = aws_iam_role.this.assume_role_policy
      create_date           = aws_iam_role.this.create_date
      description           = aws_iam_role.this.description
      force_detach_policies = aws_iam_role.this.force_detach_policies
      id                    = aws_iam_role.this.id
      max_session_duration  = aws_iam_role.this.max_session_duration
      name                  = aws_iam_role.this.name
      name_prefix           = aws_iam_role.this.name_prefix
      path                  = aws_iam_role.this.path
      permissions_boundary  = aws_iam_role.this.permissions_boundary
      tags                  = aws_iam_role.this.tags
      tags_all              = aws_iam_role.this.tags_all
      unique_id             = aws_iam_role.this.unique_id
    }

    iam_role_policy = length(var.iam_role.source_policy_documents) == 0 ? null : {
      id          = aws_iam_role_policy.this[0].id
      name        = aws_iam_role_policy.this[0].name
      name_prefix = aws_iam_role_policy.this[0].name_prefix
      policy      = aws_iam_role_policy.this[0].policy
      role        = aws_iam_role_policy.this[0].role
    }

    redshiftserverless_namespace = {
      admin_password_secret_arn        = aws_redshiftserverless_namespace.this.admin_password_secret_arn
      admin_password_secret_kms_key_id = aws_redshiftserverless_namespace.this.admin_password_secret_kms_key_id
      admin_username                   = var.admin_user.username
      arn                              = aws_redshiftserverless_namespace.this.arn
      db_name                          = aws_redshiftserverless_namespace.this.db_name
      default_iam_role_arn             = aws_redshiftserverless_namespace.this.default_iam_role_arn
      iam_roles                        = aws_redshiftserverless_namespace.this.iam_roles
      id                               = aws_redshiftserverless_namespace.this.id
      kms_key_id                       = aws_redshiftserverless_namespace.this.kms_key_id
      manage_admin_password            = aws_redshiftserverless_namespace.this.manage_admin_password
      namespace_id                     = aws_redshiftserverless_namespace.this.namespace_id
      namespace_name                   = aws_redshiftserverless_namespace.this.namespace_name
      region                           = aws_redshiftserverless_namespace.this.region
      tags                             = aws_redshiftserverless_namespace.this.tags
      tags_all                         = aws_redshiftserverless_namespace.this.tags_all
    }

    redshiftserverless_workgroup = {
      arn                      = aws_redshiftserverless_workgroup.this.arn
      base_capacity            = aws_redshiftserverless_workgroup.this.base_capacity
      config_parameter         = aws_redshiftserverless_workgroup.this.config_parameter
      endpoint                 = aws_redshiftserverless_workgroup.this.endpoint
      enhanced_vpc_routing     = aws_redshiftserverless_workgroup.this.enhanced_vpc_routing
      id                       = aws_redshiftserverless_workgroup.this.id
      max_capacity             = aws_redshiftserverless_workgroup.this.max_capacity
      namespace_name           = aws_redshiftserverless_workgroup.this.namespace_name
      port                     = aws_redshiftserverless_workgroup.this.port
      price_performance_target = aws_redshiftserverless_workgroup.this.price_performance_target
      publicly_accessible      = aws_redshiftserverless_workgroup.this.publicly_accessible
      region                   = aws_redshiftserverless_workgroup.this.region
      security_group_ids       = aws_redshiftserverless_workgroup.this.security_group_ids
      subnet_ids               = aws_redshiftserverless_workgroup.this.subnet_ids
      tags                     = aws_redshiftserverless_workgroup.this.tags
      tags_all                 = aws_redshiftserverless_workgroup.this.tags_all
      track_name               = aws_redshiftserverless_workgroup.this.track_name
      workgroup_id             = aws_redshiftserverless_workgroup.this.workgroup_id
      workgroup_name           = aws_redshiftserverless_workgroup.this.workgroup_name
    }

    security_group = {
      arn                    = aws_security_group.this.arn
      description            = aws_security_group.this.description
      id                     = aws_security_group.this.id
      name                   = aws_security_group.this.name
      name_prefix            = aws_security_group.this.name_prefix
      owner_id               = aws_security_group.this.owner_id
      region                 = aws_security_group.this.region
      revoke_rules_on_delete = aws_security_group.this.revoke_rules_on_delete
      tags                   = aws_security_group.this.tags
      tags_all               = aws_security_group.this.tags_all
      vpc_id                 = aws_security_group.this.vpc_id
    }

    iam_role_policy_attachment = length(var.iam_role.policy_arns) == 0 ? null : {
      for k in keys(var.iam_role.policy_arns) : k => {
        id         = aws_iam_role_policy_attachment.this[k].id
        policy_arn = aws_iam_role_policy_attachment.this[k].policy_arn
        role       = aws_iam_role_policy_attachment.this[k].role
      }
    }

    vpc_security_group_ingress_rule = length(var.security_group_ingress) == 0 ? null : {
      for k in keys(var.security_group_ingress) : k => {
        arn                          = aws_vpc_security_group_ingress_rule.this[k].arn
        cidr_ipv4                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv4
        cidr_ipv6                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv6
        description                  = aws_vpc_security_group_ingress_rule.this[k].description
        from_port                    = aws_vpc_security_group_ingress_rule.this[k].from_port
        id                           = aws_vpc_security_group_ingress_rule.this[k].id
        ip_protocol                  = aws_vpc_security_group_ingress_rule.this[k].ip_protocol
        prefix_list_id               = aws_vpc_security_group_ingress_rule.this[k].prefix_list_id
        referenced_security_group_id = aws_vpc_security_group_ingress_rule.this[k].referenced_security_group_id
        region                       = aws_vpc_security_group_ingress_rule.this[k].region
        security_group_id            = aws_vpc_security_group_ingress_rule.this[k].security_group_id
        security_group_rule_id       = aws_vpc_security_group_ingress_rule.this[k].security_group_rule_id
        tags                         = aws_vpc_security_group_ingress_rule.this[k].tags
        tags_all                     = aws_vpc_security_group_ingress_rule.this[k].tags_all
        to_port                      = aws_vpc_security_group_ingress_rule.this[k].to_port
      }
    }

    vpc_security_group_egress_rule = length(var.security_group_egress) == 0 ? null : {
      for k in keys(var.security_group_egress) : k => {
        arn                          = aws_vpc_security_group_egress_rule.this[k].arn
        cidr_ipv4                    = aws_vpc_security_group_egress_rule.this[k].cidr_ipv4
        cidr_ipv6                    = aws_vpc_security_group_egress_rule.this[k].cidr_ipv6
        description                  = aws_vpc_security_group_egress_rule.this[k].description
        from_port                    = aws_vpc_security_group_egress_rule.this[k].from_port
        id                           = aws_vpc_security_group_egress_rule.this[k].id
        ip_protocol                  = aws_vpc_security_group_egress_rule.this[k].ip_protocol
        prefix_list_id               = aws_vpc_security_group_egress_rule.this[k].prefix_list_id
        referenced_security_group_id = aws_vpc_security_group_egress_rule.this[k].referenced_security_group_id
        region                       = aws_vpc_security_group_egress_rule.this[k].region
        security_group_id            = aws_vpc_security_group_egress_rule.this[k].security_group_id
        security_group_rule_id       = aws_vpc_security_group_egress_rule.this[k].security_group_rule_id
        tags                         = aws_vpc_security_group_egress_rule.this[k].tags
        tags_all                     = aws_vpc_security_group_egress_rule.this[k].tags_all
        to_port                      = aws_vpc_security_group_egress_rule.this[k].to_port
      }
    }
  }
}
