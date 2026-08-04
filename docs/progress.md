# Progress

Living state for the developer site. Update this rather than reading git
archaeology. Current as of 2026-07-31, commit `3a0d0a2` on `main`.

## Current status

The Astro site is built, reviewed, merged, and pushed. **It is not deployed and
not reachable by anyone.**

Spec 0001 covers two halves: the site, and the AWS infrastructure that serves it.
The site half is done. No infrastructure exists yet. There is no `infra/`
directory, no state bucket, no distribution, and no deploy workflow.

Of the spec's eight success criteria, 4 through 7 are met. Criteria 1, 2, 3, and
8 all describe a deployed site and are unmet by definition.

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

## In progress

Nothing. No branch is open and the working tree is clean.

## Next

1. **Write the infrastructure curriculum plan.** Teaching-mode shape rather than
   a task list: trade-off space covered before each piece is written, quiz
   checkpoints, two to three sessions. This can be written before either
   prerequisite below exists.
2. **Register the domain**, and confirm an AWS account with a local
   admin-capable profile. Both block any `terraform apply`.
3. **Build `infra/`** across those guided sessions: bootstrap, platform, the
   `static-site` module, the portfolio stack, and the GitHub Actions deploy path.
4. **Then the other projects.** The recipe app and the two capstones each get
   their own brainstorm, spec, and plan. The RAG system links to its repository
   and needs no infrastructure.

## Open questions

- **Which domain name?** It determines the hosted zone and threads through
  everything as a Terraform variable. Nothing can be applied without it.
- **Root `README`?** The repository landing page is currently blank.
  `site/README.md` covers the commands and the content model, but a root README
  would want to describe `site/` and `infra/` together, which reads better once
  the second one exists.

## State the next phase depends on

- **The OIDC trust policy value is fixed** by the repository name:
  `repo:philliam-nguyen/dev_site:ref:refs/heads/main`. Renaming the repo breaks
  deploys until Terraform is re-applied.
- **Four build outputs are inputs to the Terraform work.** They live in spec
  0001 under "Carried into the Terraform plan": two unhashed assets that will
  land in the immutable cache pass, `build.inlineStylesheets` needing a pin
  before the CSP is written, `npx playwright install chromium` as a workflow
  step `npm ci` will not cover, and the placeholder `site` URL in
  `astro.config.mjs`.
- **Node 22.12 or newer**, required by Astro 7. The CI runner needs it too.
- **The remote uses an SSH host alias**, `git@github-personal:...`, not
  `github.com`. A pasted HTTPS URL will fail with `Permission denied`.

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
