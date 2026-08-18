# Progress

Living state for the developer site. Update this rather than reading git
archaeology. Current as of 2026-08-07. Last commit on `main` is `567e20d`
(bootstrap state bucket). Uncommitted: this file, the amended curriculum plan,
the stale HTML artifact, and an untracked `infra/platform/`.

## Do this first, next session

**Regenerate `docs/html_artifacts/2026-08-06-infra-curriculum.html`.** It was
already modified and uncommitted before 2026-08-07, and the source markdown has
since changed underneath it: Unit 1.5's trade-off brief was rewritten, its build
steps and reference config were changed, its verify section gained two commands,
and decision-log rows 1.4 through 1.6 were filled in. The generation method is
not recorded anywhere. Find it, note it here, then regenerate.

**Commit `infra/platform/`** if it is still untracked. The message the plan
specifies is at the end of Unit 1.6, plus a paragraph on the thumbprint
decision. `git add infra/platform/` stages only the `.tf` files,
`terraform.tfvars.example`, and `.terraform.lock.hcl`; the real
`terraform.tfvars` and `.terraform/` are both gitignored, verified 2026-08-07.

**Re-apply `infra/platform/` with the raised budget.** Added 2026-08-17.
`monthly_budget_usd` went from `"5"` to `"15"` in `variables.tf` and in the real
`terraform.tfvars`, because the recipe app's Demo Variant adds $7.36 a month of
standing cost and $5 would leave both notifications permanently fired. The
reasoning and the price breakdown are in [[0003-terraform-topology]]'s
2026-08-17 amendment. Nothing has been applied, so `platform/` currently has a
pending diff of exactly one attribute. Do this before `stacks/recipe/`, not
alongside it.

## Current status

The Astro site is built, reviewed, merged, and pushed. **It is not deployed and
not reachable by anyone.**

Spec 0001 covers two halves: the site, and the AWS infrastructure that serves it.
The site half is done. The infrastructure half is now under way: Session 1 of
the curriculum is complete, which means the state bucket, the certificate, the
OIDC provider, and the budget alarm all exist. There is still no distribution,
no bucket for the site itself, and no deploy workflow.

Of the spec's eight success criteria, 4 through 7 are met. Criteria 1, 2, 3, and
8 all describe a deployed site and remain unmet. Sessions 2 and 3 close them.

## Done

- Spec 0001 and ADRs 0001 through 0004, from the brainstorm
- Plan `2026-07-29-site-build`, ten tasks, executed with a review after each
- The site under `site/`: content collections, components, the token port, the
  responsive breakpoint, and the axe suite
- A whole-branch review and one fix wave clearing its findings
- Merged to `main` and pushed to `github.com/philliam-nguyen/dev_site`

Verified on the merged tree: `astro check` clean, vitest 4/4, axe passing in both
color schemes, zero JavaScript in the build.

**Visual acceptance closed 2026-07-31** against `mockups/built-light.png` and
`built-dark.png`, both rendered from the merged build. This was the last
outstanding Definition-of-Done item. Four things were reviewed and accepted as
deliberate rather than fixed, so they should not be re-raised as defects:

- Stub cards carry a `2026` year chip; the approved mockup showed only a stack
  chip.
- Stub thumbnails carry an `01` / `02` index; the mockup had those on populated
  cards only.
- The About stub renders real prose explaining how to replace it, where the
  mockup showed filler bars.
- In light mode the accent reads two-tone: `--accent-text` (`#a8430e`) on the
  eyebrow and kicker text sits beside `--accent` (`#e8611c`) on the chevrons and
  the wordmark period. This is the known cost of the contrast split in ADR 0004.
  Dark uses `#f6832f` for both and shows no split.

**The infrastructure curriculum plan is written**, at
`docs/plans/2026-08-06-infra-curriculum.md`. Three sessions, seventeen build
units, a quiz per session with an answer key, and a decision log to fill in
while building.

**ADR 0003 gained an amendment on 2026-08-06** fixing where the domain name
lives: `platform/` declares it as a variable and re-exports it as an output, and
app stacks read it from `terraform_remote_state` rather than each holding a copy.

