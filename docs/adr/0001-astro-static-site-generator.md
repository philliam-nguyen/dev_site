---
id: 0001
title: Astro as the static site generator
status: accepted
date: 2026-07-29
---

# Astro as the static site generator

## Context

A single-page developer site: an About section and a grid of project cards.
The project list starts empty and grows one entry at a time. Cards carry a
thumbnail, a title, a one-line blurb, a stack list, a year, and links.

The author works in Python and JavaScript. The inspiration site
(thariq.io) is built with Astro.

## Decision

Astro, using content collections for projects, the About prose, and the header
configuration.

## Alternatives rejected

**Plain HTML and CSS with a projects array in a JS file.** Genuinely viable and
simpler: no build step, no `node_modules`, no toolchain. Rejected because adding
a project means editing markup, nothing validates an entry's shape, and every
thumbnail needs hand-optimizing. The card grid is regular enough that a schema
and an image pipeline pay for the toolchain they cost.

**Eleventy.** Lighter than Astro and data-driven in the same way, but it has no
built-in image handling. Thumbnail optimization is a material part of what these
cards need, so the gap would be filled by hand or by another dependency.

## Consequences

- A Node toolchain and a `node_modules` directory exist for a one-page site.
- A frontmatter typo fails the build through the zod schema instead of rendering
  a broken card.
- Thumbnails must live under `src/`, not `public/`, because only `src/` assets
  pass through `astro:assets`.
- Astro ships no client JavaScript by default. Combined with the theming
  decision in [[0004-visual-identity-port]], the built page contains none at all.
