# Progress

Living state for the developer site. Update this rather than reading git
archaeology. Current as of 2026-08-07. Last commit on `main` is `d7348b8`; the
infrastructure plan, the ADR 0003 amendment, and this file are uncommitted.

## Current status

The Astro site is built, reviewed, merged, and pushed. **It is not deployed and
not reachable by anyone.**

Spec 0001 covers two halves: the site, and the AWS infrastructure that serves it.
The site half is done. The infrastructure half is now planned but not built.
There is no `infra/` directory, no state bucket, no distribution, and no deploy
workflow.

Of the spec's eight success criteria, 4 through 7 are met. Criteria 1, 2, 3, and
8 all describe a deployed site and are unmet by definition. Closing them is what
the infrastructure plan does.

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
while building. Every unit runs the same five beats: trade-off brief, decide and
say the reason out loud, build from requirements, compare against a reference
implementation, then verify with a command that emits a status code or a number.

**ADR 0003 gained an amendment on 2026-08-06** fixing where the domain name
lives: `platform/` declares it as a variable and re-exports it as an output, and
app stacks read it from `terraform_remote_state` rather than each holding a copy.

## In progress

No branch is open, and the working tree is not clean. Uncommitted: this file,
the ADR 0003 amendment, the infrastructure plan, and a `.gitignore` line
ignoring `docs/html_artifacts`.

## Next

1. **Install Terraform and the AWS CLI, then configure a named profile.**
   Neither binary is installed and no `~/.aws` exists, so blocking
   prerequisite 2 is still open and no `terraform apply` can run. The domain
   half of the block is closed. Unit 1.1 is done in the working tree and
   wants its decision-log row and a commit.
2. **Run the three sessions** in `docs/plans/2026-08-06-infra-curriculum.md`:
   state and platform, then the `static-site` module and the portfolio stack,
   then the GitHub Actions deploy path. The plan is author-built with coaching
   per spec 0001's implementation split, so it must not be dispatched to
   subagents.
3. **Then the other projects.** The recipe app and the two capstones each get
   their own brainstorm, spec, and plan. The RAG system links to its repository
   and needs no infrastructure.

## Open questions

- **Root `README`?** The repository landing page is currently blank.
  `site/README.md` covers the commands and the content model, but a root README
  would want to describe `site/` and `infra/` together, which reads better once
  the second one exists.

## State the next phase depends on

- **The domain is `phillip-nguyen.dev`**, registered through Route 53 on
  2026-08-07 so the hosted zone was created with it. This is `var.domain_name`
  in `platform/`, and app stacks read it back from the platform output rather
  than declaring copies, per the ADR 0003 amendment. The hosted zone still
  needs confirming with `aws route53 list-hosted-zones-by-name` once the AWS
  CLI is installed.
- **`.dev` is HSTS-preloaded at the TLD level**, which sharpens Unit 2.3's
  `preload = false` decision: submission to the preload list is redundant
  because browsers already force HTTPS on every `.dev` host. The
  `strict_transport_security` block still carries `max-age` and
  `includeSubDomains`. Confirm against the current preload list before
  repeating the claim.
- **The OIDC trust policy value is fixed** by the repository name:
  `repo:philliam-nguyen/dev_site:ref:refs/heads/main`. Renaming the repo breaks
  deploys until Terraform is re-applied.
- **Four build outputs are inputs to the Terraform work.** They live in spec
  0001 under "Carried into the Terraform plan": two unhashed assets that will
  land in the immutable cache pass, `build.inlineStylesheets` needing a pin
  before the CSP is written, `npx playwright install chromium` as a workflow
  step `npm ci` will not cover, and the placeholder `site` URL in
  `astro.config.mjs`. All four are now resolved in the plan, at Units 2.3 and
  3.2.
- **Node 22.12 or newer**, required by Astro 7. The CI runner needs it too.
- **The remote uses an SSH host alias**, `git@github-personal:...`, not
  `github.com`. A pasted HTTPS URL will fail with `Permission denied`.

## Where the plan diverges from spec 0001

Three points. Amend the spec when each one lands, rather than leaving the spec
and the plan disagreeing.

- **Three cache passes, not two.** The spec's two-pass sync gives `favicon.svg`
  and `fonts/anton.woff2` a year-long `immutable` header, and both keep stable
  filenames. Changing the font would strand returning visitors on the old one,
  and a CloudFront invalidation cannot reach a browser cache. The middle pass
  gives those two a one-day TTL.
- **`.gitignore` stops ignoring `.terraform.lock.hcl`.** The committed lock file
  is what makes a provider pin reproducible across the laptop and CI. Unit 1.1.
- **The scanner may be Trivy rather than tfsec.** The spec names tfsec, and
  tfsec is being folded into Trivy. Unit 3.4 flags this as needing a check
  before the choice is made.

Two claims in the plan are marked unverified on purpose: the current role of the
OIDC thumbprint in IAM's verification path, and tfsec's maintenance status. Both
need confirming before being repeated.

## Worth carrying into the infrastructure sessions

Six defects in the site build came from the plan rather than from the
implementation: stale version pins, a texture color invisible on its own
background, a component interface rigid enough that callers duplicated markup, a
guard that hid the thing it guarded, a contrast value verified against one
surface but used on three, and a documentation fact amended in one place but not
its copy.

Every one surfaced when something concrete got built and a fresh reader compared
it against the requirement. None would have been prevented by writing the plan
more carefully. The infrastructure checkpoints should therefore lean on checks
that emit a status code or a number, like the 403 on the direct S3 URL, rather
than on review by reading.

That is now built in: every unit in the plan ends with a command whose output is
a status code, a number, or an exact string. `terraform plan -detailed-exitcode`
returning 0 closes success criterion 8, and the 403 on the direct S3 URL closes
criterion 2.

## Open question the plan raises

**`docs/plans/2026-08-06-infra-curriculum.md` existed as an untracked path
before this session's write.** If it held content, that content is gone and git
never had a copy. Confirm whether it was an empty placeholder before treating
the current file as complete.