### Session 1 of the curriculum, complete 2026-08-07

All six units built, applied, and verified. Both blocking prerequisites closed
first: Terraform 1.15.8, aws-cli 2.36.17, `gh` authenticated as
`philliam-nguyen` over SSH.

- **1.1** `.gitignore` stops ignoring `.terraform.lock.hcl`. Both
  `git check-ignore` checks pass. Committed.
- **1.2** `infra/bootstrap/versions.tf`. The five defects recorded in the
  previous version of this file are all fixed: `required_version = ">= 1.10.0"`
  (the CLI constraint, and 1.10 is where `use_lockfile` starts existing), the
  `aws = {` attribute form, singular `version`, and the file moved from
  `infra/` to `infra/bootstrap/`.
- **1.3** `infra/bootstrap/main.tf`, applied with local state per ADR 0003.
  State bucket is `tf-state-975050064267-us-east-1`, versioned, `AES256`, all
  four public-access-block flags true, `prevent_destroy` on the bucket.
  Committed as `567e20d`.
- **1.4** `infra/platform/` created and applied. Zone read as a data source,
  one ACM certificate covering the apex and `*.apex`, validation records with
  `allow_overwrite = true`, and the wait resource. Certificate is `ISSUED`.
- **1.5** `aws_iam_openid_connect_provider` for GitHub Actions, with
  `client_id_list = ["sts.amazonaws.com"]` and **no `thumbprint_list`**.
- **1.6** `aws_budgets_budget` at $5 monthly with both an `ACTUAL` 80% and a
  `FORECASTED` 100% notification to `budget_email`. Raised to $15 on 2026-08-17
  and not yet applied; see the top of this file.

`terraform plan -detailed-exitcode` returns 0 on both `bootstrap/` and
`platform/`, and `terraform fmt -check` is clean on both. **True as of
2026-08-07 only:** the 2026-08-17 budget raise means `platform/` now returns 2
until it is re-applied.

**Decision-log rows 1.4, 1.5, and 1.6 are filled in. Rows 1.1, 1.2, and 1.3 are
still blank** and should be backfilled from the notes above.

## In progress

Nothing mid-flight. Session 1 closed cleanly. Quiz 1 in the plan has not been
worked through; the session ran hands-on instead of quiz-first by request.

## Next

1. **Regenerate the HTML artifact and commit `infra/platform/`.** See the top of
   this file.
2. **Session 2**: the `static-site` module and the portfolio stack. Then
   **Session 3**: the GitHub Actions deploy path. The plan is author-built with
   coaching per spec 0001's implementation split, so it must not be dispatched
   to subagents.
3. **Then the other projects.** The recipe app and the two capstones each get
   their own brainstorm, spec, and plan. The RAG system links to its repository
   and needs no infrastructure.

## Open questions

- **Root `README`?** The repository landing page is currently blank.
  `site/README.md` covers the commands and the content model, but a root README
  would want to describe `site/` and `infra/` together. Now that `infra/`
  exists, this is worth doing.
- **How is the HTML artifact generated?** Not recorded anywhere. Blocks the
  first item under "Do this first".
- **Does ADR 0005 come back?** It was dropped on the premise that nothing public
  needs compute, and the 2026-08-17 correction to spec 0001 breaks that premise.
  The compute is a proxy instance in AWS rather than the home server the draft
  was about, so the answer is not obvious. Settle it in the recipe app's
  brainstorm.

## State the next phase depends on

- **The domain is `phillip-nguyen.dev`**, registered through Route 53 on
  2026-08-07 so the hosted zone was created with it. Hosted zone
  `Z10293412YBU8AYXC0SF0`, account `975050064267`. This is `var.domain_name` in
  `platform/`, and app stacks read it back from the platform output rather than
  declaring copies, per the ADR 0003 amendment.
