---
id: 0003
title: Terraform state, stack topology, and per-app subdomains
status: accepted
date: 2026-07-29
---

# Terraform state, stack topology, and per-app subdomains

## Context

This started as one static site. Partway through design the scope grew: the site
is a developer hub linking to several of the author's projects, and some of those
projects will be hosted on the same domain. The current list is a recipe app, a
stripped-down RAG system, and two bootcamp capstones. Some link to a live
deployment, some link only to a GitHub repository.

An earlier draft of this design recommended a single Terraform root module with
no child modules. That recommendation was correct for one site and is wrong for
four apps.

## Decision

**State.** `infra/bootstrap/` is a root module with local state that creates the
state bucket, versioned and encrypted with `prevent_destroy` set. It is applied
once, by hand. Every other stack uses the S3 backend with `use_lockfile = true`,
which uses S3 conditional writes for locking.

**Topology.**

```
infra/
├── bootstrap/          local state, run once
├── platform/           zone lookup, ACM cert, OIDC provider, budget alarm
├── modules/
│   ├── static-site/    bucket + OAC + distribution + record + deploy role
│   └── lambda-app/     (later)
└── stacks/
    ├── portfolio/
    └── <app>/          one thin root module per app
```

App stacks read platform outputs through `terraform_remote_state`.

**Routing.** Each app gets its own subdomain and its own CloudFront
distribution.

**Region.** Everything pins to `us-east-1` with a single provider and no alias.

## Alternatives rejected

**Single root module, no child modules.** Right for one site. Once four apps each
need some variant of bucket-or-function, a distribution, a DNS record, and a
deploy role, extracting a module after the second copy-paste is later than the
right moment.

**DynamoDB lock table.** Terraform 1.10 added native S3 locking through
conditional writes, and the DynamoDB arguments are deprecated. The table is a
second resource to bootstrap and reason about for no remaining benefit.

**Path-based routing on one distribution.** One certificate and one DNS record
looks tidier, but it ties every app's deploy to a single resource, gives them a
shared blast radius, and pushes path-rewriting into each app. CloudFront charges
nothing for a distribution to exist, and the free tier is per-account, so extra
distributions are free.

**Registering the domain through Terraform.** Domain registration fits state
poorly. It happens by hand as a prerequisite, and the hosted zone is read with a
data source so no plan can ever touch the NS records.

**A provider alias for us-east-1.** ACM certificates for CloudFront must live in
us-east-1, and nothing else in this stack is region-sensitive because CloudFront
serves from edge locations regardless. Pinning everything to us-east-1 removes
the alias and a common class of "certificate not found" errors. Add the alias if
something region-sensitive appears.

## Consequences

- One hosted zone at roughly $0.50 a month covers every subdomain. It is the only
  guaranteed recurring AWS charge.
- One certificate carries both the apex and `*.domain`, because a wildcard does
  not match the apex.
- The platform stack becomes a dependency of every app stack. Changing its
  outputs is a breaking change and needs to be treated as one.
- Adding an app is a new directory under `stacks/` and a module call, not a new
  copy of a distribution config.

## Amendment, 2026-08-06: where the domain name lives

The original decision left this open. `platform/` needs the domain for the
certificate and the zone lookup, and every app stack needs it for its subdomain
record.

**Decision.** `platform/` declares the domain as a variable and re-exports it as
an output. App stacks read it from `data.terraform_remote_state.platform`
instead of declaring their own copy. If a stack later moves to a different
domain, it gets an override variable defaulting to the platform output, so the
exception stays visible in that stack's config.

**Alternatives rejected.**

*A variable in each stack, fed from its own tfvars.* That leaves five copies of
one string with nothing comparing them, and a typo in any copy still produces a
valid plan pointing at the wrong DNS record.

*A shared tfvars at the `infra/` root, passed with `-var-file`.* The value stays
written once, but the sharing then depends on someone remembering a flag on
every invocation. Reading the platform output puts the same constraint in the
dependency graph, where forgetting it fails at plan time.

**Consequences.**

The domain joins the platform outputs, so the consequence above applies to it:
changing it breaks every app stack.

No app stack can plan before `platform/` has been applied. That already held for
the certificate ARN and the OIDC provider ARN, so this adds no new coupling.
