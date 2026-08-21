# Progress

Living state for the developer site. Update this rather than reading git
archaeology. Current as of 2026-08-21. Last commit on `main` is `a796ebe`
(recipe stack demo variant terraform); this docs pass is uncommitted on top of
it.

## Do this first, next session

**Delete `~/.aws/credentials.bak.20260807`.** It holds the dead
`terraform-tester` secret (verified 2026-08-21: the file differs from the live
credentials, so it is the backup, not the active profile). An assistant attempt
to delete it was blocked by the permission classifier, so it has to be removed
by hand: `rm ~/.aws/credentials.bak.20260807`.

**Push and tidy the recipe repo.** `../recipe_site` has its `main` one commit
ahead of origin (the whole ticket-25 runbook section), and a seven-item
doc-consistency backlog sitting in its gitignored `.scratch/doc-consistency/`,
invisible to anyone reading the committed docs. That work belongs to that repo's
own session; recorded here so it is not forgotten.

## Current status

**The recipe app's Demo Variant is live at
`https://meal-prep.phillip-nguyen.dev` and the portfolio site is not deployed.**
The second project shipped before the first. The Astro site is built, reviewed,
merged, and pushed, but nothing serves it: `https://phillip-nguyen.dev` does not
answer.

All three Terraform roots are applied and clean. Verified 2026-08-21:
`terraform plan -detailed-exitcode` returns 0 on `platform/` (so the $15 budget
raise from 2026-08-17 has been applied) and on `stacks/recipe/`. The full demo
path works end to end: `GET /api/state` returns 200 in under half a second,
which means CloudFront → VPC origin → EC2 proxy → Tailscale → homelab Postgres
is all up, and the degraded mode has been observed to kick in when the homelab
is down.

Of spec 0001's eight success criteria, 4 through 7 are met, and 8 is now met
for the stacks that exist. Criteria 1, 2, and 3 describe the deployed portfolio
site and remain unmet. Sessions 2 and 3 of the curriculum close them.

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
`docs/plans/2026-08-06-infra-curriculum.md`, and carries a 2026-08-21 amendment
reconciling it with the recipe stack having shipped first.

**ADR 0003 gained an amendment on 2026-08-06** fixing where the domain name
lives, and another on 2026-08-17 raising the budget to $15.

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
- **1.6** `aws_budgets_budget` monthly with both an `ACTUAL` 80% and a
  `FORECASTED` 100% notification to `budget_email`. Originally $5; raised to
  $15 on 2026-08-17 and applied (verified 2026-08-21).

**Decision-log rows 1.4, 1.5, and 1.6 are filled in. Rows 1.1 through 1.3 are
blank and stay blank for now**: the per-unit decision log has been retired in
favor of a retrospective exercise. See "Next".

### The recipe stack, shipped 2026-08-21

`infra/stacks/recipe/` was written and applied outside the curriculum, ahead of
Sessions 2 and 3, and is live. It is standalone HCL, not a `static-site` module
consumer. What it provisions: a VPC with one public subnet (AZ pinned by ID to
avoid `use1-az3`), a `t4g.nano` AL2023 arm64 proxy instance running nginx plus
`tailscaled`, a CloudFront distribution with two origins (S3 for the bundle, a
VPC origin at the instance for `/api/*`), the frontend bucket behind OAC, DNS,
and the `meal-prep-deploy` OIDC role.

The app itself lives in `../recipe_site` (GitHub:
`philliam-nguyen/meal-prep-app`) with its own spec, eleven ADRs, two research
docs, and a runbook. Its backend and Postgres run on the homelab and are reached
over Tailscale; the AWS footprint is only the ingress. Standing cost is
$7.37/month, which is what drove the budget raise. See
`infra/stacks/recipe/README.md` for the split of responsibilities and the CI
contract between the two repos.

Two carry-forward items recorded here earlier are closed and honored in the
shipped stack: `use1-az3` is avoided, and the CloudFront retry defaults are
lowered on the `/api/*` behaviour (plus 2–3s upstream timeouts in nginx) so a
dead homelab degrades in seconds, not thirty. The two items deferred to the
app's own process are also settled there: the Tailscale policy file exists and
is versioned at `recipe_site/ops/tailnet/policy.hujson`, and recipe ticket 20
(a CloudFront VPC origin serving an instance in a public subnet) was tested
live on 2026-08-18 and works, with no certificate needed on the instance.

## In progress

A docs reconciliation pass, 2026-08-21: this file, the curriculum plan
amendment, the spec 0001 amendment, the root `README.md`, and
`infra/stacks/recipe/README.md`. The stale HTML artifact
`docs/html_artifacts/2026-08-06-infra-curriculum.html` and
`docs/specs/0001-developer-site.html` were both deleted rather than
regenerated: neither had a recorded generation method, and the markdown is the
source of truth.

