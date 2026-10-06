# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "additional_iam_role_arns" {
  description = <<-EOT
    More IAM roles to associate with the namespace, beside the one the module creates, given by ARN, such as `arn:aws:iam::123456789012:role/redshift-spectrum`. SQL commands such as `COPY` name the role to use with `IAM_ROLE '<arn>'`. Each role's trust policy must let the Amazon Redshift service principal, `redshift.amazonaws.com`, assume it.
  EOT
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for arn in var.additional_iam_role_arns : can(regex("^arn:[^:]+:iam::[0-9]{12}:role/", arn))])
    error_message = "Each entry in additional_iam_role_arns must be an IAM role ARN, such as arn:aws:iam::123456789012:role/redshift-spectrum."
  }
}

variable "additional_security_group_ids" {
  description = <<-EOT
    More security groups to attach to the workgroup, beside the one the module creates, such as `["sg-0123456789abcdef0"]`.
  EOT
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for id in var.additional_security_group_ids : startswith(id, "sg-")])
    error_message = "Each entry in additional_security_group_ids must be a security group ID, such as sg-0123456789abcdef0."
  }
}

variable "admin_password" {
  description = <<-EOT
    The admin user's password, if you want to set it yourself. Without it (the default), Amazon Redshift creates the password and keeps it in AWS Secrets Manager, where it rotates it; the module never sees it, so it is not in the Terraform state. The secret's ARN is in the `metadata` output, at `redshiftserverless_namespace.admin_password_secret_arn`.

    With a password, Secrets Manager is not used, and the password is stored in the Terraform state, so protect the state. Removing it later needs a step with the AWS CLI; see the README. It must have 8 to 64 printable ASCII characters, with at least one uppercase letter, one lowercase letter and one digit, and none of `/`, `@`, `"`, `'`, `\` or a space.
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = var.admin_password == null || (
      can(regex("^[!-~]{8,64}$", coalesce(var.admin_password, "-"))) &&
      can(regex("[A-Z]", coalesce(var.admin_password, "-"))) &&
      can(regex("[a-z]", coalesce(var.admin_password, "-"))) &&
      can(regex("[0-9]", coalesce(var.admin_password, "-"))) &&
      !can(regex("[/@\"'\\\\]", coalesce(var.admin_password, "-")))
    )
    error_message = "admin_password must have 8 to 64 printable ASCII characters, with at least one uppercase letter, one lowercase letter and one digit, and none of /, @, \", ', \\ or a space."
  }
}

variable "admin_user" {
  description = <<-EOT
    The namespace's admin user, the database superuser that Amazon Redshift creates with the namespace.

    - `username` - (Optional) The admin user's name. Defaults to `admin`. It must start with a letter and have up to 127 letters, digits and the characters `_`, `+`, `.`, `@` and `-`; `public` and `rdsdb` are refused. Without `admin_password`, change it later with the AWS CLI, not Terraform; see the README.
    - `secret_kms_key_id` - (Optional) The AWS Key Management Service (KMS) key that encrypts the Secrets Manager secret holding the password: a key ID, key ARN, alias name or alias ARN. Without it, Secrets Manager uses the AWS managed key `aws/secretsmanager`. Not used with `admin_password`. Change it later with the AWS CLI, not Terraform; see the README.
  EOT
  type = object({
    username          = optional(string, "admin")
    secret_kms_key_id = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_+.@-]{0,126}$", var.admin_user.username)) && !contains(["public", "rdsdb"], lower(var.admin_user.username))
    error_message = "admin_user.username must start with a letter, have up to 127 letters, digits and the characters _ + . @ -, and not be public or rdsdb."
  }
}

variable "base_capacity" {
  description = <<-EOT
    The workgroup's base capacity, in Redshift Processing Units (RPUs): the compute that serves queries. Defaults to `8`. Either `4`, or a multiple of `8` from `8` to `1024`. Amazon Redshift Serverless bills RPU-hours only while queries run, so a higher value costs more per query, not while idle.
  EOT
  type        = number
  default     = 8
  nullable    = false

  validation {
    condition     = var.base_capacity == 4 || (var.base_capacity >= 8 && var.base_capacity <= 1024 && var.base_capacity % 8 == 0)
    error_message = "base_capacity must be 4, or a multiple of 8 from 8 to 1024."
  }
}

variable "cloudwatch_logs" {
  description = <<-EOT
    Audit logs to send to Amazon CloudWatch Logs. The module creates one log group per log type, `/aws/redshift/<name>/<log type>`, before the namespace starts writing to it, so the retention below applies. With the default, `{}`, no logs are sent.

    - `exports` - (Optional) The log types to send: `connectionlog` (connection attempts and disconnections), `userlog` (changes to database users) and `useractivitylog` (every query, which needs `config_parameters.enable_user_activity_logging`, on by default).
    - `retention_in_days` - (Optional) Days to keep log events. Defaults to `7`. One of `1`, `3`, `5`, `7`, `14`, `30`, `60`, `90`, `120`, `150`, `180`, `365`, `400`, `545`, `731`, `1096`, `1827`, `2192`, `2557`, `2922`, `3288` or `3653`, or `0` to keep them forever.
    - `kms_key_id` - (Optional) ARN of a KMS key to encrypt the log groups with. Its key policy must let the CloudWatch Logs service principal for the Region use it. Without it, CloudWatch Logs encrypts them with its own key.
  EOT
  type = object({
    exports           = optional(list(string), [])
    retention_in_days = optional(number, 7)
    kms_key_id        = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for e in var.cloudwatch_logs.exports : contains(["connectionlog", "useractivitylog", "userlog"], e)])
    error_message = "cloudwatch_logs.exports entries must be connectionlog, useractivitylog or userlog."
  }

  validation {
    condition     = length(distinct(var.cloudwatch_logs.exports)) == length(var.cloudwatch_logs.exports)
    error_message = "cloudwatch_logs.exports lists a log type twice."
  }

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs.retention_in_days)
    error_message = "cloudwatch_logs.retention_in_days must be 0 (forever) or one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653."
  }

  validation {
    condition     = var.cloudwatch_logs.kms_key_id == null || startswith(coalesce(var.cloudwatch_logs.kms_key_id, "-"), "arn:")
    error_message = "cloudwatch_logs.kms_key_id must be the ARN of a KMS key."
  }
}

variable "config_parameters" {
  description = <<-EOT
    Database settings for the workgroup, as a map of parameter name to value, such as `{ max_query_execution_time = "3600" }`. Values are strings. See [the AWS documentation](https://docs.aws.amazon.com/redshift/latest/APIReference/API_ConfigParameter.html) for their meanings. The module sets every parameter, to the value given here or else to the value AWS gives a new workgroup:

    - `auto_mv` - Defaults to `"true"`.
    - `datestyle` - Defaults to `"ISO, MDY"`.
    - `enable_case_sensitive_identifier` - Defaults to `"false"`.
    - `enable_user_activity_logging` - Defaults to `"true"`. Needed for the `useractivitylog` in `cloudwatch_logs`.
    - `max_query_execution_time` - Seconds a query may run before it is canceled. Defaults to `"14400"`.
    - `query_group` - Defaults to `"default"`.
    - `require_ssl` - Clients must connect with TLS. Defaults to `"true"`.
    - `search_path` - Defaults to `"$user, public"`.
    - `use_fips_ssl` - Use FIPS-validated TLS. Defaults to `"false"`.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([for k in keys(var.config_parameters) : contains([
      "auto_mv", "datestyle", "enable_case_sensitive_identifier", "enable_user_activity_logging",
      "max_query_execution_time", "query_group", "require_ssl", "search_path", "use_fips_ssl",
    ], k)])
    error_message = "config_parameters keys must be auto_mv, datestyle, enable_case_sensitive_identifier, enable_user_activity_logging, max_query_execution_time, query_group, require_ssl, search_path or use_fips_ssl."
  }
}

variable "db_name" {
  description = <<-EOT
    The name of the first database in the namespace, such as `analytics`. Defaults to `dev`, the AWS default. Changing it later replaces the namespace and the workgroup, and deletes the data.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.db_name == null || can(regex("^[^\\s]{1,127}$", var.db_name))
    error_message = "db_name must have 1 to 127 characters and no spaces."
  }
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "enhanced_vpc_routing" {
  description = <<-EOT
    Send the workgroup's traffic to Amazon S3 and other AWS services, such as `COPY` and `UNLOAD`, through your VPC, where your security group rules, route tables and VPC endpoints apply. Defaults to `true`. The workgroup then needs a route to the service and a `security_group_egress` rule that allows it; see the README.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "iam_role" {
  description = <<-EOT
    Permissions for the IAM role the module creates and makes the namespace's default role. SQL commands such as `COPY`, `UNLOAD` and `CREATE EXTERNAL SCHEMA` use it with `IAM_ROLE default`. With the default, `{}`, the role has no permissions, so those commands fail until you grant what they need.

    - `policy_arns` - (Optional) Managed policies to attach, as a map of a name you choose to the policy ARN, such as `{ spectrum = aws_iam_policy.spectrum.arn }`. The names only identify each attachment, so a policy created in the same configuration can be used.
    - `source_policy_documents` - (Optional) IAM policy documents, as JSON, merged into the role's inline policy, such as `[data.aws_iam_policy_document.s3_read.json]`. Keep each grant to the buckets, keys and actions the commands need.
  EOT
  type = object({
    policy_arns             = optional(map(string), {})
    source_policy_documents = optional(list(string), [])
  })
  default  = {}
  nullable = false
}

variable "kms_key_id" {
  description = <<-EOT
    ARN of the AWS Key Management Service (KMS) key that encrypts the namespace's data and snapshots. The data is always encrypted; without a key, Amazon Redshift uses a key that AWS owns and manages, which you cannot see or audit. Use a customer managed key to control and log its use.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_id == null || startswith(coalesce(var.kms_key_id, "-"), "arn:")
    error_message = "kms_key_id must be the ARN of a KMS key, such as arn:aws:kms:us-east-1:123456789012:key/<key id>."
  }
}

variable "max_capacity" {
  description = <<-EOT
    The most RPUs the workgroup may scale to, to cap its cost. Without it, AWS sets no limit. At least `base_capacity`; `4` when `base_capacity` is `4`, otherwise a multiple of `8`, up to `5632`.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.max_capacity == null || try(var.max_capacity >= var.base_capacity && var.max_capacity <= 5632 && (var.max_capacity == 4 || var.max_capacity % 8 == 0), false)
    error_message = "max_capacity must be at least base_capacity, at most 5632, and 4 or a multiple of 8."
  }
}

variable "name" {
  description = <<-EOT
    The name of the namespace and the workgroup, such as `analytics-production`: 3 to 64 lowercase letters, digits and hyphens. It must be unique among the account's namespaces, and workgroups, in the Region. Changing it later replaces the namespace and the workgroup, and deletes the data.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]{3,64}$", var.name))
    error_message = "name must be 3 to 64 lowercase letters, digits and hyphens."
  }
}

variable "port" {
  description = <<-EOT
    The port the workgroup listens on: `5431` to `5455`, or `8191` to `8215`. Defaults to `5439`. The security group allows this port.
  EOT
  type        = number
  default     = 5439
  nullable    = false

  validation {
    condition     = floor(var.port) == var.port && ((var.port >= 5431 && var.port <= 5455) || (var.port >= 8191 && var.port <= 8215))
    error_message = "port must be a whole number from 5431 to 5455 or from 8191 to 8215."
  }
}

variable "publicly_accessible" {
  description = <<-EOT
    Make the workgroup's endpoint reachable from outside the VPC. Defaults to `false`. It also needs subnets with a route to an internet gateway and a `security_group_ingress` source outside the VPC. Keep workgroups private; reach them through the VPC instead.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the workgroup and everything else in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.
  EOT
  type        = string
  default     = null
}

variable "security_group_egress" {
  description = <<-EOT
    Where the workgroup may connect to. The workgroup needs no outbound rules to answer clients, so with the default, `{}`, it can open no connections. With `enhanced_vpc_routing`, `COPY` and `UNLOAD` reach Amazon S3 through the VPC, and need an entry such as HTTPS, port `443`, to the S3 prefix list. The keys are names you choose; they only identify each rule.

    Each entry takes:

    - `port` - (Required) The TCP port to allow.

    and exactly one of:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
    - `security_group_id` - A security group whose members the workgroup may connect to.
    - `prefix_list_id` - A managed prefix list, such as the one for S3 in the Region (`data.aws_ec2_managed_prefix_list` with name `com.amazonaws.<region>.s3`).

    and optionally:

    - `description` - (Optional) What the destination is. Defaults to the key.
  EOT
  type = map(object({
    port              = number
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for s in values(var.security_group_egress) :
      length([for v in [s.cidr_ipv4, s.cidr_ipv6, s.security_group_id, s.prefix_list_id] : v if v != null]) == 1
    ])
    error_message = "Each security_group_egress entry needs exactly one of cidr_ipv4, cidr_ipv6, security_group_id or prefix_list_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.security_group_egress) :
      (s.cidr_ipv4 == null || can(cidrnetmask(s.cidr_ipv4))) && (s.cidr_ipv6 == null || (can(cidrhost(s.cidr_ipv6, 0)) && strcontains(coalesce(s.cidr_ipv6, "-"), ":")))
    ])
    error_message = "security_group_egress: cidr_ipv4 must be an IPv4 range such as 10.0.0.0/16, and cidr_ipv6 an IPv6 range such as 2001:db8::/56."
  }

  validation {
    condition     = alltrue([for s in values(var.security_group_egress) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "security_group_egress: port must be a whole number from 1 to 65535."
  }
}

variable "security_group_ingress" {
  description = <<-EOT
    Who can reach the workgroup over the network. The module creates a security group for the workgroup that allows `port` (TCP) from each source listed here, and from nothing else. With the default, `{}`, no client can connect over the network; the Amazon Redshift Data API still works, because it does not connect through the VPC. The keys are names you choose; they only identify each rule, so a security group created in the same configuration can be used.

    Each source takes exactly one of:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
    - `security_group_id` - A security group whose members may connect, such as the group of your application servers.
    - `prefix_list_id` - A managed prefix list of ranges.

    and optionally:

    - `description` - (Optional) What the source is. Defaults to the key.
  EOT
  type = map(object({
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      length([for v in [s.cidr_ipv4, s.cidr_ipv6, s.security_group_id, s.prefix_list_id] : v if v != null]) == 1
    ])
    error_message = "Each security_group_ingress entry needs exactly one of cidr_ipv4, cidr_ipv6, security_group_id or prefix_list_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      (s.cidr_ipv4 == null || can(cidrnetmask(s.cidr_ipv4))) && (s.cidr_ipv6 == null || (can(cidrhost(s.cidr_ipv6, 0)) && strcontains(coalesce(s.cidr_ipv6, "-"), ":")))
    ])
    error_message = "security_group_ingress: cidr_ipv4 must be an IPv4 range such as 10.0.0.0/16, and cidr_ipv6 an IPv6 range such as 2001:db8::/56."
  }
}

variable "subnet_ids" {
  description = <<-EOT
    The subnets of `vpc_id` the workgroup's endpoint is placed in, such as `["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]`. AWS needs at least two, in different Availability Zones, each with at least 3 free IP addresses. Use private subnets.
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2 && alltrue([for id in var.subnet_ids : startswith(id, "subnet-")])
    error_message = "subnet_ids must list at least two subnet IDs, such as subnet-0123456789abcdef0, in different Availability Zones."
  }
}

variable "vpc_id" {
  description = <<-EOT
    The ID of the VPC the workgroup is in, such as `vpc-0123456789abcdef0`: the VPC of `subnet_ids`. The module creates the workgroup's security group in it.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "vpc_id must be a VPC ID, such as vpc-0123456789abcdef0."
  }
}
