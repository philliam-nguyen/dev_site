---
id: 0002
title: GitHub-hosted runner with OIDC for deploys
status: accepted
date: 2026-07-29
---

# GitHub-hosted runner with OIDC for deploys

## Context

The built site needs to reach S3 and CloudFront. The author runs a home server
behind Tailscale that already hosts services, and considered using it as the
deploy host.

A stated goal for this project is being able to explain its decisions in
conversation, which makes "why this and not that" part of the requirement rather
than a footnote.

## Decision

Deploy from a GitHub-hosted runner using OIDC federation to a scoped AWS role.
No AWS credentials are stored anywhere.

Terraform creates the OIDC provider and a deploy role whose trust policy
conditions on `aud = sts.amazonaws.com` and
`sub = repo:<owner>/<repo>:ref:refs/heads/main`. The role's permission policy
allows `s3:PutObject`, `s3:DeleteObject`, and `s3:ListBucket` on one bucket, plus
`cloudfront:CreateInvalidation` on one distribution ARN.

## Alternatives rejected

**Self-hosted runner on the home server, also using OIDC.** OIDC works
identically on a self-hosted runner, because the token comes from GitHub's API
rather than the runner's identity, so the technically interesting part is
unchanged. Rejected because no constraint forces it. The build takes roughly 20
seconds against 2,000 free minutes a month, and nothing in the job needs to reach
anything on the private network. Self-hosting would add runner lifecycle
maintenance and, on a public repository, a path for fork pull requests to execute
code inside the home network.

**Long-lived IAM access key on the home server**, driven by a git hook or cron.
Removes the GitHub dependency and the runner maintenance, but puts a permanent
credential on a box in exchange.

**IAM Roles Anywhere.** Solves the credential problem properly with X.509, and is
far more machinery than a personal site justifies.

## Consequences

- No AWS credential exists outside STS. Each run gets a one-hour credential.
- Only the `main` branch of one repository can assume the deploy role.
- Terraform does not run in CI. Static analysis (`fmt -check`, `validate`,
  `tfsec`) runs there because it needs no credentials; `plan` and `apply` stay
  local and manual.
- The home server stays available for a workload that actually needs the private
  network.