## Next

1. **Session 2**: the `static-site` module and the portfolio stack. Then
   **Session 3**: the GitHub Actions deploy path. Both still author-built with
   coaching per spec 0001's implementation split, so they must not be dispatched
   to subagents. Read them against the shipped recipe stack as a reference
   implementation; the plan's 2026-08-21 amendment says how.
2. **The decision-log retrospective.** The fill-in-as-you-go log did not work.
   Replacement: a dedicated session walking through the reasoning behind what
   was actually built (Session 1's units and the recipe stack), where the
   author writes the entries themselves with the assistant as coach. Rows 1.1
   through 1.3 and the $15 rationale get written then.
3. **The recipe repo's own docs pass**: push the unpushed commit, work the
   seven-item consistency backlog. Separate session, that repo.
4. **Then the other projects.** The RAG system links to its repository and
   needs no infrastructure. The capstones each get their own brainstorm, spec,
   and plan.

## Open questions

- ~~Root README?~~ Written 2026-08-21.
- ~~How is the HTML artifact generated?~~ Never recorded; the artifact was
  deleted 2026-08-21 instead of regenerated.
- ~~Does ADR 0005 come back?~~ No. The compute decision has its own record in
  the recipe repo (ADR 0008, demo backend on the homelab, plus research doc
  0002 on the ingress). Spec 0001's scope note and the curriculum amendment
  point there; a main_site ADR would duplicate it.

## State the next phase depends on

- **The domain is `phillip-nguyen.dev`**, registered through Route 53 on
  2026-08-07 so the hosted zone was created with it. Hosted zone
  `Z10293412YBU8AYXC0SF0`, account `975050064267`. This is `var.domain_name` in
  `platform/`, and app stacks read it back from the platform output rather than
  declaring copies, per the ADR 0003 amendment.
- **`platform/` publishes four outputs**, and per ADR 0003 changing any of
  them is a breaking change for every app stack. `stacks/recipe/` now consumes
  them in anger, so this is no longer theoretical:
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
- **The local AWS credential is profile `phil`** (region `us-east-1`), backing
  `arn:aws:iam::975050064267:user/dev-site-admin`, created for this project and
  tagged `Project=dev-site`, `Purpose=local-terraform-apply`. It carries
  `AdministratorAccess` and is the only admin principal in the account. It
  exists solely for `terraform apply` from the laptop; the deploy paths use
  OIDC and never touch it. There is no `default` profile, so `AWS_PROFILE=phil`
  must be set or commands fail with "No valid credential sources found". The
  predecessor `terraform-tester` user was removed 2026-08-07; the backup file
  holding its dead secret still needs deleting (see the top of this file). IAM
  Identity Center is not enabled in this account and remains the better
  endpoint now that the first applies are done.
- **The old lesson left no infrastructure behind.** One unrelated leftover
  remains and was deliberately left alone: `pinpix-user` and `pinpix-bucket`
  from 2024, scoped to a single-bucket policy.
- **`.dev` is HSTS-preloaded at the TLD level**, which sharpens Unit 2.3's
  `preload = false` decision: submission to the preload list is redundant
  because browsers already force HTTPS on every `.dev` host. The
  `strict_transport_security` block still carries `max-age` and
  `includeSubDomains`. Confirm against the current preload list before
  repeating the claim.
- **The OIDC trust policy value is fixed** by the repository name:
  `repo:philliam-nguyen/dev_site:ref:refs/heads/main` for the portfolio deploy
  role built in Session 2. The live example to crib from is
  `stacks/recipe/deploy.tf`, whose subject is
  `repo:philliam-nguyen/meal-prep-app:ref:refs/heads/main`. Renaming either
  repo breaks its deploys until Terraform is re-applied.
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

**One plan claim remains unverified on purpose**: tfsec's maintenance status,
which Unit 3.4 depends on. Confirm before repeating it.

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

The recipe project bore it out a third time, at larger scale: its docs repo
accumulated seven consistency defects between what the ADRs said and what
actually shipped, all catalogued but none yet fixed. The lesson generalizes:
docs written before the build go stale the moment the build teaches you
something, and the fix is a reconciliation pass, not better foresight.

## Open question the plan raises

**`docs/plans/2026-08-06-infra-curriculum.md` existed as an untracked path
before the 2026-08-06 session's write.** If it held content, that content is
gone and git never had a copy. Confirm whether it was an empty placeholder
before treating the current file as complete.
