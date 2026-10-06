# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An Amazon Redshift Serverless namespace and workgroup, with secure defaults: always encrypted, private, TLS required, enhanced VPC routing on, and no network access until you allow a source.
- The admin password created by Amazon Redshift and kept, and rotated, in AWS Secrets Manager, so it does not appear in the Terraform state; or a password you give.
- The namespace's default IAM role, with no permissions until you grant them, through managed policies or policy documents. More IAM roles can be associated.
- A security group that allows the workgroup's port from IPv4 and IPv6 ranges, security groups and prefix lists, and outbound connections only to the destinations you list, such as Amazon S3 for `COPY` and `UNLOAD`.
- Base and maximum capacity, the port, every workgroup configuration parameter, and a customer managed KMS key.
- Audit logs sent to CloudWatch Logs, in log groups the module creates with your retention.
- `region`, to create the workgroup in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for a basic workgroup and one that loads data from Amazon S3.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-redshift_serverless/releases/tag/v1.0.0
