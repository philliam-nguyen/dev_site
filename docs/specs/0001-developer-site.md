---
id: 0001
title: Developer site
status: accepted
adrs: [0001, 0002, 0003, 0004]
---

# Developer site

## Overview

A single-page developer site at a custom domain, built with Astro and served from
S3 through CloudFront, with all AWS infrastructure provisioned by Terraform. The
page carries a header, an About section, and a "Stuff I've made" grid of project
cards. Both content sections ship as skeletons and get filled in later.

The site is the hub for the author's other projects. Some cards will link to apps
hosted on their own subdomains, some to GitHub repositories only. This spec
covers the shared platform layer and the site itself. Each hosted app gets its
own brainstorm, spec, and plan.

## Scope

**In:** the Astro site, the Terraform bootstrap and platform layers, a reusable
`static-site` module, the portfolio stack, and the GitHub Actions deploy path.

**Out:** the recipe app, the RAG system, the capstone projects, and any compute
or database infrastructure. The RAG system links to its GitHub repository and is
not deployed.

## Visual design

Retro-futurist tech-manual and HUD, ported from the `html_artifacts` project's
spec 0001. Off-white paper, orange accent, Anton condensed wordmark, JetBrains
Mono for labels and chips, fixed corner ticks with a reticle, a blueprint grid on
dark.

The approved mockup lives at `mockups/skeleton-state.html`, frozen from the
brainstorm session and self-contained, and it is the visual reference for
acceptance. It shows both the skeleton state and the same page populated.

The rejected alternatives stay in `.superpowers/brainstorm/`, which is
gitignored, so they are local to the machine that produced them.

Layout, top to bottom:

- Mono eyebrow line, `PORTFOLIO // IT & SOFTWARE` left, index right
- Header: a 104px portrait panel on the left, and on the right the Anton wordmark
  carrying the author's name with an orange period, a role line, and four badges
  reading Infrastructure, Security, Automation, AI
- About: kicker, `h2`, prose
- Stuff I've made: kicker, `h2`, a two-column card grid

No link strip in v1. The component exists and reads from a list in `site.yml`
that starts empty, so adding GitHub or email later is a content change.

Theming is `prefers-color-scheme` only, no toggle, per
[[0004-visual-identity-port]]. The built page contains no JavaScript.

## Site architecture

```
site/
├── src/
│   ├── content.config.ts
│   ├── content/
│   │   ├── site.yml
│   │   ├── about.md
│   │   └── projects/*.md
│   ├── components/
│   │   ├── Hud.astro
│   │   ├── Eyebrow.astro
│   │   ├── Wordmark.astro
│   │   ├── SectionHead.astro
│   │   ├── ProjectCard.astro
│   │   └── Stub.astro
│   ├── layouts/Base.astro
│   ├── lib/sortProjects.ts
│   ├── pages/index.astro
│   └── styles/
│       ├── tokens.css
│       └── site.css
├── astro.config.mjs
└── package.json
```

### Content model

Three collections, all schema-validated at build time. Config at
`src/content.config.ts`; loaders from `astro/loaders`; zod from `astro/zod`.

```ts
const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: ({ image }) => z.object({
    title: z.string(),
    blurb: z.string().max(120),
    stack: z.array(z.string()).default([]),
    year: z.number().int(),
    order: z.number().int(),
    thumb: image().optional(),
    live: z.url({ protocol: /^https$/ }).optional(),
    repo: z.url({ protocol: /^https$/ }).optional(),
    draft: z.boolean().default(false),
    placeholder: z.boolean().default(false),
  }).refine(d => d.placeholder || d.live || d.repo, {
    message: 'a project needs a live URL, a repo URL, or both',
  }),
});
```

The `protocol` restriction is doing real work. Plain `z.string().url()` accepts
`javascript:alert(1)`, which would render straight into an `href` on a site whose
headline property is shipping no JavaScript. Constraining the scheme makes that
unrepresentable in content rather than something a test has to catch.

`about` is a single markdown entry carrying the same `placeholder` boolean.
`site` is a YAML entry holding the wordmark name, role line, eyebrow text, badge
list, and an empty links array.

