---
date: 2026-08-06
spec: 0001
feature: infra-curriculum
status: planned
---

# Infrastructure Curriculum Plan

> **This plan is not for agentic workers, and must not be dispatched to
> subagents.** Spec 0001's "Implementation split" section makes the
> infrastructure author-built in full teaching mode. The assistant's role is
> coach: present the trade-off space, review what gets written, run the
> checkpoints, ask the quiz questions. If a subagent writes the HCL, the plan
> has failed regardless of whether the site comes up.

**Goal:** Stand up the AWS infrastructure in spec 0001 — state, platform, a
reusable `static-site` module, the portfolio stack, and the OIDC deploy path —
built by the author, closing success criteria 1, 2, 3, and 8.

**Architecture:** Four Terraform root-or-child modules per
[[0003-terraform-topology]]. `bootstrap/` has local state and creates the state
bucket. `platform/` holds the account-wide singletons: hosted zone lookup, one
certificate, the GitHub OIDC provider, a budget alarm. `modules/static-site/`
is the reusable unit: bucket, OAC, distribution, DNS, deploy role.
`stacks/portfolio/` is a thin root module that reads platform outputs and calls
it once. Deploys run from GitHub Actions against a role assumed through OIDC;
Terraform never runs in CI.

**Tech Stack:** Terraform 1.10+, AWS provider, `tls` provider (OIDC thumbprint),
GitHub Actions, AWS CLI v2, PowerShell for the local deploy script.

---

## How a session runs

Every build unit follows the same five beats. The order is the teaching
mechanism; skipping to the reference implementation wastes the session.

1. **Trade-off brief.** The fork, the options, what each one costs. Read it
   before writing anything.
2. **Decide.** Pick one, say why out loud, and record it in the decision log at
   the bottom of this plan. If the reason doesn't survive being said out loud,
   that's the signal to go back to the brief.
3. **Build.** The requirements: exact resource types, attribute names, and
   values that must appear. Written as requirements, not as code to copy.
4. **Compare.** A reference implementation to diff your version against. Read
   it *after* you've written yours. Differences are worth a conversation, not
   an automatic rewrite — yours may be better.
5. **Verify.** A command that emits a status code, a number, or an exact
   string. Never "look at it and see if it seems right."

That last point is a direct carry-forward from the site build. Six defects
there came from the plan rather than the implementation, and every one surfaced
when something concrete got built and checked against a requirement. Review by
reading missed all six. So every checkpoint here compares against a value.

**Quiz checkpoints** close each session. Answer keys are at the end of each
session's quiz — the questions are worth attempting cold first.

**Estimated timing** (estimates, not commitments): Session 1 around 90 minutes,
Session 2 around 2.5 hours, Session 3 around 90 minutes.

---

## Global constraints

Every unit's requirements implicitly include these.

- Region is `us-east-1`, single provider, **no alias**. ACM for CloudFront must
  live there and nothing else here is region-sensitive.
- Terraform **1.10 or newer**. `use_lockfile` does not exist before it.
- Every stack except `bootstrap` uses the S3 backend with `use_lockfile = true`.
  No DynamoDB table.
- The hosted zone is **read with a data source, never created**. No plan may
  touch the NS records.
- The OIDC trust subject is fixed by the repository name:
  `repo:philliam-nguyen/dev_site:ref:refs/heads/main`. Renaming the repository
  breaks deploys until Terraform is re-applied.
- No AWS credential is stored anywhere. Not in the repo, not in GitHub secrets.
- The deploy role ARN lives in a **repository variable**, not a secret and not
  hardcoded.
- `terraform fmt` clean before every commit.
- Provider versions are **pinned to a major, with the lock file committed**.
- No emoji in code, HCL, commit messages, or output.
- The git remote uses an SSH host alias: `git@github-personal:...`. A pasted
  `https://github.com/...` URL fails with `Permission denied`.
- Verification commands in this plan are written for **PowerShell on Windows**.
  `curl` there is an alias for `Invoke-WebRequest`, so every HTTP check calls
  `curl.exe` explicitly. `dig` is not present; `Resolve-DnsName` replaces it.

---

## Blocking prerequisites

Session 1 cannot start until both exist. Sessions 2 and 3 inherit the block.

1. **A registered domain**, with a Route 53 hosted zone. Registering through
   Route 53 creates the zone automatically. Another registrar means creating
   the zone by hand and repointing nameservers there, then waiting for
   propagation before ACM validation can succeed.
2. **An AWS account with a local admin-capable named profile.** Every `apply`
   in this plan runs against it. Confirm with:

```powershell
aws sts get-caller-identity --profile <profile>
```

Expected: JSON with an `Account` and an `Arn`. Anything else, including an
expired SSO session, stops the session here.

Set the profile once per shell rather than passing `--profile` to every
command:

```powershell
$env:AWS_PROFILE = "<profile>"
$env:AWS_REGION  = "us-east-1"
```

Also confirm the toolchain:

```powershell
terraform version    # 1.10.0 or newer
aws --version        # aws-cli/2.x
gh auth status       # authenticated, for the repository variable in Session 3
```

**The domain name is the one open question in progress.md.** It threads through
the platform stack as `var.domain_name`, and reaches every app stack through
the platform outputs. Nothing below can be applied without it, and
everything below can be *written* without it.

---

# Session 1: State and the platform layer

**Deliverable:** a state bucket, a validated certificate, an OIDC provider, and
a budget alarm. Nothing is serving traffic yet.

**Session-end checkpoint:** `terraform plan -detailed-exitcode` returns 0 in
both `bootstrap/` and `platform/`, and the certificate reports `ISSUED`.

---

## Unit 1.1: The lock file, before anything else

**Trade-off brief.**

`.gitignore` currently contains `.terraform.lock.hcl`. That line is wrong and
it should come out before the first `terraform init` runs.

The dependency lock file records the exact provider versions and their
checksums. Committing it is what makes `terraform init` resolve the same
provider build on your machine, on a fresh clone, and in the CI static-analysis
job. Ignoring it means each `init` re-resolves against whatever the registry
offers that day, so a provider minor release can change a plan's output between
two people running the same commit.

The counter-argument for ignoring it is that a stale lock blocks provider
upgrades until someone runs `terraform init -upgrade`. That is the intended
behavior, not a cost — upgrades become an explicit commit with a diff.

This matters more here than in a generic project. Progress.md records that
stale version pins were one of six plan-originated defects in the site build.
The lock file is the mechanism that turns a version pin into something the tool
enforces rather than something a document asserts.

**Decide.** Commit lock files, or keep ignoring them. Recommended: commit.

**Build.**

- Remove the `.terraform.lock.hcl` line from `.gitignore`.
- Leave `.terraform/`, `*.tfstate`, `*.tfstate.*`, and `*.tfvars` ignored.
- Confirm the bootstrap state file will be ignored before it exists.

**Verify.**

```powershell
git check-ignore -v infra/bootstrap/terraform.tfstate
```

Expected: a line naming `.gitignore` and the `*.tfstate` rule. No output means
the state file would be committed — stop and fix `.gitignore`.

```powershell
git check-ignore -v infra/bootstrap/.terraform.lock.hcl
```

Expected: **no output**, and exit code 1. That confirms the lock file is now
committable.

**Commit.**

```bash
git add .gitignore
git commit -m "Stop ignoring .terraform.lock.hcl

The lock file is what makes a provider pin reproducible across the laptop
and the CI static-analysis job. Ignoring it means each init re-resolves
against the registry, which is the same failure class as the stale version
pins found during the site build."
```

---

## Unit 1.2: Provider pinning

**Trade-off brief.**

Four constraint styles, loosest to tightest:

| Style | Behavior | Cost |
|---|---|---|
| No constraint | Latest on every fresh init | A major release breaks the plan silently |
| `>= 6.0` | Any newer version | Same problem, later |
| `~> 6.0` | Any 6.x, no 7.x | Minor changes arrive without a commit — but the lock file pins the exact build |
| `= 6.4.2` | Exactly one | Every patch is a manual edit in every module |

`~> <major>.0` plus a committed lock file is the pairing that works: the
constraint blocks the breaking upgrade, the lock file makes the exact build
reproducible, and `terraform init -upgrade` is the deliberate act that moves it.

**Do not take a version number from this plan.** It was written 2026-08-06 and
provider majors move. Check the registry and pin what is current.

**Build.**

Check the current major for both providers:

```powershell
curl.exe -s "https://registry.terraform.io/v1/providers/hashicorp/aws" | ConvertFrom-Json | Select-Object -ExpandProperty version
curl.exe -s "https://registry.terraform.io/v1/providers/hashicorp/tls" | ConvertFrom-Json | Select-Object -ExpandProperty version
```

Write `infra/bootstrap/versions.tf` with `required_version >= 1.10.0`, a
`required_providers` block pinning `hashicorp/aws` to `~> <major>.0`, and a
`provider "aws"` block with `region = "us-east-1"`.

**Compare.** Substitute the majors you just looked up.

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # verify against the registry before committing
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

`platform/`, `modules/static-site/`, and `stacks/portfolio/` each get the same
`required_providers` block. A child module declares its provider requirements
but **does not declare a `provider` block** — it inherits the configured
provider from the root that calls it. Putting a `provider` block inside
`modules/static-site/` would make the module impossible to call with an aliased
provider later, and Terraform warns about it.

---

