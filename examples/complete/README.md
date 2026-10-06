# Complete

A workgroup that loads data from one Amazon S3 bucket with `COPY`:

- A customer managed KMS key, which encrypts the namespace and the admin password's secret.
- An admin user named `dwadmin`, and a first database named `analytics`.
- An IAM role, the namespace's default, that can list and read only the data bucket.
- An outbound rule for HTTPS to Amazon S3, which `COPY` needs with enhanced VPC routing.
- Connection and user audit logs in CloudWatch Logs, kept 90 days.
- 8 RPUs of base capacity, and at most 32, to cap the compute bill.
- Queries canceled after an hour.
- Access only from a security group for the application servers, which the example creates.

## Run it

The VPC needs a route to Amazon S3 from the subnets, such as a gateway endpoint for S3 on their route tables, or a NAT gateway. Choose private subnets in at least two Availability Zones, and a bucket in the same Region:

```shell
terraform init
terraform apply \
  -var 'vpc_id=vpc-0123456789abcdef0' \
  -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210","subnet-0123456789abcdef1"]' \
  -var 'data_bucket_name=example-data-bucket'
```

Then load a CSV file from the bucket, for example through the Amazon Redshift Data API:

```shell
aws redshift-data execute-statement --workgroup-name example-complete --database analytics \
  --sql "create table people (id int, name varchar(20))"
aws redshift-data execute-statement --workgroup-name example-complete --database analytics \
  --sql "copy people from 's3://example-data-bucket/people.csv' iam_role default format as csv"
```

To remove it, run `terraform destroy` with the same `-var` options. That deletes the namespace and all its data, with no final snapshot, and the log groups with their events. The KMS key is deleted after 7 days.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_data_bucket_name"></a> [data_bucket_name](#input_data_bucket_name)

Description: Name of the S3 bucket the workgroup loads data from with COPY

Type: `string`

#### <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)

Description: IDs of private subnets for the workgroup, in at least two Availability Zones

Type: `list(string)`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the workgroup in. It needs a gateway endpoint for Amazon S3, or a NAT gateway, on the subnets' route tables.

Type: `string`

### Outputs

The following outputs are exported:

#### <a name="output_workgroup"></a> [workgroup](#output_workgroup)

Description: Where to connect, the ARN of the Secrets Manager secret that holds the admin password, and the security group to add application servers to
<!-- END_TF_DOCS -->
