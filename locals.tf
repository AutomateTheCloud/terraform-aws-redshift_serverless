# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # The description of the security group and the IAM role.
  description = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): Redshift Serverless ${var.name}"

  # A group description may contain only these characters, so anything else in the
  # details names is dropped rather than failing the create.
  security_group_description = substr(replace(local.description, "/[^A-Za-z0-9 ._:/()#,@\\[\\]+=&;{}!$*-]/", ""), 0, 255)

  # IAM descriptions refuse characters outside Latin-1, so those are dropped too.
  iam_role_description = substr(replace(local.description, "/[^\\t\\n\\r -~\u00a1-\u00ff]/", ""), 0, 1000)

  # Every workgroup parameter, with the values AWS gives a new workgroup, then the
  # caller's. The module always sends all of them: provider 6.0.0 saves every parameter
  # AWS reports, so sending only some made every later plan try to remove the others
  # (seen in AWS).
  config_parameters = merge({
    auto_mv                          = "true"
    datestyle                        = "ISO, MDY"
    enable_case_sensitive_identifier = "false"
    enable_user_activity_logging     = "true"
    max_query_execution_time         = "14400"
    query_group                      = "default"
    require_ssl                      = "true"
    search_path                      = "$user, public"
    use_fips_ssl                     = "false"
  }, var.config_parameters)

  # Amazon Redshift keeps the admin password in Secrets Manager unless one is given.
  # Whether one is given is not secret, so it can decide the arguments below.
  manage_admin_password = nonsensitive(var.admin_password == null)
}