## Unit 1.3: The bootstrap paradox

**Trade-off brief.**

Remote state needs a bucket. Creating the bucket with Terraform needs state.
The circularity has to break somewhere. Four ways:

1. **Create the bucket by hand in the console.** No state at all. Fastest, and
   the bucket's configuration exists nowhere in the repo — versioning,
   encryption, and public-access-block are invisible facts someone has to
   remember to re-create.
2. **A `bootstrap/` root module with local state**, applied once, its state
   file living on disk and gitignored. The configuration is code and reviewable.
   The state is one laptop's file.
3. **Bootstrap with local state, then migrate that state into the bucket it
   just made.** Elegant, and it makes the state bucket depend on itself for
   locking, so a mistake in the bucket resources can lock you out of fixing
   them.
4. **A separate tool** (CloudFormation, CDK, a shell script). Second toolchain
   for one bucket.

Option 2 is what [[0003-terraform-topology]] chose. The consequence to
understand and accept: **if the laptop dies, `bootstrap/terraform.tfstate` is
gone.** The bucket survives — it has `prevent_destroy` and nothing else manages
it — and recovery is `terraform import` on a fresh clone, not a rebuild. That
is a real but bounded cost for one resource group applied once.

**Decide.** Confirm option 2, and say out loud what happens when the laptop
dies.

**Build.**

Create `infra/bootstrap/main.tf` with:

- `data "aws_caller_identity" "current"` to get the account ID.
- `aws_s3_bucket` named `tf-state-<account-id>-us-east-1`, built from the data
  source so the name is derived rather than typed. Bucket names are globally
  unique across all AWS accounts; the account ID is the cheapest guaranteed
  uniqueness.
- `lifecycle { prevent_destroy = true }` on the bucket.
- `aws_s3_bucket_versioning` set to `Enabled`. Versioning is the state-recovery
  mechanism: a corrupt or truncated state file is a rollback to the previous
  object version.
- `aws_s3_bucket_server_side_encryption_configuration` with `AES256`.
- `aws_s3_bucket_public_access_block` with all four flags true.
- An output for the bucket name — the backend blocks in the other stacks need
  it, and the backend cannot read it programmatically.

**Compare.**

```hcl
data "aws_caller_identity" "current" {}

locals {
  state_bucket = "tf-state-${data.aws_caller_identity.current.account_id}-us-east-1"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}
```

The four public-access-block resources are separate from the bucket because
AWS provider v4 split them out. A single `aws_s3_bucket` block with inline
`versioning` and `acl` arguments is the pre-v4 shape and will not work — most
tutorials still show it.

**Verify.**

```powershell
cd infra/bootstrap
terraform init
terraform apply
```

Then, against the bucket name the output printed:

```powershell
$b = terraform output -raw state_bucket
aws s3api get-bucket-versioning --bucket $b --query "Status" --output text
```
Expected: `Enabled`

```powershell
aws s3api get-public-access-block --bucket $b --query "PublicAccessBlockConfiguration" --output json
```
Expected: four `true` values, no `false`.

```powershell
aws s3api get-bucket-encryption --bucket $b --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" --output text
```
Expected: `AES256`

```powershell
terraform plan -detailed-exitcode; $LASTEXITCODE
```
Expected: `0`. Exit 2 means the apply did not converge — something in the
config drifts on every plan, and that is a defect to find now rather than in
Session 3 when it will look like a deploy problem.

```powershell
git status --short infra/bootstrap
```
Expected: `.tf` files and `.terraform.lock.hcl` listed, **no `terraform.tfstate`**.

**Commit.**

```bash
git add infra/bootstrap/
git commit -m "Bootstrap: Terraform state bucket with versioning and encryption

Local state, applied once by hand, per ADR-0003. Versioning is the
recovery path for a corrupt state object; prevent_destroy is the guard
against a stray destroy taking every other stack's state with it."
```

---

## Unit 1.4: The zone, the certificate, and the validation loop

**Trade-off brief, part one: data source or resource for the zone.**

`aws_route53_zone` as a *resource* means Terraform owns the zone and its NS
records. Destroying the stack destroys the zone; recreating it issues **new
nameservers**, which then have to be updated at the registrar, and the domain
is dark until DNS propagates. `data "aws_route53_zone"` reads the existing zone
and can never modify it. [[0003-terraform-topology]] chose the data source, and
the reason is blast radius, not convenience.

**Trade-off brief, part two: certificate coverage.**

A wildcard `*.example.com` **does not match the apex** `example.com`. It also
does not match a second label — `*.example.com` covers `app.example.com` but
not `a.b.example.com`. Three options:

1. One certificate, apex as `domain_name`, `*.example.com` as a SAN. One
   validation cycle, one ARN to pass around, and every future app subdomain is
   already covered.
2. One certificate per subdomain. Tighter scoping, and a new validation cycle
   and a new platform output on every new app.
3. Apex only, and add SANs as apps arrive. Every addition re-validates and
   replaces the certificate on the distribution.

Option 1 is the spec's choice. The cost worth naming: the certificate is a
platform-wide shared resource, so a mistake in it takes every app's HTTPS with
it.

**Trade-off brief, part three: the duplicate validation record.**

ACM emits one `domain_validation_options` entry per name on the certificate, so
apex plus wildcard gives two entries. **Both entries carry the same validation
record name and the same value** — ACM deduplicates the underlying challenge.
A naive `for_each` keyed on `domain_name` therefore tries to create the same
Route 53 record twice, and the second one fails with "Tried to create resource
record set but it already exists."

Two fixes. Set `allow_overwrite = true` so the second write is idempotent, or
deduplicate in the `for_each` expression. `allow_overwrite` is the conventional
answer and it also covers a re-apply after a certificate replacement.
Deduplicating is arguably more precise and is harder to read.

**Decide.** Data source for the zone; one certificate with apex plus wildcard;
one of the two duplicate-record fixes.

**Build.**

Create `infra/platform/` with `versions.tf`, `backend.tf`, `variables.tf`,
`main.tf`, `outputs.tf`, and `terraform.tfvars.example`.

- `backend.tf`: S3 backend, `key = "platform/terraform.tfstate"`,
  `region = "us-east-1"`, `encrypt = true`, `use_lockfile = true`, bucket set
  to the bootstrap output. **Backend blocks cannot use variables or
  interpolation** — the bucket name is a literal string. That constraint is why
  bootstrap emits the name as an output for a human to paste.
- `variables.tf`: `domain_name`, `budget_email`, `monthly_budget_usd` with a
  sensible default. No default on `domain_name` — a typo'd default is worse
  than a prompt.
- `main.tf`: the zone data source, the certificate, the validation records, the
  validation resource.
- `outputs.tf`: `zone_id`, `domain_name`, `certificate_arn`. These are the
  platform's public interface, and [[0003-terraform-topology]] records that
  changing them is a breaking change for every app stack. `domain_name` is
  there because of that ADR's 2026-08-06 amendment: platform owns the string
  and app stacks read it, so five stacks cannot hold five copies that drift.

**Compare.**

```hcl
# infra/platform/backend.tf
terraform {
  backend "s3" {
    bucket       = "tf-state-<account-id>-us-east-1"
    key          = "platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

```hcl
# infra/platform/variables.tf
variable "domain_name" {
  description = "Apex domain, no trailing dot. The hosted zone must already exist."
  type        = string
}

variable "budget_email" {
  description = "Address that receives budget threshold alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost threshold in USD."
  type        = string
  default     = "5"
}
```

```hcl
# infra/platform/main.tf
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # The apex and the wildcard resolve to the same challenge record. Without
  # this, the second write collides with the first.
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
```

`create_before_destroy` on the certificate matters because a certificate in use
by a distribution cannot be deleted. Without it, any change forcing replacement
deadlocks: Terraform tries to destroy the old certificate first, AWS refuses
because CloudFront still references it.

`aws_acm_certificate_validation` creates nothing. It is a wait: it blocks until
ACM reports the certificate issued, so downstream resources do not try to
attach a pending certificate. Pass **its** `certificate_arn` to the
distribution, not the certificate resource's, to make the dependency explicit.

```hcl
# infra/platform/outputs.tf
output "zone_id" {
  description = "Hosted zone ID. Consumed by every app stack."
  value       = data.aws_route53_zone.this.zone_id
}

# Re-exported from the variable, not from the data source, per the ADR 0003
# amendment of 2026-08-06. The data source returns the name with a trailing
# dot; app stacks want the form they can build a subdomain from.
output "domain_name" {
  description = "Apex domain. App stacks read this rather than declaring a copy."
  value       = var.domain_name
}

