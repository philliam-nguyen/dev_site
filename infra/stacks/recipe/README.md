# stacks/recipe

AWS ingress for the recipe app's Demo Variant, live at
`https://meal-prep.phillip-nguyen.dev`. This stack is only the front door: the
app's API and Postgres run on the homelab and are reached over Tailscale. The
application, its Compose files, the tailnet policy, and the ADRs that decided
this shape all live in the `philliam-nguyen/meal-prep-app` repository
(`recipe_site/` locally) — start with its ADR 0008 (demo backend on the
homelab) and research doc 0002 (the ingress design).

What this stack provisions:

- A CloudFront distribution with two origins: the frontend bundle from S3
  behind OAC, and `/api/*` routed through a VPC origin to the proxy instance.
  Retry counts and timeouts on the `/api/*` behaviour are deliberately low so a
  dead homelab degrades to the recorded-seed read-only mode in seconds.
- A `t4g.nano` (AL2023 arm64) in a public subnet running nginx and
  `tailscaled`, joined to the tailnet as `tag:proxy`. No inbound security
  group rules of its own; CloudFront's service-managed VPC-origins group is the
  only ingress. Management is Tailscale SSH; there is no port 22 from the
  internet.
- DNS, the frontend bucket, and the `meal-prep-deploy` OIDC role.

It consumes the platform outputs (`zone_id`, `domain_name`, `certificate_arn`,
`oidc_provider_arn`) via `terraform_remote_state`, per ADR 0003.

## The CI contract

The meal-prep-app repository's workflow deploys the frontend bundle using three
GitHub repository **variables** that come from this stack's outputs:

| Repo variable in meal-prep-app | Output here |
|---|---|
| `DEMO_DEPLOY_ROLE_ARN` | `deploy_role_arn` |
| `DEMO_BUCKET` | `frontend_bucket` |
| `DEMO_DISTRIBUTION_ID` | `distribution_id` |

Recreating any of those resources means updating the variables over there, or
that repo's deploys break with no signal on this side.

## Operational notes

- The SSM parameter `/meal-prep/tailscale-auth-key` must exist before apply;
  the instance reads it at boot to join the tailnet.
- Rebuilding the instance changes its tailnet address. The policy file at
  `recipe_site/ops/tailnet/policy.hujson` pins the proxy's address in `hosts`
  on purpose, so its `tests` block fails loudly until the entry is updated.
- The AMI is pinned via `ignore_changes`; patching is `dnf` on the box, not
  instance replacement. Recovery from a lost instance is `terraform apply`.
- Standing cost is about $7.37/month, dominated by the instance and its public
  IPv4. The derivation and the rejected alternatives are in the app repo's
  research docs.
