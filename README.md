# Terraform module for Amazon Redshift Serverless

Creates an Amazon Redshift Serverless namespace, which holds the databases, users and data, and a workgroup, the compute that runs queries and the endpoint clients connect to. It also creates the namespace's default IAM role, for commands such as `COPY` and `UNLOAD`, and a security group that controls which clients can reach the workgroup.

The defaults are the settings most data warehouses should have. A workgroup created with only the required inputs is private, encrypted, requires TLS, and cannot be reached over the network until you allow a source. Its IAM role has no permissions until you grant them. Amazon Redshift creates the admin password and keeps it in AWS Secrets Manager, so it does not appear in the Terraform state.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Encryption at rest | Always on, with a key AWS owns | `kms_key_id` |
| Admin user | `admin`, with a password created by Amazon Redshift and kept and rotated in Secrets Manager | `admin_user`, `admin_password` |
| Network access | None: no client can connect through the VPC | `security_group_ingress` |
| Outbound traffic | None | `security_group_egress` |
| Public endpoint | Off | `publicly_accessible` |
| TLS for clients | Required (`require_ssl`) | `config_parameters` |
| Enhanced VPC routing | On: `COPY` and `UNLOAD` traffic goes through your VPC | `enhanced_vpc_routing` |
| IAM role permissions | None | `iam_role` |
| Capacity | 8 RPUs base, no maximum | `base_capacity`, `max_capacity` |
| Port | `5439` | `port` |
| Audit logs in CloudWatch | None | `log_exports` |

## Usage

```hcl
module "redshift_serverless" {
  source  = "AutomateTheCloud/redshift_serverless/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Analytics"
    environment = "Production"
  }

  name       = "analytics-production"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]

  security_group_ingress = {
    app = { security_group_id = "sg-0123456789abcdef0", description = "Application servers" }
  }
}
```

`details`, `name`, `vpc_id` and `subnet_ids` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags on every resource.

Clients connect to `module.redshift_serverless.metadata.redshiftserverless_workgroup.endpoint[0].address` on port `5439`, as `admin`. The password is in the Secrets Manager secret at `module.redshift_serverless.metadata.redshiftserverless_namespace.admin_password_secret_arn`.

The module uses your default `aws` provider and creates everything in that provider's Region. To create the workgroup somewhere else without configuring another provider, set `region`:

```hcl
module "redshift_serverless_us_west_2" {
  source  = "AutomateTheCloud/redshift_serverless/aws"
  version = "~> 1.0"

  region     = "us-west-2"
  details    = { scope = "Automate the Cloud", purpose = "Analytics", environment = "Production" }
  name       = "analytics-production"
  vpc_id     = "vpc-0abcdef0123456789"
  subnet_ids = ["subnet-0abcdef0123456789", "subnet-0abcdef0123456788", "subnet-0abcdef0123456787"]
}
```