# The validation resource's arn, not the certificate's. Same string, but
# reading it here means a consumer cannot attach a certificate that ACM has
# not issued yet.
output "certificate_arn" {
  description = "Validated certificate covering the apex and *.apex."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
```

The `oidc_provider_arn` output is added in Unit 1.5.

**Verify.**

```powershell
cd ../platform
Copy-Item terraform.tfvars.example terraform.tfvars   # then fill it in
terraform init
terraform apply
```

The apply can sit on `aws_acm_certificate_validation` for several minutes. That
is DNS propagation plus ACM's polling interval, not a hang.

```powershell
$cert = terraform output -raw certificate_arn
aws acm describe-certificate --certificate-arn $cert --query "Certificate.Status" --output text
```
Expected: `ISSUED`

```powershell
aws acm describe-certificate --certificate-arn $cert --query "Certificate.SubjectAlternativeNames" --output json
```
Expected: both the apex and `*.<domain>`.

---

## Unit 1.5: The OIDC provider

**Trade-off brief.**

This is the resource that makes [[0002-github-oidc-deploy-identity]] real: the
account-level statement that tokens signed by
`token.actions.githubusercontent.com` are worth evaluating. It is
account-scoped, so it belongs in `platform/` and there is exactly one no matter
how many apps deploy.

The thumbprint argument is where this gets murky. Historically it was the SHA-1
fingerprint of the CA certificate in the issuer's TLS chain, and it had to be
manually updated when GitHub rotated CAs. Three ways to handle it:

1. Hardcode the well-known fingerprint. Reproducible, and it goes stale.
2. Read it at plan time with `data "tls_certificate"`. Always current, and it
   adds a provider plus a network call during plan.
3. Omit it entirely. No second provider, no data source, no value to keep
   current.

**Verified 2026-08-07, replacing this section's earlier uncertainty flag.** IAM
verifies the OIDC endpoint's TLS certificate against its own library of trusted
root certificate authorities. The thumbprint is consulted only as a fallback:
when the issuer's certificate is not signed by a trusted CA, when AWS cannot
retrieve the certificate, or when TLS 1.3 is required. GitHub's issuer uses a
well-known CA, so for this provider the thumbprint is never read. This became
GitHub-specific behavior on 2023-07-06 and general IAM behavior in July 2024.

The earlier draft also claimed the API still requires the field to be
populated. That is wrong. `CreateOpenIDConnectProvider` treats the thumbprint as
optional and derives one itself when it is absent, and the AWS provider declares
`thumbprint_list` as `Optional: true, Computed: true`, so omitting it records
AWS's derived value in state rather than leaving a permanent diff.

Option 3 is the choice. Options 1 and 2 both pay something to compute a value
that has no consumer. Option 2 stays the right answer for an issuer whose
certificate chain does not come from a well-known CA.

Sources: IAM's "Obtain the thumbprint for an OpenID Connect identity provider",
the GitHub changelog entry of 2023-07-13, and the AWS IAM announcement of July
2024.

**Build.**

- `aws_iam_openid_connect_provider` with `url` set to the issuer and
  `client_id_list = ["sts.amazonaws.com"]`. No `thumbprint_list`.
- Output `oidc_provider_arn`.

`platform/versions.tf` is unchanged. Under option 2 this unit would have added
`hashicorp/tls` to `required_providers`; option 3 needs no second provider.

**Compare.**

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
```

`client_id_list` holding `sts.amazonaws.com` is the audience. The workflow's
token carries `aud: sts.amazonaws.com` when
`aws-actions/configure-aws-credentials` requests it, and the role's trust
policy conditions on the same value in Session 2. The provider says which
audiences are acceptable at all; the role says which one it wants.

**Verify.**

```powershell
$oidc = terraform output -raw oidc_provider_arn
aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidc --query "ClientIDList" --output text
```
Expected: `sts.amazonaws.com`

```powershell
aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidc --query "length(ThumbprintList)" --output text
```
Expected: `1`. The config never supplies a thumbprint, so a non-zero count is
IAM deriving one on its own, which is the option 3 claim made concrete.

```powershell
terraform plan -detailed-exitcode; $LASTEXITCODE
```
Expected: `0`. This is the check that `thumbprint_list` being `Computed` holds:
exit 2 would mean the derived value shows as a diff on every plan.

---

## Unit 1.6: The budget alarm

**Trade-off brief.**

Spec 0001 calls the budget the deliberate observability choice, and it is worth
being able to defend rather than just having.

CloudFront access logs cost S3 storage to collect and nobody reads them on a
personal site. CloudWatch alarms on CloudFront metrics tell you about traffic,
not cost, and the free-tier failure mode is a cost surprise. A budget with an
email notification reports the single number that matters on a free-tier
account.

Two notification types, and both are worth having:

- `ACTUAL` at 80% fires after the money is spent. Accurate, late.
- `FORECASTED` at 100% fires when AWS projects the month will exceed the
  threshold. Early, and it can be noisy in the first days of a month when the
  forecast extrapolates from thin data.

**Decide.** Threshold amount, and whether to take both notifications.

**Build.**

`aws_budgets_budget` with `budget_type = "COST"`, `time_unit = "MONTHLY"`,
`limit_unit = "USD"`, and the limit from a variable. Two `notification` blocks
per the decision above. The email address comes from a variable, never a
literal — it keeps a personal address out of the repository and makes the
platform reusable.

**Compare.**

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-total"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
```

`limit_amount` is a string in the AWS provider, not a number. Passing a number
works through Terraform's type conversion but the variable is typed `string`
above to match.

**Verify.**

```powershell
$acct = aws sts get-caller-identity --query "Account" --output text
aws budgets describe-budget --account-id $acct --budget-name monthly-total --query "Budget.BudgetLimit" --output json
```
Expected: the amount and `USD`.

```powershell
terraform plan -detailed-exitcode; $LASTEXITCODE
```
Expected: `0`

**Commit.**

```bash
git add infra/platform/
git commit -m "Platform: zone lookup, certificate, OIDC provider, budget alarm

Zone is a data source so no plan can touch the NS records. One certificate
carries the apex and the wildcard because a wildcard does not match the
apex. Budget over CloudFront access logs: cost is the number that matters
on a free-tier account, and logs would cost storage to go unread.

Implements ADR-0002 and ADR-0003."
```

---

## Quiz 1

Answer out loud, in full sentences, before reading the key.

1. The state bucket exists. Where is the state that describes it, and what
   breaks if that file is lost? What is the recovery path?
2. Why does the backend block hardcode the bucket name instead of referencing
   the bootstrap output?
3. `terraform plan -detailed-exitcode` returned 2 on a stack you just applied.
   What does that mean, and why is it a defect rather than noise?
4. Someone runs `terraform destroy` in `platform/`. What happens to the domain?
   What happens to the hosted zone?
5. Why does the certificate need both `example.com` and `*.example.com` when
   the wildcard looks broader?
6. What does `aws_acm_certificate_validation` actually create in AWS?
7. `allow_overwrite = true` is on the validation records. What failure does it
   prevent, and what failure could it now hide?
8. The OIDC provider exists but no role trusts it yet. Can a GitHub workflow do
   anything with it? Why or why not?
9. Why is `create_before_destroy` on the certificate and not on the bucket?

### Answer key

1. `infra/bootstrap/terraform.tfstate`, on the laptop, gitignored. Losing it
   means Terraform no longer knows the bucket exists — the bucket itself is
   untouched and every other stack keeps working, because nothing else manages
   it. Recovery is `terraform import` of the bucket and its four sub-resources
   into a fresh state file, not a rebuild. `prevent_destroy` is a lifecycle
   rule stored in the configuration, so it survives the state loss.
2. Backend configuration is read before Terraform evaluates variables, outputs,
   or any expression, so no interpolation is available there. That is why
   bootstrap outputs the name for a human to paste, and it is also why the
   backend can be partially configured on the command line if you'd rather not
   hardcode it.
3. Exit 2 means the plan is non-empty: applying again would change something.
   Immediately after a successful apply that means the configuration does not
   converge — typically a computed attribute written back as an input, or a
   value AWS normalizes differently from what was declared. It is a defect
   because success criterion 8 is exactly "plan on a clean tree reports no
   changes," and because a permanently dirty plan destroys the signal that
   would otherwise reveal real drift.
4. The domain registration is untouched; it was never in Terraform. The hosted
   zone is untouched too, because it is a data source and destroy only removes
   managed resources. What does get destroyed is the certificate, the
   validation records, the OIDC provider, and the budget — and destroying the
   certificate fails while a distribution still references it.
5. A wildcard certificate covers one label at the position of the `*`.
   `*.example.com` matches `www.example.com` but not the apex `example.com`,
   and not `a.b.example.com`. The apex has to be named explicitly.
6. Nothing. It has no AWS resource behind it. It polls until ACM reports the
   certificate `ISSUED` and then completes, which gives downstream resources
   something concrete to depend on so they cannot attach a pending certificate.
7. It prevents the collision between the apex's and the wildcard's validation
   records, which ACM emits as two entries carrying identical name and value.
   What it can now hide: a genuinely conflicting record at the same name
   created by something else gets silently overwritten instead of failing the
   apply.
8. No. The provider establishes that tokens from that issuer can be evaluated;
   it grants nothing. Without a role whose trust policy names the provider as a
   federated principal, `AssumeRoleWithWebIdentity` has no role to return
   credentials for.
9. Because the failure modes differ. A certificate in use by a distribution
   cannot be deleted, so destroy-then-create deadlocks on any replacement. The
   bucket has the opposite concern — it holds state, so the desired behavior is
   to never replace it at all, which is what `prevent_destroy` expresses.

---

# Session 2: The static-site module and the portfolio stack

**Deliverable:** the site is live at the domain, served from a bucket nobody
else can read.

**Session-end checkpoint:** the six infrastructure checks from spec 0001,
including the 403 on the direct S3 URL.

---

## Unit 2.1: Where the module boundary goes

**Trade-off brief.**

[[0003-terraform-topology]] says a module gets extracted before the second
copy-paste, not after. The hard part is not whether to have a module, it is
deciding what is a variable and what is hardcoded inside it — and spec 0001 is
honest that **a module with one consumer is a guess**. The recipe app is the
first real test.

Three candidate boundaries:

1. **Everything a static site needs, one variable per decision.** Maximum
   reuse, and a variables file long enough that calling the module is as much
   work as writing the resources.
2. **Opinionated: hardcode the decisions that are the same for every site here
   — price class, cache policy, protocol policy, security headers — and take
   variables only for what actually differs.** Fewer knobs, and the second
   consumer may need one of the hardcoded values.
3. **Thin wrapper around the distribution only**, with buckets and DNS in each
   stack. Barely a module.

Option 2 is the right default. The decisions that differ per site are: the
FQDN, which hosts redirect to it, the zone, the certificate, the OIDC provider,
and the GitHub subject. Everything else is a house style, and a house style
belongs in the module. When the recipe app needs a different value, promoting a
hardcoded value to a variable is a small, obvious diff — much smaller than the
cost of ten speculative variables that never get a second value.

**Decide.** The variable list. Write it down before writing any resource.

**Build.**

`infra/modules/static-site/variables.tf`:

```hcl
variable "fqdn" {
  description = "Primary hostname this site serves, no trailing dot."
  type        = string
}

variable "redirect_hosts" {
  description = "Hostnames that 301 to fqdn. Empty for subdomain apps."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route 53 hosted zone ID from the platform stack."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN covering fqdn and redirect_hosts."
  type        = string
}

variable "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN from the platform stack."
  type        = string
}

