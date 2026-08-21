# phillip-nguyen.dev

Source for the developer portfolio site at `phillip-nguyen.dev`, plus the
Terraform for the AWS account it lives in. Two halves:

- **`site/`** — the Astro site. Static, zero JavaScript in the build, content
  driven by markdown collections. Commands and the content model are in
  `site/README.md`. Built and reviewed; not yet deployed.
- **`infra/`** — all Terraform for the account, per
  [ADR 0003](docs/adr/0003-terraform-topology.md):
  - `bootstrap/` — the state bucket, local state, applied once.
  - `platform/` — account-wide singletons: hosted zone lookup, the ACM
    certificate, the GitHub OIDC provider, the budget alarm. Publishes the
    outputs every app stack consumes.
  - `stacks/recipe/` — AWS ingress for the recipe app's Demo Variant, live at
    `meal-prep.phillip-nguyen.dev`. The app itself lives in the
    `meal-prep-app` repository; see `infra/stacks/recipe/README.md` for the
    split and the CI contract.

`docs/` holds the specs, ADRs, and plans. Start with
[`docs/progress.md`](docs/progress.md) — it is the living state of the project
and is maintained so nobody has to do git archaeology.

Working notes: everything is `us-east-1`, Terraform 1.10+, and local applies
need `AWS_PROFILE=phil`. Deploys run through GitHub Actions with OIDC; no AWS
credential is stored in any repo or in GitHub secrets.