The VPC and subnets must be in that Region too.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the workgroup belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Analytics"          # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a workgroup in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the workgroup, its key, its network and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Analytics"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "warehouse" {
  source  = "AutomateTheCloud/redshift_serverless/aws"
  version = "~> 1.0"

  details    = local.details
  name       = "analytics-production"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.warehouse.metadata.redshiftserverless_workgroup.endpoint[0].address` for the host name clients connect to, or `module.warehouse.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`, given a VPC and private subnets.

- [Basic workgroup](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/tree/main/examples/basic): a private, encrypted workgroup that anything in the VPC can reach.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/tree/main/examples/complete): a workgroup that loads data from one S3 bucket, with a customer managed key, an IAM role limited to that bucket, audit logs, a capacity limit, and access from one security group.

## Things to know

### The admin password

By default, Amazon Redshift creates the admin user's password, stores it in a Secrets Manager secret it manages, and rotates it. Terraform never sees the password, so it is not in the state, the plan or the outputs. The secret holds the `username` and `password`, and its ARN is in `metadata.redshiftserverless_namespace.admin_password_secret_arn`:

```shell
aws secretsmanager get-secret-value --secret-id '<secret ARN>' --query SecretString --output text
```

Because the password changes on rotation, applications should read the secret when they connect, rather than keep a copy. Better still, give each application its own database user with only the grants it needs, or let it sign in with its IAM identity through `aws redshift-serverless get-credentials` or the [Amazon Redshift Data API](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api.html).

With `admin_password`, the module sets the password you give instead, and it is stored in the Terraform state, so keep the state in an encrypted backend that only administrators can read.

**Some changes to the admin user fail, or seem to succeed and do nothing.** The AWS provider (seen with 6.0.0 and 6.67.0) sends these changes in a way AWS refuses. It still saves the new values in the state, so the next plan shows no changes while AWS keeps the old ones. Make them with the AWS CLI instead, before or after changing the inputs:

| Change | What goes wrong | AWS CLI command |
|---|---|---|
| Remove `admin_password`, to have Amazon Redshift manage the password | `Member must have length greater than or equal to 8` | `aws redshift-serverless update-namespace --namespace-name <name> --manage-admin-password` |
| Change `admin_user.username` without `admin_password` | The same error | `aws redshift-serverless update-namespace --namespace-name <name> --admin-username <new name> --manage-admin-password`, adding `--admin-password-secret-kms-key-id <key>` if you set `admin_user.secret_kms_key_id` |
| Change `admin_user.secret_kms_key_id` | `The AdminPasswordSecretKmsKeyId parameter cannot be provided unless ManagedAdminPassword is true` | `aws redshift-serverless update-namespace --namespace-name <name> --manage-admin-password --admin-password-secret-kms-key-id <key>` |

Wait until the namespace shows `AVAILABLE` again, which took up to 6 minutes in AWS, then run `terraform apply`; it changes no resources, and saves the new secret's ARN in the outputs. A new user name gets a new secret, `redshift!<name>-<user name>`.

These work as expected: setting `admin_password` on a namespace whose password Amazon Redshift manages (AWS deletes the secret), and changing `admin_user.username` while `admin_password` is set. After the first, the next plan shows only `metadata` changing; `terraform apply` saves it.

### Network access and loading data

The module's security group allows `port`, over TCP, from the sources in `security_group_ingress`, and nothing else. The [Amazon Redshift Data API](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api.html) does not connect through the VPC, so it works with no ingress rules at all (seen in AWS).

The group allows no outbound traffic until you add `security_group_egress` rules. With `enhanced_vpc_routing`, on by default, `COPY` and `UNLOAD` reach Amazon S3 through your VPC, so they need both a route to S3, such as a gateway endpoint for S3 on the subnets' route tables, and an egress rule such as:

```hcl
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.us-east-1.s3"
}

