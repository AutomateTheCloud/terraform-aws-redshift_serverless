# Automate the Cloud Terraform modules: working rules

This file is the same in every Automate the Cloud Terraform module repository.
Change it in one place and copy it to the others; do not let copies drift. The
reference implementation of everything below is
[terraform-aws-s3_bucket](https://github.com/AutomateTheCloud/terraform-aws-s3_bucket).

These modules are published on the Terraform Registry under `AutomateTheCloud`.
Automate the Cloud Inc. is a Kentucky 501(c)(3) that teaches cloud
infrastructure, and the modules are teaching material as well as tools: people
read them to learn, copy examples out of them, and build real infrastructure on
them. Correctness, secure defaults, and clear documentation matter more than
features.

## Ground rules

- Do not commit, push, tag, or change repository settings unless asked.
- Commit messages and pull requests describe the change only. Never mention an
  AI tool or add attribution trailers for one.
- Sign off every commit with `git commit -s` (Developer Certificate of Origin).
- Say what you verified and how. "Tests pass" means you ran them; otherwise say
  it is untested.

## Versions

- Each module has its own semantic version, from git tags (`v1.0.0`),
  independent of the Terraform version and of other modules.
- `versions.tf` sets minimums only, never an upper bound: `required_version =
  ">= 1.9"`, and each provider at the oldest version the code actually needs
  (`hashicorp/aws >= 6.0`). Examples are root modules and pin with `~>`.
- Test on the oldest supported versions and the newest. Use tfswitch to install
  Terraform versions.

## Module design

- **Provider:** use the default `aws` provider, and pass `region = var.region`
  to every resource and data source that accepts it (`region` defaults to
  `null`, meaning the provider's Region). Use `configuration_aliases` only for a
  module that truly works across two accounts or Regions at once.
- **`details`:** every module takes the same required `details` input (`scope`,
  `purpose`, `environment`, optional `*_abbr` and `additional_tags`). It tags
  every resource and produces the `abbr` and `machine` name forms. Copy its
  type, validation and locals from the reference module unchanged.
- **One output, `metadata`:** `details`, `aws` (account, Region name, `abbr`,
  description), and one entry per resource, `null` when not created.
- **Typed inputs:** `object({...})` with `optional()` defaults, never `any`.
  `nullable = false` where there is a default. Add a `validation` block for any
  value AWS would reject, so mistakes fail at plan time with a clear message.
- **Secure defaults:** a resource created with only the required inputs is
  private, encrypted, and least-privilege. Anything public or broader is an
  explicit opt-in.
- **No broad presets:** do not add switches that grant many services or
  accounts access at once. Give a general escape hatch (such as
  `source_policy_documents`) and an example that shows a narrowly scoped grant.
- **`count` and `for_each` depend on inputs only**, never on values known only
  after apply, so a dependency created in the same run still plans.
- **No hard-coded per-Region tables.** Use service principals, provider data
  sources, or a computed value with a small override map. Build ARNs from
  resource attributes, never `arn:aws:` strings, so GovCloud and China work.
- **Never set a ForceNew attribute that a user might toggle later** on a
  stateful resource; find the separate resource that does it in place.
- **No `null_resource` for input checks**; use `validation` blocks.

## Outputs must not warn

List output attributes one by one. Referencing a whole resource, or iterating
over one with `for`, also references its deprecated and sensitive attributes,
and every caller's plan then prints deprecation warnings or the output becomes
sensitive. Generate the attribute list from `terraform providers schema -json`:
keep an attribute only if it exists at the provider floor and is not deprecated
in the latest release. CI fails on any `terraform validate` warning.

## Files and layout

`versions.tf`, `main.tf` (data sources, locals), `variables.tf` (every
variable, alphabetical), `outputs.tf`, `locals.tf`, one file per resource type,
`tests/`, `examples/<name>/` each with a README. Also, copied from the
reference module and adapted: `.terraform-docs.yml`, `.tflint.hcl`,
`.trivyignore.yaml`, `.github/` (CI workflow, CODEOWNERS, pull request
template, Dependabot), `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`,
`AUTHORS.md`, `LICENSE`, `NOTICE`.

## Documentation

- Variable and output descriptions are the reference documentation:
  terraform-docs generates the README's Reference section from them. Describe
  every attribute and its default, with a blank line before each list. Run
  `terraform-docs .` after changing any variable or output; CI checks it.
- The README's hand-written part: what the module creates, a table of
  defaults, usage with the registry source and `version = "~> 1.0"`, the
  `details` section, examples, "Things to know", contributing, testing,
  license.
- Links in anything the registry shows (README, CHANGELOG, example READMEs,
  descriptions) are full GitHub URLs to `main`; the registry does not resolve
  relative links.
- Examples must make sense on their own and be safe to apply. One purpose per
  example.
- Voice: plain and specific. Say what a thing does before why. Short sentences,
  no marketing words, expand an acronym the first time it appears, link text
  that makes sense out of context. "Automate the Cloud" in prose, "Automate the
  Cloud Inc." in legal text. American English everywhere.
- A refreshed module is published as new: `CHANGELOG.md` starts with a 1.0.0
  initial-release entry and does not mention earlier versions.

## Licensing

Terraform modules are code only, under the Apache License 2.0:

- `LICENSE`: the official Apache 2.0 text, byte for byte. Download it; never
  retype it.
- `NOTICE`: `Automate the Cloud Inc.` and `Copyright <YEAR> Automate the Cloud Inc.`
- Every source file (`.tf`, `.tftest.hcl`, `.hcl`, workflow YAML) starts with:

  ```hcl
  # Copyright <YEAR> Automate the Cloud Inc.
  # SPDX-License-Identifier: Apache-2.0
  ```

- `<YEAR>` is the year the repository was first published.
- The README's license section says the code is Apache 2.0 and that the name
  and logo are not licensed.

The full policy is the organization's licensing playbook. Read it before any
licensing change, and report rather than decide: an earlier license, unclear
ownership, third-party material, or personal information in files or history.

## Testing

- `tests/` holds offline `terraform test` files with mocked providers. Every
  bug fix and every feature gets a test. Assert on configured values in `plan`
  runs; mocks leave computed values unknown at plan, so use `apply` (still
  mocked) for those, and `plan` for `expect_failures`.
- CI runs fmt, terraform-docs, TFLint, Trivy, and the tests on the oldest and
  newest Terraform and provider versions, plus a DCO sign-off check.
- Before a release, verify in a real AWS account: fresh apply, a re-plan with
  no changes, the configuration checked with the AWS CLI, then destroy and
  confirm nothing is left. Never make anything public in a shared account.

## Terraform traps that have already bitten

- `cond ? [ {...} ] : []` fails when the objects differ in shape; use
  `[for s in [ {...} ] : s if cond]`.
- `tolist()` fails on a JSON array of differently shaped objects; test with
  `can(x[0])`.
- `coalesce()` errors when every argument is null or empty.
- Typed objects reject a missing required attribute but silently drop a
  misspelled optional one, so document attribute names exactly.
- A `for` expression carries the deprecated and sensitive marks of everything
  it iterates over.
- New deprecations appear first on the newest Terraform and provider. Run
  `terraform validate` there before every release.
- `x != null` on a value from a resource created in the same run is unknown
  at plan, so it cannot decide `count` or `for_each`. Take such a value inside
  an object input (`{ zone_id = ... }`): whether the object is `null` is known.
- When a resource is replaced, its computed attributes are unknown at plan.
  Resources built from them are replaced too, if those arguments force
  replacement, and are destroyed before the new resource exists, even with
  `create_before_destroy`. If the values cannot change, use `ignore_changes`.
- `terraform validate` fails on a module that declares
  `configuration_aliases`. CI writes a non-empty provider block for each alias
  (an empty one is a deprecated proxy block) and runs `validate -no-tests`,
  because test fixtures that pass the alias in clash with that block.
