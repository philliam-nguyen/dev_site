---
id: 0004
title: Porting the html_artifacts visual identity
status: accepted
date: 2026-07-29
---

# Porting the html_artifacts visual identity

## Context

The site adopts the visual language defined in a separate project,
`the_LAB/html_artifacts`, in that project's spec 0001: retro-futurist tech-manual
and HUD. Off-white paper, orange accent, Anton condensed wordmark, JetBrains Mono
labels, corner ticks and a reticle, a blueprint grid on dark.

That spec carries a palette table naming every token with light and dark values,
and `artifacts.css` opens by calling those tokens "the contract from spec 0001."

Two separate repositories, no shared build, one developer.

Note on numbering: `html_artifacts` has its own spec 0001. References below name
the project explicitly to keep the two apart.

## Decision

The site becomes a **second implementation of the same palette table**. Its
`src/styles/tokens.css` carries the token block, the dark override, and the Anton
`@font-face`, copied value for value from html_artifacts spec 0001. All layout
CSS is site-specific and lives in `site.css`.

Three deliberate divergences.

**1. Font delivery.** html_artifacts inlines Anton as a base64 woff2 inside its
CSS, because artifact output has to work offline from a `file://` path. A website
has no such constraint, and base64 in the stylesheet means the font bytes block
first paint and cannot be cached separately. The site ships Anton as a `.woff2`
file with `font-display: swap` and a `<link rel="preload">`.

**2. Contrast.** Three token values fail WCAG AA against their own background.
Measured ratios:

| Token on its `--bg` | Light | Dark |
|---|---|---|
| `--ink-dim` | 4.97:1 pass | 5.80:1 pass |
| `--accent` | **3.13:1 fail** | 6.93:1 pass |
| `--ink-faint` | **2.81:1 fail** | **3.38:1 fail** |

Neither failure is fixed by changing the token's value, for different reasons.

`--accent` is the link color, but it also carries the wordmark period, the `»`
kicker marks, the `›` list chevrons, and the accent borders, none of which are
text and none of which need to change. Darkening it to clear 4.5:1 means roughly
a darker brown, which dulls all of that furniture to fix one use. So the site
keeps `--accent` at `#e8611c` and adds **`--accent-text`** at `#a8430e`, used
only where accent-colored text appears. Dark mode sets both to `#f6832f`, which
already measures 6.93:1.

The light value was wrong the first time. It was set to `#b84a10` on a hand
calculation against `--bg` alone (4.79:1), which ignored the two darker surfaces
the token also sits on. The axe suite from Task 10 caught both. Ratios below are
what axe measured against real composited pixels, not computed:

| `--accent-text` on | `#b84a10` | `#a8430e` |
|---|---|---|
| `--bg` | 4.79:1 pass | pass, not re-measured |
| `--accent-soft` over `--panel` (`.badge--accent`) | **4.28:1 fail** | **4.96:1 pass** |
| `--panel-2` (inline `code`) | **4.06:1 fail** | **4.70:1 pass** |

The lesson worth keeping: a contrast value is only verified against the specific
background it was checked on. Checking one and generalizing is how both failures
got in.

`--ink-faint` cannot be fixed by value at all. Clearing 4.5:1 on `#f7f5f0`
requires about `#6f6c62`, and `--ink-dim` is `#6d6a61`. The two collapse into one
color and the hierarchy disappears. So the value stays and the **usage** changes:
every rule rendering text uses `--ink-dim`, which passes in both modes, and
`--ink-faint` survives for non-text ornament only.

html_artifacts spec 0001 stays unchanged, by the author's decision, so existing
artifacts do not shift.

**3. Theming mechanism.** `prefers-color-scheme` only. No toggle, no
`data-theme` attribute, no `localStorage`. `color-scheme: light dark` is set so
scrollbars follow.

**4. Two added texture tokens.** `--hatch` and `--blueprint` carry the diagonal
hatching on the portrait panel and the blueprint grid on empty card thumbnails.
Both are near-black at low alpha in light and near-white at low alpha in dark.
They exist because the alternative is a color literal in `site.css`, and a fixed
black overlay is invisible on a dark panel: `rgba(0,0,0,.035)` over `#26282c`
moves the pixels by one or two units. html_artifacts already established this
pattern for its own `--grid`, which is `none` in light and white-on-transparent
in dark, so the site follows the precedent rather than inventing one.

Found during implementation, after a task review flagged the hardcoded overlay
as a plan-mandated defect.

## Alternatives rejected

**Copying `artifacts.css` wholesale.** Brings `.progress-rail`, `.qa`, `.fold`,
`.hud-index`, and the decision-block styles that a portfolio never uses. Dead CSS
you cannot safely delete is worse than dead CSS you never wrote, because removing
a rule means first checking whether the other project depends on it.

**A shared npm package for the tokens.** Publishing, versioning, and consuming a
20-line CSS block across two repositories with one developer is more machinery
than the problem. The spec's palette table is the cheaper enforcement mechanism.

**Fixing the contrast in html_artifacts too.** Would keep the two
implementations identical, at the cost of visibly shifting every artifact already
written. The author chose to leave them alone.

**Darkening `--accent` globally instead of adding `--accent-text`.** One fewer
token and no two-tone effect, where a link reads slightly deeper than the chevron
beside it. Rejected because it dulls the wordmark period, the kicker marks, and
the list chevrons to fix a problem that only affects text.

**Dropping orange links entirely,** with `--ink` plus an underline and `--accent`
reserved for furniture. Needs no new token and no contrast fix at all. Rejected
because orange links are part of the identity being ported.

**A theme toggle.** Requires a blocking inline script in `<head>` to read
`localStorage` before first paint, or the page flashes the wrong theme on every
load. It buys an override that few visitors want on a page they read once, and it
costs the site its zero-JavaScript property.

## Consequences

- The built page contains no JavaScript.
- Token sync between the two projects is manual. `tokens.css` carries a comment
  naming html_artifacts spec 0001 as the authority and this ADR as the record of
  where they differ.
- The contrast divergence is permanent unless html_artifacts adopts the same
  values.
- `axe-core` runs against both themes via `npm run test:a11y`, specifically to
  protect the overridden values from a future token edit. **This is local-only
  today.** No CI exists in this repository yet, and making the check binding
  requires the deploy workflow to run `npm test` and `npm run test:a11y`, plus
  `npx playwright install chromium`, which `npm ci` does not do. Recorded in the
  spec as a requirement on the Terraform plan.

  The suite has limits worth knowing. It renders only the states the seed
  content produces, so it cannot see a rule no content reaches. Two real AA
  failures hid behind exactly that during the build: the `:focus-visible` outline
  against a populated card's panel, which never rendered because every seed card
  is a transparent placeholder, and the `rec` and `warn` badge kinds, which the
  schema allowed but no content requested. Both were found by reading, not by
  the gate. A passing axe run means the rendered states are clean, not that the
  stylesheet is.

## Observed, not fixed

html_artifacts' theme toggle writes `localStorage` on click but nothing reads it
back on load, so a reopened artifact comes up on the OS preference rather than
the last choice. Out of scope here. Noted so the gap is not ported along with the
mechanism.