**Ordering.** `order` is required, with no default and no tiebreaker. Number
sparsely by tens so inserting between two entries means `15` rather than
renumbering. `year` is displayed on the card and never sorted on, which preserves
the ability to lead with an older project without editing its year.

**Link types are derived, not declared.** There is no `type` field. The card
renders a Live chip when `live` exists and a Source chip when `repo` exists. The
`refine` fails the build on a real entry with neither. An unfinished project
omits `live` and gains it in one line when it ships.

Placeholders are exempt from that rule. A stub is not a project, so requiring it
to carry a link only forces a fake URL into the content, and the seed entries
shipped a `github.com/example/placeholder` link that resolved to a real 404. The
skeleton is supposed to read as deliberately unfinished, and a working-looking
link that 404s reads as broken instead.

### Components

| Component | Responsibility |
|---|---|
| `Base.astro` | Document shell and head |
| `Hud.astro` | Corner ticks and reticle, `aria-hidden` |
| `Eyebrow.astro` | Mono kicker line with right-aligned index |
| `Wordmark.astro` | Anton name and the orange period |
| `SectionHead.astro` | The kicker and `h2` pair |
| `ProjectCard.astro` | One card, populated or stub |
| `Stub.astro` | Dashed placeholder naming the file that replaces it |

`index.astro` composes them and holds no styling. `sortProjects.ts` filters
drafts and sorts by `order`.

### Styles

`tokens.css` holds the ported palette, the `prefers-color-scheme` override, and
the Anton `@font-face`, and nothing else. `site.css` holds site layout: the wrap,
the header grid, the portrait panel, the card grid, the responsive collapse.
Keeping them separate is what makes the token contract legible.

### Skeleton state

Two mechanisms, both small, neither a separate render path.

**The `placeholder` boolean.** When true, `Stub.astro` wraps the rendered content
in the dashed `.block-stub` frame from `artifacts.css` and prints the file that
replaces it. `about.md` and the two seed project entries ship with it set.
Deleting the flag deletes the treatment. One boolean, one conditional, shared by
both content types.

**Missing thumbnails.** `thumb` is optional. A card without one renders the
blueprint-grid panel and a mono "no image yet" label rather than a broken or
empty box. This is not placeholder-specific: any real project that has no
screenshot yet degrades the same way, which is why it keys off the absent field
instead of the flag.

## Infrastructure

Per [[0003-terraform-topology]]. Everything in `us-east-1`, single provider, no
alias.

### `infra/bootstrap/`

Local state, applied once by hand. Creates the state bucket with versioning,
server-side encryption, public access blocked, and `prevent_destroy`. Its
`terraform.tfstate` is a real file on disk and must be gitignored.

### `infra/platform/`

- `data "aws_route53_zone"` looking the zone up by name. Never creates it.
- One ACM certificate: apex as `domain_name`, `*.domain` as a SAN.
- Route 53 validation records and `aws_acm_certificate_validation`.
- `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`,
  thumbprint from `data.tls_certificate`.
- An AWS Budget with a low monthly threshold and an email alert.

The budget is the deliberate observability choice. CloudFront access logs would
cost S3 storage to collect and go unread; a budget alarm reports the one thing
that matters on a free-tier account.

### `infra/modules/static-site/`

- Bucket with all four public access block flags true and ownership controls set
  to `BucketOwnerEnforced`, so ACLs are off.
- `aws_cloudfront_origin_access_control` with sigv4 signing. Bucket policy grants
  `s3:GetObject` to `cloudfront.amazonaws.com` only, conditioned on
  `AWS:SourceArn` matching this distribution. The condition is what prevents any
  other distribution in any account from reading the bucket.
- Distribution: `default_root_object = "index.html"`,
  `viewer_protocol_policy = "redirect-to-https"`, compression on, managed
  CachingOptimized cache policy, `PriceClass_100`.
- A response headers policy carrying HSTS, `X-Content-Type-Options`,
  `Referrer-Policy`, and a CSP.
- A CloudFront Function issuing a 301 from `www` to the apex.
- Route 53 A and AAAA alias records using the distribution's own
  `hosted_zone_id` attribute, not a hardcoded zone ID.
