# Basic workgroup

A private, encrypted Amazon Redshift Serverless workgroup in the subnets you give. Anything in the VPC can reach it on port `5439`. Amazon Redshift creates the admin user, `admin`, and keeps its password in AWS Secrets Manager.

Everything else uses the module's defaults: a key AWS owns for encryption, TLS required, 8 RPUs of base capacity, enhanced VPC routing, no outbound traffic, and an IAM role with no permissions.

## Run it

Choose a VPC and private subnets in at least two Availability Zones:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210","subnet-0123456789abcdef1"]'
```

Creating the workgroup takes about a minute. The `workgroup` output gives its address and port, and the ARN of the secret that holds the admin password. From an instance in the VPC:

```shell
PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id '<secret ARN>' --query SecretString --output text | jq -r .password) \
  psql "host=<address> port=5439 user=admin dbname=dev sslmode=require"
```

Or, with no network access at all, through the Amazon Redshift Data API:

```shell
aws redshift-data execute-statement --workgroup-name example-basic --database dev --sql 'select current_user'
```

To remove it, run `terraform destroy` with the same `-var` options. That deletes the namespace and all its data, with no final snapshot.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)

Description: IDs of private subnets for the workgroup, in at least two Availability Zones

Type: `list(string)`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the workgroup in

Type: `string`

### Outputs

The following outputs are exported:

#### <a name="output_workgroup"></a> [workgroup](#output_workgroup)

Description: Where to connect, and the ARN of the Secrets Manager secret that holds the admin password
<!-- END_TF_DOCS -->