variable "github_sub" {
  description = "Exact sub claim allowed to assume the deploy role, e.g. repo:owner/name:ref:refs/heads/main"
  type        = string
}

variable "content_security_policy" {
  description = "CSP header value. Site-specific because it depends on what the build emits."
  type        = string
}
```

`content_security_policy` is a variable rather than a module constant on
purpose: the recipe app will load something this site does not, and a CSP
baked into the module would be either wrong for it or loose enough to be
worthless here. That is the one place where "what the site emits" leaks into
the infrastructure, and it is better as an explicit argument than as a lie in
the module.

---

## Unit 2.2: Bucket, OAC, and the SourceArn condition

**Trade-off brief.**

Three ways CloudFront can read a private S3 bucket:

1. **Public bucket, no signing.** Anyone can read the bucket directly and
   bypass CloudFront entirely, which means bypassing the security headers, the
   HTTPS redirect, and the WAF you might add later. Success criterion 2 exists
   specifically to prove this is not what shipped.
2. **Origin Access Identity (OAI).** The predecessor. Still works, does not
   support SSE-KMS or newer regions, and AWS documents OAC as the replacement.
3. **Origin Access Control (OAC)** with sigv4. CloudFront signs each origin
   request; the bucket policy grants read to the CloudFront service principal.

OAC is the spec's choice. The part that carries the real security weight is the
**condition** on the bucket policy. Granting `s3:GetObject` to
`cloudfront.amazonaws.com` without a condition grants it to *every* CloudFront
distribution in *every* AWS account — anyone who learns the bucket name can
point their own distribution at it and serve your bucket. The
`AWS:SourceArn` condition matching this one distribution is what closes that.

Also: ownership controls set to `BucketOwnerEnforced` turns ACLs off entirely.
With ACLs disabled, object ownership is unambiguous and the deploy role does
not need `s3:PutObjectAcl`. Fewer permissions and fewer ways to make an object
public by accident.

**Build.**

In `infra/modules/static-site/main.tf`:

- `data "aws_caller_identity" "current"`.
- `aws_s3_bucket` named from the FQDN and the account ID (`example-com-<id>`)
  — dots are legal in bucket names but complicate virtual-host-style TLS, so
  replace them.
- `aws_s3_bucket_public_access_block`, all four true.
- `aws_s3_bucket_ownership_controls` set to `BucketOwnerEnforced`.
- `aws_cloudfront_origin_access_control` with `signing_behavior = "always"` and
  `signing_protocol = "sigv4"`.
- `aws_s3_bucket_policy` built from `data "aws_iam_policy_document"`, granting
  only `s3:GetObject` to the service principal, conditioned on `AWS:SourceArn`
  equal to the distribution ARN.

**Compare.**

```hcl
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${replace(var.fqdn, ".", "-")}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = local.bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "AllowThisDistributionOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.site.arn}/*"]

    # Without this, the grant covers every CloudFront distribution in every
    # AWS account, not just this one.
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket.json
}
```

The bucket policy references the distribution and the distribution references
the bucket. That is not a cycle: the distribution needs the bucket's *domain
name*, and the policy is a third resource that depends on both. Terraform
orders it bucket, distribution, policy. There is a brief window mid-apply where
the distribution exists and cannot read the origin, which resolves when the
policy lands.

---

## Unit 2.3: The distribution and the response headers policy

**Trade-off brief, part one: cache policy.**

Managed `CachingOptimized` forwards no cookies, no query strings, and no
headers to the origin, and it compresses. For a static site that is exactly
right — every viewer gets the same bytes, so the cache key should be the path
and nothing else. A custom cache policy would let you tune TTLs, and the
`Cache-Control` headers set at upload time already do that job from the origin
side. Managed policy, no custom policy.

**Trade-off brief, part two: price class.**

`PriceClass_100` is North America and Europe. `PriceClass_All` adds Asia,
South America, and Oceania at higher per-request rates. For a personal site
whose audience is mostly local, `PriceClass_100` is the cost-aware default and
viewers elsewhere still get served, just from a farther edge.

**Trade-off brief, part three: the CSP, and why it has a site-side prerequisite.**

Spec 0001 carries this forward as an open input: `build.inlineStylesheets` is
unpinned, and Astro's `'auto'` inlines stylesheets under roughly 4 kB. The
build actually crossed that threshold mid-project and flipped from an inline
`<style>` to an external hashed file. The current `dist/` emits
`/_astro/index.<hash>.css`, external.

That decides the CSP, so it has to be pinned first:

| Pin | Output | CSP consequence |
|---|---|---|
| `'never'` | External hashed `.css` | `style-src 'self'` — tight, and the file gets the immutable cache pass |
| `'always'` | Inline `<style>` | Needs `'unsafe-inline'`, since Astro emits no nonce or hash |
| `'auto'` | Depends on file size | The CSP silently becomes wrong when the stylesheet crosses 4 kB |

`'never'` is the clear answer: it keeps `'unsafe-inline'` out of the CSP and
makes the output stable. The cost is one extra request, which HTTP/2 over
CloudFront makes close to free.

With that pinned, the site loads a stylesheet, a font, and a favicon, all from
its own origin, and no JavaScript at all. So:

```
default-src 'none'; img-src 'self'; style-src 'self'; font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
```

`default-src 'none'` covers `script-src` — the zero-JavaScript guarantee
becomes a header the browser enforces, not just a property of the build.
`img-src 'self'` will need revisiting when the first real thumbnail lands if
Astro ever inlines a small image as a data URI; that is a re-check, not a
change today.

**Trade-off brief, part four: HSTS scope.**

`includeSubDomains` on the apex commits every future subdomain to HTTPS-only in
every browser that has seen the header, for the length of `max-age`. That is
desirable here — every planned app subdomain will be HTTPS behind CloudFront —
but it is a real commitment with a one-year memory, so it should be a decision
rather than a copied default. `preload` is a separate step requiring submission
to the browser preload list; setting the flag without submitting claims an
intent nothing acts on. Leave `preload = false`.

`X-XSS-Protection` is deliberately absent. It is deprecated, browsers have
removed it, and on the browsers that still honor it the filter has its own
vulnerability history. CSP replaces it.

**Decide.** Pin value for `inlineStylesheets`, price class, the CSP string, and
the HSTS scope.

**Build.**

Pin the site config first, since the CSP depends on it:

```js
// site/astro.config.mjs
export default defineConfig({
  site: 'https://<the registered domain>',
  build: {
    format: 'file',
    // Pinned: 'auto' flips to an inline <style> under ~4 kB, which would
    // silently invalidate style-src 'self' in the CloudFront CSP.
    inlineStylesheets: 'never',
  },
});
```

Then rebuild and confirm the output shape did not change:

```powershell
cd site
npm run build
Get-ChildItem dist -Recurse -Filter *.css | Select-Object Name
Select-String -Path dist/index.html -Pattern "<style" -SimpleMatch
```
Expected: one hashed `.css` under `dist/_astro/`, and **no match** for
`<style`. Then `npm run test:a11y` still passes — the a11y suite counts
`<script>` elements, so this change should not move it, and if it does that is
information.

Then write the distribution and the response headers policy.

**Compare.**

```hcl
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "site" {
  name = "${replace(var.fqdn, ".", "-")}-security-headers"

  security_headers_config {
    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = concat([var.fqdn], var.redirect_hosts)
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-${local.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect.arn
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
```

`bucket_regional_domain_name`, not `bucket_domain_name`. The regional form
avoids a redirect on the first request to a bucket outside us-east-1, and it is
the form OAC expects.

`allowed_methods` limited to GET and HEAD means the distribution cannot forward
a POST or DELETE to the origin at all. For a static site that is free defense.

---

## Unit 2.4: The www redirect

**Trade-off brief.**

`www.example.com` should not serve a duplicate of the apex — that is two
canonical URLs for one page. Options:

1. **A second S3 bucket configured as a website redirect**, with its own
   distribution. The classic pre-Functions answer. Two more resources and a
   second distribution to keep in sync.
2. **A CloudFront Function on viewer-request** that 301s any non-apex host.
   Runs at the edge before the cache, sub-millisecond, and the free tier covers
   2 million invocations a month.
3. **A Lambda@Edge function.** Same job, cold starts, higher cost, replication
   to every region, and much slower to update. Overkill for a string compare.
4. **Nothing** — let www 404 or not resolve. Free, and people type www.

Option 2 is the spec's choice. Two things worth being precise about:

The function runs on **every** viewer request, including apex requests that
just pass through. At personal-site volume that stays inside the free tier, and
it is a real per-request cost to be aware of rather than surprised by.

It does not contradict the zero-JavaScript guarantee. That guarantee is about
what reaches the browser; a CloudFront Function is server-side JavaScript
executing at the edge. Worth being able to say cleanly, because it looks like a
contradiction at a glance.

**Known limit to accept deliberately:** the redirect below drops the query
string. `event.request.querystring` is an object that has to be reassembled,
and this site takes no query parameters. If a future app on this module needs
them, this is where to fix it.

**Build.**

Create `infra/modules/static-site/redirect.js.tftpl` and an
`aws_cloudfront_function` that loads it through `templatefile`, injecting the
apex.

**Compare.**

```js
// infra/modules/static-site/redirect.js.tftpl
function handler(event) {
  var request = event.request;
  var host = request.headers.host.value;

  if (host === '${apex}') {
    return request;
  }

  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: {
      location: { value: 'https://${apex}' + request.uri }
    }
  };
}
```

```hcl
resource "aws_cloudfront_function" "redirect" {
  name    = "${replace(var.fqdn, ".", "-")}-canonical-host"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/redirect.js.tftpl", { apex = var.fqdn })
}
```

`${apex}` in the `.tftpl` is Terraform template interpolation, not JavaScript.
The function body uses string concatenation rather than template literals
specifically so the two syntaxes cannot collide.

---

## Unit 2.5: DNS records

**Trade-off brief.**

An alias record is a Route 53 extension: it resolves to the target's addresses
at query time and costs nothing to query, where a CNAME is a real DNS record
that adds a resolution hop and **cannot exist at the zone apex**. The apex is
exactly where this site lives, so alias is not a preference.

Both A and AAAA, because `is_ipv6_enabled` is on and an AAAA-only client with
no AAAA record fails.

The alias target's `zone_id` is CloudFront's own hosted zone ID. It can be
hardcoded — `Z2FDTNDATAQYW2` is the well-known constant for all CloudFront
distributions — or read from `aws_cloudfront_distribution.site.hosted_zone_id`.
Spec 0001 explicitly requires the attribute. A hardcoded magic string that
happens to be right is the kind of thing that is wrong once and undiagnosable.

**Build.**

Two resources, each with `for_each` over the set of hostnames — apex plus
redirect hosts. The redirect hosts need records too: the CloudFront Function
cannot 301 a request that never resolves.

**Compare.**

```hcl
locals {
  all_hosts = toset(concat([var.fqdn], var.redirect_hosts))
}

resource "aws_route53_record" "a" {
  for_each = local.all_hosts

  zone_id = var.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  for_each = local.all_hosts

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
```

`for_each` over a set rather than `count` over a list is deliberate. With
`count`, removing the first element of a two-element list renumbers the second
from index 1 to index 0, and Terraform destroys and recreates it. With
`for_each`, each record's address in state is its hostname, so removing one
touches only that one. That difference is invisible with one element and
destructive with three.

---

## Unit 2.6: The deploy role

**Trade-off brief.**

The trust policy is the security boundary of the entire deploy path. Its
conditions decide who can assume the role.

Three levels of scoping on the `sub` claim, and the difference matters:

1. `repo:owner/name:*` — any branch, any tag, **any pull request** in the
   repository. On a public repository that means a fork PR could potentially
   reach a workflow that assumes this role.
2. `repo:owner/name:ref:refs/heads/*` — any branch. A pushed branch gets
   production write.
3. `repo:owner/name:ref:refs/heads/main` — exactly one ref. This one.

The `aud` condition matters independently. Without it, a token issued to a
different audience by the same issuer could satisfy the subject condition.
`StringEquals` on both claims, never `StringLike`, and never a wildcard in the
subject.

On the permission side, the least-privilege set for what the workflow actually
runs — three sync passes and an invalidation:

- `s3:PutObject` on `bucket/*`, to upload.
- `s3:DeleteObject` on `bucket/*`, because the first pass uses `--delete`.
- `s3:ListBucket` on the bucket itself — note the different resource ARN, no
  `/*`; it is a bucket-level action, and this is the single most common IAM
  mistake in this shape.
- `cloudfront:CreateInvalidation` on the distribution ARN.

Not `s3:PutObjectAcl` — `BucketOwnerEnforced` means there are no object ACLs to
set. Not `s3:GetObject` — sync compares by listing the destination. Not
`cloudfront:*`.

**Decide.** Confirm the subject string, and confirm the action list against
what the workflow in Session 3 actually runs.

**Build.**

An assume-role policy document with a `Federated` principal and two
`StringEquals` conditions, plus an inline permission policy on the role.

**Compare.**

```hcl
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringEquals, not StringLike. A wildcard here would let any branch,
    # tag, or pull request in the repository assume this role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_sub]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${replace(var.fqdn, ".", "-")}-deploy"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
```

`infra/modules/static-site/outputs.tf`:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.site.id
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
```

---

## Unit 2.7: The portfolio stack and the first apply

**Trade-off brief.**

How does the stack learn the platform's zone ID, certificate ARN, OIDC provider
ARN, and domain name? Three options:

1. **`terraform_remote_state`.** Reads platform's state file directly. Coupled
   to the state layout, and it needs read access to the state bucket. Refactors
   in platform's *outputs* are breaking; refactors in its internals are not.
2. **Data sources re-looking-up each resource** (`aws_route53_zone`,
   `aws_acm_certificate`). No state coupling, and it re-queries AWS for facts
   another stack already computed, matching on names that are now implicit
   contracts.
3. **Copy the values into tfvars by hand.** No coupling and no automation. Goes
   stale silently.

[[0003-terraform-topology]] chose remote state, and named the consequence:
platform's outputs are a public interface and changing them is a breaking
change for every app stack.

Its 2026-08-06 amendment extends that to the domain name itself. Option 3 was
tempting for one string — it is just the apex, and each stack could take it as
a tfvar. The amendment rejects that: five stacks holding five copies of one
string have nothing comparing them, and a typo in any copy still produces a
valid plan pointing at the wrong DNS record. Reading it from platform puts the
constraint in the dependency graph, where a mistake fails at plan time.

**Build.**

`infra/stacks/portfolio/` with `versions.tf`, `backend.tf`
(`key = "portfolio/terraform.tfstate"`), `variables.tf`, `main.tf`,
`outputs.tf`, and `terraform.tfvars.example`.

**Compare.**

```hcl
# infra/stacks/portfolio/variables.tf

# No domain_name variable here. The ADR 0003 amendment of 2026-08-06 puts the
# domain in the platform outputs, so app stacks read it instead of holding a
# copy. A stack that genuinely needs a different domain adds an override
# variable defaulting to the platform output, which keeps the exception
# visible in that stack's config.

# The backend block hardcodes this same bucket because backend configuration
# cannot interpolate. The variable exists for the remote state data source,
# which can.
variable "state_bucket" {
  description = "Terraform state bucket created by infra/bootstrap."
  type        = string
}
```

```hcl
# infra/stacks/portfolio/main.tf
data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  domain_name = data.terraform_remote_state.platform.outputs.domain_name
}

module "site" {
  source = "../../modules/static-site"

  fqdn              = local.domain_name
  redirect_hosts    = ["www.${local.domain_name}"]
  zone_id           = data.terraform_remote_state.platform.outputs.zone_id
  certificate_arn   = data.terraform_remote_state.platform.outputs.certificate_arn
  oidc_provider_arn = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  github_sub        = "repo:philliam-nguyen/dev_site:ref:refs/heads/main"

  content_security_policy = join("; ", [
    "default-src 'none'",
    "img-src 'self'",
    "style-src 'self'",
    "font-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  ])
}
```

```hcl
# infra/stacks/portfolio/outputs.tf
output "bucket_name" {
  value = module.site.bucket_name
}

output "distribution_id" {
  value = module.site.distribution_id
}

output "deploy_role_arn" {
  value = module.site.deploy_role_arn
}
```

**Verify. This is the session's real checkpoint.**

```powershell
cd infra/stacks/portfolio
terraform init
terraform apply
```

The first apply takes several minutes; a new distribution has to reach
`Deployed`. Then upload the current build by hand — the workflow does not exist
until Session 3:

```powershell
$bucket = terraform output -raw bucket_name
$dist   = terraform output -raw distribution_id
aws s3 sync ../../../site/dist "s3://$bucket" --delete
aws cloudfront create-invalidation --distribution-id $dist --paths "/*"
```

Now run every check from spec 0001. Each one emits a value.

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" https://<domain>
```
Expected: `200`

```powershell
curl.exe -sI https://<domain> | Select-String -Pattern "strict-transport-security|content-security-policy|x-content-type-options"
```
Expected: all three headers present, HSTS carrying `max-age=31536000; includeSubDomains`.

```powershell
curl.exe -s -o NUL -w "%{http_code} %{redirect_url}`n" http://<domain>
```
Expected: `301` and an `https://` target.

```powershell
curl.exe -s -o NUL -w "%{http_code} %{redirect_url}`n" https://www.<domain>
```
Expected: `301` and the apex URL.

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" "https://$bucket.s3.amazonaws.com/index.html"
```
Expected: **`403`**. This is the one that separates "the site works" from "the
site works and the bucket is not readable by anyone else." A `200` here means
success criterion 2 fails and the bucket policy condition or the public access
block is wrong.

```powershell
aws s3api get-public-access-block --bucket $bucket --query "PublicAccessBlockConfiguration" --output json
```
Expected: four `true`.

```powershell
Resolve-DnsName <domain> -Type A | Select-Object -ExpandProperty IPAddress
```
Expected: CloudFront edge addresses, and more than one.

```powershell
terraform plan -detailed-exitcode; $LASTEXITCODE
```
Expected: `0`. This is success criterion 8.

**Commit.**

```bash
git add infra/modules/ infra/stacks/
git commit -m "static-site module and the portfolio stack

Bucket is private behind OAC, and the bucket policy conditions on
AWS:SourceArn so the grant covers this distribution rather than every
CloudFront distribution in every account. Verified: direct S3 URL
returns 403.

Deploy role trusts exactly one sub claim, no wildcard, and holds four
actions scoped to this bucket and this distribution.

Implements ADR-0002 and ADR-0003."
```

---

## Quiz 2

1. The bucket policy grants `s3:GetObject` to `cloudfront.amazonaws.com`.
   Without the `AWS:SourceArn` condition, who exactly can read the bucket, and
   how would they do it?
2. The bucket policy references the distribution, and the distribution
   references the bucket. Why is that not a dependency cycle? What is the state
   of the site partway through the first apply?
3. Why is `s3:ListBucket` on a different resource ARN than `s3:PutObject`?
4. Why `for_each` over hostnames rather than `count` over a list, for the DNS
   records?
5. The site ships zero JavaScript, and a CloudFront Function runs JavaScript on
   every request. Reconcile those.
6. `include_subdomains = true` on HSTS. What exactly have you committed to, for
   how long, and what breaks if you later want an HTTP-only subdomain?
7. Why does the CSP say `default-src 'none'` instead of listing `script-src
   'none'` explicitly?
8. Someone changes `inlineStylesheets` back to `'auto'` and the stylesheet
   shrinks below 4 kB. What breaks, and would any existing test catch it?
9. `terraform destroy` on the portfolio stack while platform stays. What
   survives?

### Answer key

1. Every CloudFront distribution in every AWS account. The service principal is
   not account-scoped, so anyone who learns the bucket name can create their
   own distribution with an OAC pointing at your bucket and serve its contents
   from their domain. The `AWS:SourceArn` condition narrows the grant to
   requests signed on behalf of this specific distribution.
2. The distribution depends on the bucket's `bucket_regional_domain_name`, not
   on the policy. The policy is a third resource depending on both, so the
   order is bucket, distribution, policy. Between the distribution being
   created and the policy landing, the distribution exists and gets
   `AccessDenied` from the origin — a real window, self-healing, and worth
   knowing about when a first apply is interrupted.
3. `ListBucket` is an operation on the bucket, so its resource is
   `arn:aws:s3:::name`. `PutObject` and `DeleteObject` operate on objects, so
   theirs is `arn:aws:s3:::name/*`. Using the object ARN for `ListBucket`
   silently grants nothing, and `aws s3 sync` then fails on the destination
   listing rather than on the upload, which makes it look like a network
   problem.
4. `count` addresses resources by list index. Remove the first of two hosts and
   the second shifts from index 1 to index 0, so Terraform destroys and
   recreates a DNS record that should not have been touched. `for_each`
   addresses by key — the hostname — so state addresses are stable under
   insertion and removal.
5. The zero-JavaScript property is about what the browser executes. The
   CloudFront Function is server-side, running at the edge before the response
   is built; nothing about it is delivered to the client. The built HTML still
   contains no `<script>`, no `.js` request, and no `on*` attribute, which is
   what the a11y suite asserts.
6. Every hostname under the apex must serve valid HTTPS, in any browser that
   has seen the header, for one year from its last visit. An HTTP-only
   subdomain would be unreachable for those visitors. Lowering `max-age` does
   not retroactively shorten what browsers already stored; you have to serve a
   smaller `max-age` and wait for visitors to return. That is why it is a
   decision rather than a default.
7. `default-src` is the fallback for every fetch directive that is not
   specified, `script-src` included. `'none'` there means anything not
   explicitly allowed is blocked, so a directive nobody thought of — `connect-src`,
   `worker-src`, `object-src` — is denied by default rather than open. Listing
   directives individually inverts that: whatever you forget is allowed.
8. Astro inlines the stylesheet into a `<style>` element, and the CSP's
   `style-src 'self'` blocks it, so the page renders unstyled in production.
   No existing test catches it: the a11y suite runs against a local preview
   with no CloudFront and therefore no CSP header, and it counts `<script>`
   elements, not `<style>`. That gap is the reason the pin exists, and it is a
   candidate for a real test — asserting `dist/index.html` contains no
   `<style`.
9. The hosted zone, the certificate, the OIDC provider, and the budget — all in
   platform. The bucket and its contents, the distribution, the DNS records for
   apex and www, the CloudFront Function, and the deploy role all go. The
   domain stays registered. Bringing it back is one `apply` plus a re-upload,
   with a new distribution domain name behind the same alias records.

---

# Session 3: The deploy path

**Deliverable:** a push to `main` touching `site/` deploys the site with no
stored AWS credential.

**Session-end checkpoint:** all eight success criteria verified.

---

## Unit 3.1: The repository variable

**Trade-off brief.**

The deploy role ARN has to reach the workflow. Three places:

1. **Hardcoded in the YAML.** Visible in a public repo — which is fine, an ARN
   is not a secret — and it makes the workflow file app-specific, so each new
   app stack forks the workflow rather than reusing its shape.
2. **A repository secret.** Encrypted, masked in logs. It is not a secret, and
   storing non-secrets as secrets means the masking hides the value when you
   are trying to debug why the assume failed.
3. **A repository variable.** Plain, readable in logs, one value to change per
   app.

Spec 0001 picked the variable, and the reasoning is reuse: the same workflow
shape drops into a later app stack with one value changed. An ARN is an
identifier, not a credential — the trust policy is what makes it useless to
anyone else.

**Build.**

```powershell
cd infra/stacks/portfolio
$role = terraform output -raw deploy_role_arn
gh variable set AWS_DEPLOY_ROLE_ARN --body $role --repo philliam-nguyen/dev_site
```

**Verify.**

```powershell
gh variable list --repo philliam-nguyen/dev_site
```
Expected: `AWS_DEPLOY_ROLE_ARN` with the ARN visible.

---

## Unit 3.2: The deploy workflow

**Trade-off brief, part one: the cache passes.**

Spec 0001 specifies two sync passes and says the order matters. Both facts need
unpacking, and the spec's own carried-forward findings turn two passes into
three.

**Why order matters.** HTML references hashed asset filenames. Upload the HTML
first and, for the duration of the asset pass, a visitor gets a page whose
stylesheet 404s. Assets first means the worst case is a visitor getting the old
HTML, which references old assets that are still present.

**Why two passes are not enough.** The immutable pass gives everything except
`*.html` a one-year `immutable` header. Astro content-hashes files in `_astro/`,
so a changed file is a changed URL and the long TTL is safe. But
`favicon.svg` and `fonts/anton.woff2` **keep stable filenames** — spec 0001
carries this forward explicitly. Marking them immutable for a year means
changing the font or the favicon leaves every prior visitor on the old one
until the TTL expires, and a CloudFront invalidation does not help because the
stale copy is in the *browser* cache.

Three ways out:

1. Rename the file whenever its contents change. Relies on a human remembering,
   with a year-long consequence for forgetting.
2. Exclude both from the immutable pass and give them a moderate TTL. One extra
   sync pass, no memory required.
3. Move both into Astro's asset pipeline so they get hashed. Cleanest, and it
   is a site change fighting how favicons and preloaded fonts are referenced.

Option 2 is the pragmatic choice here, and option 3 is worth revisiting if the
unhashed set ever grows.

**A limit to accept:** `--delete` lives on the first pass, which excludes HTML.
Stale hashed assets get cleaned up; a deleted HTML page would linger. This is a
one-page site, so the cost is theoretical — but it is a real asymmetry and
worth knowing rather than discovering.

**Trade-off brief, part two: what gates the deploy.**

`astro check`, `npm test`, and `npm run test:a11y` all run before the build. The
a11y suite is the one with a design argument behind it: [[0004-visual-identity-port]]
makes an accessibility guarantee, and running the suite only locally makes that
guarantee a habit rather than a rule. In CI it is binding.

`npx playwright install chromium` is a separate step because `npm ci` does not
download browsers. Spec 0001 carries this forward; omitting it fails the a11y
step with a confusing browser-not-found error.

**Trade-off brief, part three: concurrency.**

`cancel-in-progress: false`. Cancelling a deploy mid-sync leaves the bucket in
a mixed state — some new assets, old HTML, or worse. Queuing means two rapid
pushes deploy in order and the second wins, which is correct.

**Build.**

Create `.github/workflows/deploy.yml`.

**Check the current major of `aws-actions/configure-aws-credentials` before
committing.** The version below was current at the time of writing and this is
the exact failure class — a stale version pin — that produced defects in the
site build.

```powershell
gh api repos/aws-actions/configure-aws-credentials/releases/latest --jq .tag_name
gh api repos/actions/checkout/releases/latest --jq .tag_name
gh api repos/actions/setup-node/releases/latest --jq .tag_name
```

**Compare.**

```yaml
name: deploy

on:
  push:
    branches: [main]
    paths:
      - 'site/**'
      - '.github/workflows/deploy.yml'
  workflow_dispatch:

concurrency:
  group: deploy
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: site

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '22.12'
          cache: npm
          cache-dependency-path: site/package-lock.json

      - run: npm ci

      # npm ci does not download browsers, and test:a11y needs one.
      - run: npx playwright install chromium

      - run: npx astro check
      - run: npm test
      - run: npm run test:a11y
      - run: npm run build

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: us-east-1

      - name: Confirm the assumed identity
        run: aws sts get-caller-identity

      # Pass 1: content-hashed assets. A changed file is a changed URL, so a
      # year-long immutable TTL is safe. --delete lives here so stale hashed
      # assets get cleaned up.
      - name: Sync hashed assets
        run: |
          aws s3 sync dist "s3://${{ vars.SITE_BUCKET }}" --delete \
            --cache-control "public,max-age=31536000,immutable" \
            --exclude "*.html" \
            --exclude "favicon.svg" \
            --exclude "fonts/*"

      # Pass 2: assets with stable filenames. Immutable here would strand a
      # visitor on an old font or favicon for a year, and an invalidation
      # cannot reach a browser cache.
      - name: Sync unhashed assets
        run: |
          aws s3 sync dist "s3://${{ vars.SITE_BUCKET }}" \
            --cache-control "public,max-age=86400" \
            --exclude "*" \
            --include "favicon.svg" \
            --include "fonts/*"

      # Pass 3: HTML last. Uploading it before the assets it references
      # serves a page whose stylesheet 404s for the length of the other passes.
      - name: Sync HTML
        run: |
          aws s3 sync dist "s3://${{ vars.SITE_BUCKET }}" \
            --cache-control "public,max-age=0,must-revalidate" \
            --exclude "*" \
            --include "*.html"

      - name: Invalidate
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "${{ vars.SITE_DISTRIBUTION_ID }}" \
            --paths "/*"
```

Two more repository variables are needed:

```powershell
gh variable set SITE_BUCKET --body (terraform output -raw bucket_name) --repo philliam-nguyen/dev_site
gh variable set SITE_DISTRIBUTION_ID --body (terraform output -raw distribution_id) --repo philliam-nguyen/dev_site
```

Invalidating `/*` counts as **one path** against the 1,000 free paths a month,
not one per file. Listing individual paths would be cheaper in theory and is
strictly worse here: `/*` is one path, and enumerating changed files is both
more paths and a chance to miss one.

**Verify.**

Push a trivial change under `site/` and watch it:

```powershell
gh run watch --repo philliam-nguyen/dev_site
```

Then confirm the headers landed, which proves each pass hit the right files:

```powershell
aws s3api head-object --bucket $bucket --key index.html --query "CacheControl" --output text
```
Expected: `public,max-age=0,must-revalidate`

```powershell
aws s3api head-object --bucket $bucket --key favicon.svg --query "CacheControl" --output text
```
Expected: `public,max-age=86400` — the exclude worked.

```powershell
aws s3api list-objects-v2 --bucket $bucket --prefix "_astro/" --query "Contents[0].Key" --output text
$key = aws s3api list-objects-v2 --bucket $bucket --prefix "_astro/" --query "Contents[0].Key" --output text
aws s3api head-object --bucket $bucket --key $key --query "CacheControl" --output text
```
Expected: `public,max-age=31536000,immutable`

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" https://<domain>
```
Expected: `200`. That closes success criterion 3.

Also confirm no credential was stored: the workflow file contains no
`secrets.AWS_*`, and the repository has no AWS secret.

```powershell
gh secret list --repo philliam-nguyen/dev_site
```
Expected: no AWS entries.

---

## Unit 3.3: The local deploy script

**Trade-off brief.**

`scripts/deploy.ps1` runs the same three passes against a local admin profile.
It exists for the case where CI is down or a deploy needs to happen from the
laptop — and it introduces a duplication risk: two definitions of the deploy
that can drift.

Three ways to handle that:

1. **Accept the duplication**, keep the script short, and treat the workflow as
   authoritative. Simple, and drift is possible.
2. **Have the workflow call the script.** One definition, and it needs
   PowerShell on the runner (available on `ubuntu-latest` as `pwsh`, one more
   moving part).
3. **Skip the script**, deploy by hand when needed. No drift, and the
   three-pass ordering has to be remembered correctly under pressure — exactly
   when it will not be.

Option 1 is the spec's implied choice. The mitigation is a comment in both
files pointing at the other, so a change to one prompts a look at the other.

**Build.**

`scripts/deploy.ps1` taking bucket, distribution ID, and profile as parameters
with no hardcoded values, running build then the same three passes then the
invalidation.

**Compare.**

```powershell
<#
.SYNOPSIS
  Deploys site/dist to S3 and invalidates CloudFront, from a local AWS profile.

.DESCRIPTION
  The cache passes here mirror .github/workflows/deploy.yml. Change one,
  check the other.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Bucket,
    [Parameter(Mandatory)][string]$DistributionId,
    [string]$Profile = $env:AWS_PROFILE
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $repoRoot 'site')

try {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "build failed with exit code $LASTEXITCODE" }

    $common = @('--profile', $Profile)

    Write-Host 'Pass 1: hashed assets'
    aws s3 sync dist "s3://$Bucket" --delete `
        --cache-control 'public,max-age=31536000,immutable' `
        --exclude '*.html' --exclude 'favicon.svg' --exclude 'fonts/*' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 1 failed with exit code $LASTEXITCODE" }

    Write-Host 'Pass 2: unhashed assets'
    aws s3 sync dist "s3://$Bucket" `
        --cache-control 'public,max-age=86400' `
        --exclude '*' --include 'favicon.svg' --include 'fonts/*' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 2 failed with exit code $LASTEXITCODE" }

    Write-Host 'Pass 3: HTML'
    aws s3 sync dist "s3://$Bucket" `
        --cache-control 'public,max-age=0,must-revalidate' `
        --exclude '*' --include '*.html' @common
    if ($LASTEXITCODE -ne 0) { throw "pass 3 failed with exit code $LASTEXITCODE" }

    Write-Host 'Invalidating'
    aws cloudfront create-invalidation --distribution-id $DistributionId --paths '/*' @common
    if ($LASTEXITCODE -ne 0) { throw "invalidation failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
```

`$ErrorActionPreference = 'Stop'` does not catch native executable failures —
`aws` and `npm` are external programs, and a non-zero exit from them is not a
PowerShell error. The explicit `$LASTEXITCODE` check after each is what makes
this script fail loudly instead of reporting success after a failed upload.

**Verify.**

```powershell
./scripts/deploy.ps1 -Bucket $bucket -DistributionId $dist
```
Expected: four steps, no thrown error, and `head-object` still reports the
three different `CacheControl` values from Unit 3.2.

---

## Unit 3.4: Terraform static analysis in CI

**Trade-off brief.**

[[0002-github-oidc-deploy-identity]] draws the line: `fmt -check`, `validate`,
and a security scan need no credentials and no state, so they run on every
push. `plan` needs credentials and `apply` changes production, so both stay
local and manual.

`validate` needs `terraform init` to have run, and `init` with an S3 backend
needs credentials. `terraform init -backend=false` is the way around that: it
downloads providers and validates the configuration without touching remote
state.

**On the scanner, flagged as uncertain.** Spec 0001 names `tfsec`. Aqua
Security announced that tfsec is being folded into Trivy, with tfsec's
misconfiguration scanning available as `trivy config` and tfsec itself moving
to maintenance. **Verify the current status before choosing** — if tfsec is
still maintained, either works; if it is archived, `trivy config` is the
successor and the spec's mention should be treated as naming the capability
rather than the binary. This plan uses `trivy config` with that caveat stated.

**Decide.** Scanner, and whether a finding fails the build or only reports.
Failing the build is the stricter default and it means a scanner rule change
can block an unrelated push — an acceptable trade for a repo that changes
rarely.

**Build.**

`.github/workflows/terraform.yml`, triggered on changes under `infra/`.

**Compare.**

```yaml
name: terraform

on:
  push:
    paths:
      - 'infra/**'
      - '.github/workflows/terraform.yml'
  pull_request:
    paths:
      - 'infra/**'

jobs:
  static-analysis:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.10.0'

      - name: Format check
        run: terraform fmt -check -recursive infra/

      # -backend=false is what lets validate run without credentials: it
      # installs providers and checks the configuration without touching
      # remote state.
      - name: Validate each module
        run: |
          for dir in infra/bootstrap infra/platform infra/modules/static-site infra/stacks/portfolio; do
            echo "== $dir"
            terraform -chdir="$dir" init -backend=false
            terraform -chdir="$dir" validate
          done

      - name: Security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: infra/
          exit-code: '1'
          severity: 'HIGH,CRITICAL'
```

Pinning `trivy-action@master` contradicts the pinning discipline in this plan.
Pin it to a release tag; `master` is written here only because the correct tag
has to be looked up:

```powershell
gh api repos/aquasecurity/trivy-action/releases/latest --jq .tag_name
```

**Verify.**

```powershell
terraform fmt -check -recursive infra/
```
Expected: no output, exit 0. Any output names files to run `terraform fmt` on.

Push and confirm the workflow passes:

```powershell
gh run watch --repo philliam-nguyen/dev_site
```

Expect the scanner to flag things on the first run. Each finding gets a ruling:
fixed, or documented as accepted with a reason. Likely candidates — no S3
access logging on the site bucket, no KMS encryption on either bucket, no WAF
on the distribution. Each is a defensible "accepted" on a personal static site,
and the reason has to be written down rather than assumed.

**Commit.**

```bash
git add .github/workflows/ scripts/ site/astro.config.mjs
git commit -m "Deploy path: OIDC workflow, local script, Terraform static analysis

Three cache passes rather than two. favicon.svg and fonts/anton.woff2 keep
stable filenames, so the immutable pass would strand visitors on a stale
copy for a year and no invalidation reaches a browser cache. HTML stays
last so it never references assets that have not landed.

inlineStylesheets pinned to 'never' so the CSP's style-src 'self' cannot be
invalidated by the stylesheet shrinking below Astro's inline threshold.

Implements ADR-0002."
```

---

## Quiz 3

1. A GitHub workflow in a fork of this repository runs on a pull request and
   tries to assume the deploy role. Trace what happens and name the exact
   condition that stops it.
2. The role ARN is a repository variable, readable by anyone. Why is that not a
   credential leak?
3. Why does HTML go last? Describe what a visitor sees if the order is reversed.
4. Why three cache passes and not two? Which files are in the middle pass, and
   what is the failure the middle pass prevents?
5. `--delete` is only on the first pass. What does that miss, and why is it
   acceptable here?
6. `cancel-in-progress: false`. What goes wrong with `true`?
7. Invalidation uses `/*`. Why is that one path against the free tier, and why
   not enumerate the changed files?
8. Why can `terraform validate` run in CI while `terraform plan` cannot?
9. The workflow assumes a role. Where did the credential come from, and how
   long does it live?

### Answer key

1. `configure-aws-credentials` requests an OIDC token from GitHub. For a fork
   pull request the token's `sub` claim is `repo:<fork-owner>/<repo>:pull_request`
   or similar — not `repo:philliam-nguyen/dev_site:ref:refs/heads/main`. The
   trust policy's `StringEquals` on `token.actions.githubusercontent.com:sub`
   does not match, `AssumeRoleWithWebIdentity` returns `AccessDenied`, and no
   credential is issued. On top of that, GitHub does not grant `id-token: write`
   to fork pull requests by default, so the token request itself fails first.
2. An ARN is an identifier, not a secret. Assuming a role requires satisfying
   its trust policy, and this one requires a token signed by GitHub's OIDC
   issuer carrying an exact subject claim. Knowing the ARN gets an attacker
   nothing they could not have learned from a CloudTrail-less guess.
3. Assets first means the HTML being served is still the previous version, and
   the assets it references are still present because `--delete` has already
   run against the new set — the old ones are gone only if the new HTML that
   references them is also going up. Reversed, the new HTML lands first and
   references hashed filenames that have not been uploaded yet, so every
   visitor in that window gets an unstyled page with a 404 stylesheet.
4. Because two assets are not content-hashed: `favicon.svg` and
   `fonts/anton.woff2`. The immutable pass would give them `max-age=31536000`,
   so changing the font would leave returning visitors on the old one for up to
   a year, and a CloudFront invalidation cannot clear a browser cache. The
   middle pass gives them a one-day TTL instead.
5. Stale HTML. The first pass excludes `*.html`, so a removed page would remain
   in the bucket and remain reachable. This is a single-page site, so there is
   one HTML file that is always overwritten. It becomes a real problem the
   moment a second page is added and later removed.
6. A cancelled run can be killed between sync passes — for example after the
   asset pass and before the HTML pass, or worse, partway through `--delete`.
   The bucket is left in a mixed state with no automatic recovery. Queuing
   means the second push waits and then overwrites cleanly.
7. CloudFront bills invalidation by path *entry* submitted, not by object
   matched, and `/*` is one entry. Enumerating changed files submits one entry
   per file, which is both more entries against the 1,000 free monthly paths
   and a chance to omit a file that actually changed.
8. `validate` checks syntax, types, and internal references using only the
   configuration and the provider schemas, and `-backend=false` skips remote
   state entirely — no credentials needed. `plan` has to read remote state and
   query AWS for the current state of every resource, which requires
   credentials, and issuing CI credentials capable of reading all infrastructure
   state is a much larger grant than the deploy role.
9. From STS, via `AssumeRoleWithWebIdentity`, in exchange for a short-lived
   OIDC token GitHub minted for that specific workflow run. The returned
   credential defaults to one hour and exists only in the runner's environment
   for the life of the job. Nothing is stored in the repository, in AWS, or on
   any machine.

---

## Definition of done

Every box above is checked and every quiz answered. Then, against the live
site:

| # | Success criterion | Check | Expected |
|---|---|---|---|
| 1 | HTTPS with HSTS | `curl.exe -sI https://<domain>` | 200, `strict-transport-security` present |
| 2 | S3 URL denied | `curl.exe -s -o NUL -w "%{http_code}" https://<bucket>.s3.amazonaws.com/index.html` | `403` |
| 3 | Push deploys, no stored credential | `gh run list --workflow deploy.yml` plus `gh secret list` | latest run success, no AWS secrets |
| 4 | One markdown file, one card | Add a project file, push | one new card, no other edit |
| 5 | Skeleton reads unfinished | Visual, closed 2026-07-31 | already met |
| 6 | Light and dark pass axe | `npm run test:a11y` | 3 passing |
| 7 | No JavaScript | same suite | passing |
| 8 | Clean plan | `terraform plan -detailed-exitcode` in all three stacks | exit `0` |

Criteria 4 through 7 were met by the site build. Criteria 1, 2, 3, and 8 are
this plan's deliverable.

Also confirm, because they are easy to leave undone:

- `terraform fmt -check -recursive infra/` is clean.
- Every `.terraform.lock.hcl` is committed.
- No `terraform.tfstate` is committed: `git ls-files | Select-String tfstate`
  returns nothing.
- No `.tfvars` is committed, only `.tfvars.example`.
- The scanner's findings each have a ruling written down.
- `docs/progress.md` is updated: current status, what is done, what is next.
  The remaining "next" item after this plan is the other projects.
- The root README open question in progress.md is now answerable, since
  `infra/` exists and there are two things to describe together.

---

## Decision log

Fill this in during the sessions. One line per decision, in the words used to
justify it out loud. This is the artifact that makes the infrastructure
explainable months later, and it is worth more than the HCL.

| Unit | Decision | Rejected | Why |
|---|---|---|---|
| 1.1 | | | |
| 1.2 | | | |
| 1.3 | | | |
| 1.4 | Data source for the zone; one certificate with apex plus `*.apex` SAN; `allow_overwrite = true` on the validation records | Zone as a resource; per-subdomain certificates; deduplicating the `for_each` on `resource_record_name` | `allow_overwrite` makes any second write idempotent and allows re-applying the certificate after a replacement |
| 1.5 | Omit `thumbprint_list` from `aws_iam_openid_connect_provider` | Hardcoding the well-known fingerprint; reading it at plan time with `data "tls_certificate"` | It is not required anymore, because IAM verifies the TLS certificate against its own trust library |
| 1.6 | `$5` monthly limit with both notifications: `ACTUAL` at 80% and `FORECASTED` at 100% | CloudFront access logs; CloudWatch alarms on CloudFront metrics; a single notification type | $5 is a cheap anomaly detector against a real bill of roughly $0.50, and `FORECASTED` gives early warning that `ACTUAL` alone would not |
| 2.1 | | | |
| 2.2 | | | |
| 2.3 | | | |
| 2.4 | | | |
| 2.5 | | | |
| 2.6 | | | |
| 2.7 | | | |
| 3.1 | | | |
| 3.2 | | | |
| 3.3 | | | |
| 3.4 | | | |

Any decision here that diverges from spec 0001 or an ADR needs the document
amended, not just this table filled in. A decision log that contradicts the
spec is how the spec stops being authoritative.

---

## Deviations from this plan's own advice, stated up front

- **Reference implementations appear inline**, after the build requirements
  rather than before. Withholding them entirely would make the plan unusable
  cold in six months; showing them first would make the sessions transcription.
  Read the brief, decide, write, then compare.
- **Version numbers in this plan are not authoritative.** Provider majors and
  action tags move, and the site build's most common plan-originated defect was
  a stale pin. Every version has a lookup command next to it. Use the lookup.
- **Two claims are flagged as unverified**: the current role of the OIDC
  thumbprint in IAM's verification path (Unit 1.5), and tfsec's maintenance
  status relative to Trivy (Unit 3.4). Both are stated as needing a check
  because both are the kind of detail that gets repeated confidently and turns
  out to be a year out of date.