- A deploy role assumable only through the OIDC provider, scoped to
  `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on this bucket and
  `cloudfront:CreateInvalidation` on this distribution.

### `infra/stacks/portfolio/`

S3 backend with `use_lockfile = true`, a `terraform_remote_state` data source
reading platform outputs, and one module call.

## Deploy

Per [[0002-github-oidc-deploy-identity]]. Terraform does not run in CI.

```yaml
on:
  push:
    branches: [main]
    paths: ['site/**', '.github/workflows/deploy.yml']
  workflow_dispatch:
concurrency: { group: deploy, cancel-in-progress: false }
jobs:
  deploy:
    permissions: { id-token: write, contents: read }
```

Steps: `npm ci`, `npx playwright install chromium`, `astro check`, `npm test`,
`npm run test:a11y`, `astro build`, assume role, sync, invalidate.

The browser install is a separate step because `npm ci` does not download it.
Running both suites in the workflow is what makes ADR 0004's accessibility
guarantee binding rather than a local habit.

Two sync passes, and the order matters. Hashed assets go first with
`max-age=31536000, immutable`; HTML goes second with `max-age=0,
must-revalidate`. HTML uploaded before the files it references produces a page
that 404s on its own stylesheet for the length of the second pass. Astro hashes
asset filenames, so a long immutable TTL is safe.

Invalidation uses `/*`, which counts as one path against the 1,000 free paths a
month.

The role ARN lives in a repository variable, not a secret and not hardcoded, so
the same workflow shape drops into later app stacks with one value changed.

`scripts/deploy.ps1` runs the same three commands against a local AWS profile.

**`.gitignore`:** `infra/bootstrap/terraform.tfstate*`, `.terraform/`, `*.tfvars`
except `.example`, `.superpowers/`, `node_modules/`, `dist/`.

## Verification

**Free from the build.** The zod schema fails `astro build` on a malformed entry,
including the `refine` rejecting a project with no links. `astro check` catches
type errors.

**Unit tests.** `sortProjects()` only: drafts excluded, `order` respected. No
component render tests, which would test Astro rather than this code.

**Accessibility.** Playwright with `@axe-core/playwright` against the built
output in both themes, protecting the contrast decisions in
[[0004-visual-identity-port]] from a future token edit. Playwright rather than
`@axe-core/cli` because verifying dark mode needs
`emulateMedia({ colorScheme: 'dark' })`, which the CLI cannot set. jsdom is
disqualified too, since axe's color-contrast rule needs real rendering. The same
suite asserts the built page loads no `.js` and contains no inline `<script>`.

**Terraform static analysis in CI.** `fmt -check`, `validate`, and `tfsec` need
no credentials or state, so they run on every push. `plan` and `apply` stay
manual.

**Infrastructure checks, run by hand after apply:**

```
curl -sI https://<domain>                      # 200, HSTS present
curl -sI http://<domain>                       # 301 to https
curl -sI https://www.<domain>                  # 301 to apex
curl -sI https://<bucket>.s3.amazonaws.com/index.html   # 403
aws s3api get-public-access-block --bucket <name>       # all four true
dig +short <domain>                            # CloudFront edges
```

The 403 is the one that separates "the site works" from "the site works and the
bucket is not readable by anyone else."

**Manual visual acceptance.** Light mode is checked against the approved mockup
in `skeleton-state.html`, both in its skeleton and populated states. Mobile width
is checked for the header grid collapsing to one column and the card grid going
to one across.

No dark mockup of the final layout exists. The only dark preview produced during
design (`identity-merge.html`) predates the badge changes and the removal of the
link strip, so it is not an acceptance reference. Dark is checked against the
palette table in html_artifacts spec 0001 plus the three overrides in
[[0004-visual-identity-port]], and a dark preview gets produced and approved
during implementation before the site ships.

## Success criteria

1. `https://<domain>` serves the page over HTTPS with HSTS present
2. The direct S3 URL returns 403
3. A push to `main` touching `site/` deploys with no stored AWS credential
4. Adding one markdown file to `src/content/projects/` produces one card, with no
   other edit
5. The skeleton state renders as deliberately unfinished and names the files that
   replace it
6. Light and dark both pass axe with zero violations
7. The built output contains no JavaScript
8. `terraform plan` on a clean tree reports no changes

## Manual prerequisites

1. Register the domain. Route 53 creates the hosted zone automatically; another
   registrar means creating the zone and repointing nameservers.
2. `git init` and create the GitHub repository, public.
3. An AWS account with a local admin-capable profile for the bootstrap, platform,
   and portfolio applies.
4. Node 22.12 or newer, required by Astro 7.
5. Terraform 1.10 or newer, required for `use_lockfile`.

## Implementation split

The site is built normally. The infrastructure is built by the author with
guidance, in full teaching mode: the trade-off space gets covered before each
piece is written, and there are quiz checkpoints. That plan is a curriculum with
build checkpoints rather than a task list, and it spans two to three sessions.

## Known future directions

Recorded so the current design does not fight them. None are in scope.

- Hosted apps at their own subdomains, consuming platform outputs
  ([[0003-terraform-topology]]).
- The recipe app's demo mode (seeded data, no backend) as the second consumer of
  `static-site`. That is the real test of whether the module's boundaries are
  right, since a module with one consumer is a guess.
- A `lambda-app` module alongside `static-site` if a public serverless app ever
  arrives. Nothing currently planned needs one.
- A scheduled link checker once project entries carry external URLs worth
  rotting.

## Carried into the Terraform plan

Found while building the site. Each one is an input to the infrastructure work,
not a site defect.

- **Two assets are not content-hashed.** `favicon.svg` and `fonts/anton.woff2`
  keep stable filenames, and the deploy's first sync pass gives everything except
  `*.html` a year-long `immutable` header. Rename either file when its contents
  change, or exclude the two from that pass. `tokens.css` carries this warning
  for the font; the favicon has none.
- **Pin `build.inlineStylesheets`.** Astro's `'auto'` inlines stylesheets under
  roughly 4 kB, and this build's output actually crossed that threshold partway
  through and flipped from an inline `<style>` to an external hashed file. The
  CSP in the response headers policy depends on which one ships, so the value
  should be pinned rather than left to the size of the stylesheet.
- **The deploy workflow needs `npx playwright install chromium`.** `npm ci` does
  not download browsers, so `npm run test:a11y` fails in CI without it.
- **`astro.config.mjs`'s `site` value** is `https://example.com` until the domain
  is registered.

## Known limits of the accessibility gate

Recorded because a passing suite is easy to over-trust.

`npm run test:a11y` renders only the states the seed content produces. It cannot
see a rule that no content reaches. Two real AA failures hid behind exactly that
and were found by reading rather than by the gate: the `:focus-visible` outline
against a populated card's panel, invisible because every seed card is a
transparent placeholder, and the `rec` and `warn` badge kinds, which the schema
allowed but nothing requested. The first was fixed, the second removed from the
schema.

The zero-JavaScript test checks response URLs against `/\.m?js(\?|$)/`, counts
`<script>` elements, and collects `on*` attribute names. It does not cover
`javascript:` URIs, which the content schema now makes unrepresentable instead,
or shadow-DOM content, which is unreachable without JavaScript on the page.

## Deferred, with rulings

Real, understood, and deliberately not fixed.

- `favicon.svg` hardcodes its colors and does not follow `prefers-color-scheme`.
  An embedded `<style>` with a media query inside the SVG would work; `var()`
  would not, since an icon-linked SVG sits outside the page cascade.
- `<Image>` is fixed at 640x360 and Astro 7 refuses to upscale, so a first real
  thumbnail smaller than that fails the build. Loud failure, no code exercises it
  yet.
- `alt=""` treats project screenshots as decorative. The adjacent heading names
  the project and the blurb describes it. Revisit if a thumbnail ever carries
  information the card text does not.
- Nothing enforces unique `order`. Duplicates fall back to glob order silently,
  which is the likely result of copying a project file without renumbering.
- ~~There is no `README`~~. Resolved: `site/README.md` documents the scripts,
  the Node floor, and the content model.

## Open questions

None blocking. The domain name is chosen at registration time and threaded
through as a Terraform variable.