- **`platform/` now publishes four outputs**, and per ADR 0003 changing any of
  them is a breaking change for every app stack:
  - `zone_id` = `Z10293412YBU8AYXC0SF0`
  - `domain_name` = `phillip-nguyen.dev`
  - `certificate_arn` = `arn:aws:acm:us-east-1:975050064267:certificate/0019c868-7bf0-4db6-8b63-acd6eeb9e657`
  - `oidc_provider_arn` = `arn:aws:iam::975050064267:oidc-provider/token.actions.githubusercontent.com`

  `certificate_arn` is sourced from `aws_acm_certificate_validation`, not from
  the certificate resource. Same string, but reading it there means a consumer
  cannot attach a certificate ACM has not issued yet. Session 2's distribution
  must consume the output, not the certificate directly.
- **The state bucket is `tf-state-975050064267-us-east-1`.** Backend blocks
  cannot interpolate, so every new stack hardcodes that literal and sets its own
  `key`. `platform/` uses `platform/terraform.tfstate`. Locking is
  `use_lockfile = true`, S3-native, no DynamoDB table.
- **`bootstrap/terraform.tfstate` is on this laptop only**, per ADR 0003. If the
  laptop dies the bucket survives (`prevent_destroy`, nothing else manages it)
  and recovery is `terraform import` on a fresh clone, not a rebuild.
- **The local AWS credential was replaced on 2026-08-07.** Profile `phil`
  (region `us-east-1`) backs `arn:aws:iam::975050064267:user/dev-site-admin`,
  created for this project and tagged `Project=dev-site`,
  `Purpose=local-terraform-apply`. It carries `AdministratorAccess` and is the
  only admin principal in the account. It exists solely for `terraform apply`
  from the laptop; the deploy path in Sessions 2 and 3 uses OIDC and never
  touches it. There is no `default` profile, so `AWS_PROFILE=phil` must be set
  or commands fail with "No valid credential sources found". The previous
  credential, `terraform-tester`, was an unrelated admin user left over from a
  2025 lesson with a 16-month-old access key of unknown provenance. Its key was
  deleted, its policy detached, and the user removed. A backup of the old
  credentials file sits at `~/.aws/credentials.bak.20260807` and holds the
  now-dead secret; **delete it.** IAM Identity Center is not enabled in this
  account and remains the better endpoint once the first applies are done.
- **The old lesson left no infrastructure behind.** No CloudFront
  distributions, no customer-managed IAM roles, no state buckets. One unrelated
  leftover remains and was deliberately left alone: `pinpix-user` and
  `pinpix-bucket` from 2024, scoped to a single-bucket policy.
- **`.dev` is HSTS-preloaded at the TLD level**, which sharpens Unit 2.3's
  `preload = false` decision: submission to the preload list is redundant
  because browsers already force HTTPS on every `.dev` host. The
  `strict_transport_security` block still carries `max-age` and
  `includeSubDomains`. Confirm against the current preload list before
  repeating the claim.
- **The OIDC trust policy value is fixed** by the repository name:
  `repo:philliam-nguyen/dev_site:ref:refs/heads/main`. Renaming the repo breaks
  deploys until Terraform is re-applied. The provider accepts the audience
  (`sts.amazonaws.com`); the role's trust policy is what constrains repo and
  branch, and that is built in Session 2.
- **Four build outputs are inputs to the Terraform work.** They live in spec
  0001 under "Carried into the Terraform plan": two unhashed assets that will
  land in the immutable cache pass, `build.inlineStylesheets` needing a pin
  before the CSP is written, `npx playwright install chromium` as a workflow
  step `npm ci` will not cover, and the placeholder `site` URL in
  `astro.config.mjs`. All four are resolved in the plan, at Units 2.3 and 3.2.
- **Node 22.12 or newer**, required by Astro 7. The CI runner needs it too.
- **The remote uses an SSH host alias**, `git@github-personal:...`, not
  `github.com`. A pasted HTTPS URL will fail with `Permission denied`.

## Where the plan diverges from spec 0001

Amend the spec when each one lands, rather than leaving the spec and the plan
disagreeing.