security_group_egress = {
  s3 = { port = 443, prefix_list_id = data.aws_ec2_managed_prefix_list.s3.id }
}
```

Without them, `COPY` does not fail quickly: in AWS, it was still waiting after more than 4 minutes, and it would have run until `max_query_execution_time`, 4 hours by default, with the workgroup billed while it ran.

The IAM role the module creates is the namespace's default role, so `COPY ... IAM_ROLE default` uses it, but it has no permissions until you grant them in `iam_role`. Grant only the buckets and actions the commands need; the [complete example](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/tree/main/examples/complete) grants read access to one bucket. Objects encrypted with a customer managed KMS key also need `kms:Decrypt` on that key.

Keep workgroups private. `publicly_accessible = true` makes the endpoint reachable from outside the VPC, but only from sources in `security_group_ingress`, and only from subnets with a route to an internet gateway.

### Encryption

The namespace's data is always encrypted. Without `kms_key_id`, Amazon Redshift uses a key that AWS owns, which you cannot see, audit or share. Setting `kms_key_id` later changes the key in place and keeps the data; in AWS, the change took about 5 minutes. Removing `kms_key_id` afterwards changes nothing: the namespace keeps the key it has.

### Settings that replace the namespace

AWS cannot rename a namespace or a workgroup, or change the name of the first database. Changing `name` or `db_name` replaces the namespace, and its data is deleted. AWS refuses to delete a namespace that still has a workgroup, so the module replaces the workgroup with it.

With a managed admin password, AWS deletes the old namespace's secret a little after the namespace. When the new namespace has the same name, as after a `db_name` change, its creation can fail with `a secret with a matching name exists`; run `terraform apply` again a few minutes later. Seen in AWS.

Everything else changes in place, including `kms_key_id`, the capacity, `port`, `config_parameters`, `enhanced_vpc_routing`, the IAM roles and the security group's rules. After a change of `port`, the provider returns before AWS has finished: a plan in the next minute or two shows the old port again, and after that only `metadata` changing, which `terraform apply` saves.

### Deleting a namespace

Destroying the module, or any change that replaces the namespace, deletes the namespace with all its databases and data. The AWS provider takes no final snapshot, and the recovery points Amazon Redshift Serverless takes on its own are deleted with the namespace (seen in AWS). To keep the data, take a snapshot first, and see [Snapshots and recovery points](https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-snapshots-recovery-points.html) in the AWS documentation for how long AWS keeps it:

```shell
aws redshift-serverless create-snapshot --namespace-name <name> --snapshot-name <name>-final
```

Amazon Redshift deletes the admin password's secret a few minutes after the namespace. The module's log groups are deleted with their events.

### Audit logs

For each log type in `cloudwatch_logs.exports`, the module creates the log group `/aws/redshift/<name>/<log type>` with the retention you choose, before the namespace starts writing to it. Without them, Amazon Redshift creates the groups itself on the first event, outside Terraform, and keeps the events forever. Destroying the module deletes its log groups and their events.

If a log group with that name already exists, for example one Amazon Redshift created before you set `cloudwatch_logs`, the apply fails with `ResourceAlreadyExistsException`. Delete the group, or import it with an `import` block, then apply again.

### Capacity and cost

Amazon Redshift Serverless bills compute in RPU-hours while the workgroup runs queries, and storage separately; see [Amazon Redshift pricing](https://aws.amazon.com/redshift/pricing/). `base_capacity` sets the RPUs a query starts with; `max_capacity` caps how far the workgroup scales, and so the compute bill. A workgroup that runs no queries is not billed for compute.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_name"></a> [name](#input_name)

Description: The name of the namespace and the workgroup, such as `analytics-production`: 3 to 64 lowercase letters, digits and hyphens. It must be unique among the account's namespaces, and workgroups, in the Region. Changing it later replaces the namespace and the workgroup, and deletes the data.

Type: `string`

#### <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)

Description: The subnets of `vpc_id` the workgroup's endpoint is placed in, such as `["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]`. AWS needs at least two, in different Availability Zones, each with at least 3 free IP addresses. Use private subnets.

Type: `list(string)`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: The ID of the VPC the workgroup is in, such as `vpc-0123456789abcdef0`: the VPC of `subnet_ids`. The module creates the workgroup's security group in it.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_additional_iam_role_arns"></a> [additional_iam_role_arns](#input_additional_iam_role_arns)

Description: More IAM roles to associate with the namespace, beside the one the module creates, given by ARN, such as `arn:aws:iam::123456789012:role/redshift-spectrum`. SQL commands such as `COPY` name the role to use with `IAM_ROLE '<arn>'`. Each role's trust policy must let the Amazon Redshift service principal, `redshift.amazonaws.com`, assume it.

Type: `list(string)`

Default: `[]`

#### <a name="input_additional_security_group_ids"></a> [additional_security_group_ids](#input_additional_security_group_ids)

Description: More security groups to attach to the workgroup, beside the one the module creates, such as `["sg-0123456789abcdef0"]`.

Type: `list(string)`

Default: `[]`

#### <a name="input_admin_password"></a> [admin_password](#input_admin_password)

Description: The admin user's password, if you want to set it yourself. Without it (the default), Amazon Redshift creates the password and keeps it in AWS Secrets Manager, where it rotates it; the module never sees it, so it is not in the Terraform state. The secret's ARN is in the `metadata` output, at `redshiftserverless_namespace.admin_password_secret_arn`.

With a password, Secrets Manager is not used, and the password is stored in the Terraform state, so protect the state. Removing it later needs a step with the AWS CLI; see the README. It must have 8 to 64 printable ASCII characters, with at least one uppercase letter, one lowercase letter and one digit, and none of `/`, `@`, `"`, `'`, `\` or a space.

Type: `string`

Default: `null`

#### <a name="input_admin_user"></a> [admin_user](#input_admin_user)

Description: The namespace's admin user, the database superuser that Amazon Redshift creates with the namespace.

- `username` - (Optional) The admin user's name. Defaults to `admin`. It must start with a letter and have up to 127 letters, digits and the characters `_`, `+`, `.`, `@` and `-`; `public` and `rdsdb` are refused. Without `admin_password`, change it later with the AWS CLI, not Terraform; see the README.
- `secret_kms_key_id` - (Optional) The AWS Key Management Service (KMS) key that encrypts the Secrets Manager secret holding the password: a key ID, key ARN, alias name or alias ARN. Without it, Secrets Manager uses the AWS managed key `aws/secretsmanager`. Not used with `admin_password`. Change it later with the AWS CLI, not Terraform; see the README.

Type:

```hcl
object({
    username          = optional(string, "admin")
    secret_kms_key_id = optional(string)
  })
```

Default: `{}`

#### <a name="input_base_capacity"></a> [base_capacity](#input_base_capacity)

Description: The workgroup's base capacity, in Redshift Processing Units (RPUs): the compute that serves queries. Defaults to `8`. Either `4`, or a multiple of `8` from `8` to `1024`. Amazon Redshift Serverless bills RPU-hours only while queries run, so a higher value costs more per query, not while idle.

Type: `number`

Default: `8`

#### <a name="input_cloudwatch_logs"></a> [cloudwatch_logs](#input_cloudwatch_logs)

Description: Audit logs to send to Amazon CloudWatch Logs. The module creates one log group per log type, `/aws/redshift/<name>/<log type>`, before the namespace starts writing to it, so the retention below applies. With the default, `{}`, no logs are sent.

- `exports` - (Optional) The log types to send: `connectionlog` (connection attempts and disconnections), `userlog` (changes to database users) and `useractivitylog` (every query, which needs `config_parameters.enable_user_activity_logging`, on by default).
- `retention_in_days` - (Optional) Days to keep log events. Defaults to `7`. One of `1`, `3`, `5`, `7`, `14`, `30`, `60`, `90`, `120`, `150`, `180`, `365`, `400`, `545`, `731`, `1096`, `1827`, `2192`, `2557`, `2922`, `3288` or `3653`, or `0` to keep them forever.
- `kms_key_id` - (Optional) ARN of a KMS key to encrypt the log groups with. Its key policy must let the CloudWatch Logs service principal for the Region use it. Without it, CloudWatch Logs encrypts them with its own key.

Type:

```hcl
object({
    exports           = optional(list(string), [])
    retention_in_days = optional(number, 7)
    kms_key_id        = optional(string)
  })
```

Default: `{}`

#### <a name="input_config_parameters"></a> [config_parameters](#input_config_parameters)

Description: Database settings for the workgroup, as a map of parameter name to value, such as `{ max_query_execution_time = "3600" }`. Values are strings. See [the AWS documentation](https://docs.aws.amazon.com/redshift/latest/APIReference/API_ConfigParameter.html) for their meanings. The module sets every parameter, to the value given here or else to the value AWS gives a new workgroup:

- `auto_mv` - Defaults to `"true"`.
- `datestyle` - Defaults to `"ISO, MDY"`.
- `enable_case_sensitive_identifier` - Defaults to `"false"`.
- `enable_user_activity_logging` - Defaults to `"true"`. Needed for the `useractivitylog` in `cloudwatch_logs`.
- `max_query_execution_time` - Seconds a query may run before it is canceled. Defaults to `"14400"`.
- `query_group` - Defaults to `"default"`.
- `require_ssl` - Clients must connect with TLS. Defaults to `"true"`.
- `search_path` - Defaults to `"$user, public"`.
- `use_fips_ssl` - Use FIPS-validated TLS. Defaults to `"false"`.

Type: `map(string)`

Default: `{}`

#### <a name="input_db_name"></a> [db_name](#input_db_name)

Description: The name of the first database in the namespace, such as `analytics`. Defaults to `dev`, the AWS default. Changing it later replaces the namespace and the workgroup, and deletes the data.

Type: `string`

Default: `null`

#### <a name="input_enhanced_vpc_routing"></a> [enhanced_vpc_routing](#input_enhanced_vpc_routing)

Description: Send the workgroup's traffic to Amazon S3 and other AWS services, such as `COPY` and `UNLOAD`, through your VPC, where your security group rules, route tables and VPC endpoints apply. Defaults to `true`. The workgroup then needs a route to the service and a `security_group_egress` rule that allows it; see the README.

Type: `bool`

Default: `true`

#### <a name="input_iam_role"></a> [iam_role](#input_iam_role)

Description: Permissions for the IAM role the module creates and makes the namespace's default role. SQL commands such as `COPY`, `UNLOAD` and `CREATE EXTERNAL SCHEMA` use it with `IAM_ROLE default`. With the default, `{}`, the role has no permissions, so those commands fail until you grant what they need.

- `policy_arns` - (Optional) Managed policies to attach, as a map of a name you choose to the policy ARN, such as `{ spectrum = aws_iam_policy.spectrum.arn }`. The names only identify each attachment, so a policy created in the same configuration can be used.
- `source_policy_documents` - (Optional) IAM policy documents, as JSON, merged into the role's inline policy, such as `[data.aws_iam_policy_document.s3_read.json]`. Keep each grant to the buckets, keys and actions the commands need.

Type:

```hcl
object({
    policy_arns             = optional(map(string), {})
    source_policy_documents = optional(list(string), [])
  })
```

Default: `{}`

#### <a name="input_kms_key_id"></a> [kms_key_id](#input_kms_key_id)

Description: ARN of the AWS Key Management Service (KMS) key that encrypts the namespace's data and snapshots. The data is always encrypted; without a key, Amazon Redshift uses a key that AWS owns and manages, which you cannot see or audit. Use a customer managed key to control and log its use.

Type: `string`

Default: `null`

#### <a name="input_max_capacity"></a> [max_capacity](#input_max_capacity)

Description: The most RPUs the workgroup may scale to, to cap its cost. Without it, AWS sets no limit. At least `base_capacity`; `4` when `base_capacity` is `4`, otherwise a multiple of `8`, up to `5632`.

Type: `number`

Default: `null`

#### <a name="input_port"></a> [port](#input_port)

Description: The port the workgroup listens on: `5431` to `5455`, or `8191` to `8215`. Defaults to `5439`. The security group allows this port.

Type: `number`

Default: `5439`

#### <a name="input_publicly_accessible"></a> [publicly_accessible](#input_publicly_accessible)

Description: Make the workgroup's endpoint reachable from outside the VPC. Defaults to `false`. It also needs subnets with a route to an internet gateway and a `security_group_ingress` source outside the VPC. Keep workgroups private; reach them through the VPC instead.

Type: `bool`

Default: `false`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the workgroup and everything else in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.

Type: `string`

Default: `null`

#### <a name="input_security_group_egress"></a> [security_group_egress](#input_security_group_egress)

Description: Where the workgroup may connect to. The workgroup needs no outbound rules to answer clients, so with the default, `{}`, it can open no connections. With `enhanced_vpc_routing`, `COPY` and `UNLOAD` reach Amazon S3 through the VPC, and need an entry such as HTTPS, port `443`, to the S3 prefix list. The keys are names you choose; they only identify each rule.

Each entry takes:

- `port` - (Required) The TCP port to allow.

and exactly one of:

- `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
- `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
- `security_group_id` - A security group whose members the workgroup may connect to.
- `prefix_list_id` - A managed prefix list, such as the one for S3 in the Region (`data.aws_ec2_managed_prefix_list` with name `com.amazonaws.<region>.s3`).

and optionally:

- `description` - (Optional) What the destination is. Defaults to the key.

Type:

```hcl
map(object({
    port              = number
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
```

Default: `{}`

#### <a name="input_security_group_ingress"></a> [security_group_ingress](#input_security_group_ingress)

Description: Who can reach the workgroup over the network. The module creates a security group for the workgroup that allows `port` (TCP) from each source listed here, and from nothing else. With the default, `{}`, no client can connect over the network; the Amazon Redshift Data API still works, because it does not connect through the VPC. The keys are names you choose; they only identify each rule, so a security group created in the same configuration can be used.

Each source takes exactly one of:

- `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
- `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
- `security_group_id` - A security group whose members may connect, such as the group of your application servers.
- `prefix_list_id` - A managed prefix list of ranges.

and optionally:

- `description` - (Optional) What the source is. Defaults to the key.

Type:

```hcl
map(object({
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
```

Default: `{}`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

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
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
