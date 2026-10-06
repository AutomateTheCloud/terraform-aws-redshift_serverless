# Security

## Reporting a vulnerability

Report security problems privately, not in a public issue. On GitHub, open the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainers can see the report.

Include what you found, how to reproduce it, and what an attacker could do with it.

## What counts

A security problem in this module is anything that makes a workgroup or its data more exposed than its inputs say it should be: for example, a default that allows network access or makes the endpoint public, a security group rule or IAM permission broader than documented, a password written to the Terraform state without `admin_password`, or a validation that lets an insecure value through.

## Supported versions

Fixes are made to the latest release.