- **Three cache passes, not two.** The spec's two-pass sync gives `favicon.svg`
  and `fonts/anton.woff2` a year-long `immutable` header, and both keep stable
  filenames. Changing the font would strand returning visitors on the old one,
  and a CloudFront invalidation cannot reach a browser cache. The middle pass
  gives those two a one-day TTL.
- **`.gitignore` stops ignoring `.terraform.lock.hcl`.** The committed lock file
  is what makes a provider pin reproducible across the laptop and CI. Unit 1.1,
  done.
- **The scanner may be Trivy rather than tfsec.** The spec names tfsec, and
  tfsec is being folded into Trivy. Unit 3.4 flags this as needing a check
  before the choice is made.

## Where the build diverged from the plan

- **Unit 1.5 drops `thumbprint_list` entirely.** The plan offered two options,
  hardcoding the fingerprint or reading it at plan time with
  `data "tls_certificate"`, and flagged as unverified the claim that the API
  still requires the field. **Verified 2026-08-07: that claim was wrong.** IAM
  verifies the OIDC endpoint's TLS certificate against its own library of
  trusted root CAs and consults the thumbprint only as a fallback, for issuers
  outside that library, when the certificate cannot be retrieved, or when TLS
  1.3 is required. GitHub's issuer is covered, so the value has no consumer.
  `CreateOpenIDConnectProvider` treats it as optional, and the AWS provider
  declares it `Optional: true, Computed: true`, so omitting it stores AWS's
  derived value rather than leaving a permanent diff. Confirmed in practice:
  `length(ThumbprintList)` returns 1 with nothing supplied, and
  `plan -detailed-exitcode` still returns 0. The plan's Unit 1.5 has been
  rewritten to match, and the `hashicorp/tls` provider is never added.

**One plan claim remains unverified on purpose**: tfsec's maintenance status,
which Unit 3.4 depends on. Confirm before repeating it. The other flagged claim,
the OIDC thumbprint, is resolved above.

## Carried into the recipe stack

Not in scope for Sessions 2 or 3. Recorded here because both bind whoever writes
the Terraform for `stacks/recipe/`, and both are the kind of default that reads
fine in a plan and fails in a browser.

- **us-east-1 excludes `use1-az3` from VPC origins.** It is the same zone already
  excluded from RDS Proxy. Subnet placement has to avoid it, and zone *names* are
  shuffled per account while zone *IDs* are not, so check the mapping with
  `aws ec2 describe-availability-zones` rather than trusting the letter.
- **CloudFront's origin retry defaults defeat the degraded mode.** Three attempts
  at a ten-second timeout means a dead origin costs a visitor up to thirty
  seconds before anything renders. The entire point of degrading to the static
  bundle is that the page still arrives, so `connection_attempts` and
  `connection_timeout` both come down on the `/api/*` behaviour.

The Demo Variant's other open items, the Tailscale policy file and recipe ticket
20 on whether a VPC origin serves an instance in a public subnet, belong in that
app's own brainstorm and spec rather than here.

## Worth carrying into the infrastructure sessions

Six defects in the site build came from the plan rather than from the
implementation: stale version pins, a texture color invisible on its own
background, a component interface rigid enough that callers duplicated markup, a
guard that hid the thing it guarded, a contrast value verified against one
surface but used on three, and a documentation fact amended in one place but not
its copy.

Every one surfaced when something concrete got built and a fresh reader compared
it against the requirement. The infrastructure checkpoints therefore lean on
checks that emit a status code or a number.

Session 1 bore this out twice. The Unit 1.5 thumbprint claim was a plan defect
that only a documentation check caught, and the duplicate validation record in
Unit 1.4 showed up as two `for_each` instances sharing one resource ID in the
refresh output, which is the concrete form of the collision `allow_overwrite`
prevents.

## Open question the plan raises

**`docs/plans/2026-08-06-infra-curriculum.md` existed as an untracked path
before the 2026-08-06 session's write.** If it held content, that content is
gone and git never had a copy. Confirm whether it was an empty placeholder
before treating the current file as complete.
