---
date: 2026-07-29
spec: 0001
feature: site-build
---

# Developer Site (Astro) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the static Astro site described in `docs/specs/0001-developer-site.md`, ready to deploy, with content shipping as skeletons.

**Architecture:** One page composed of small single-responsibility `.astro` components. All content lives in schema-validated collections under `src/content/`, so publishing is a content edit and a malformed entry is a build failure. Styling splits into `tokens.css` (the ported design-system contract) and `site.css` (local layout). The built page ships zero client JavaScript.

**Tech Stack:** Astro 7, TypeScript, vitest for the one pure function, Playwright plus `@axe-core/playwright` for accessibility.

## Global Constraints

- Everything lives under `site/`. Terraform is out of scope for this plan.
- Node 22.12 or newer. Required by Astro 7; Node 18 and 20 support was dropped in v6.
- The built output must contain **zero** JavaScript. No client directives, no inline scripts, no theme toggle.
- Theming is `prefers-color-scheme` only. No `data-theme` attribute, no `localStorage`.
- `tokens.css` contains only palette, `@font-face`, and the dark override. Layout rules go in `site.css`. Never mix.
- Token values are transcribed from `the_LAB/html_artifacts/docs/artifacts.css`. Divergences are limited to those named in ADR 0004 and Task 4 of this plan.
- No emoji anywhere in code, content, or commit messages.
- Project cards render a Live chip when `live` exists and a Source chip when `repo` exists. Never a `type` field.
- `order` is required on every project. No default, no tiebreaker.

**Prerequisite:** `git init` and a GitHub repository must exist before Task 1, because every task ends in a commit. This is listed as a manual prerequisite in the spec.

---

### Task 1: Scaffold the Astro project

**Files:**
- Create: `site/package.json`
- Create: `site/astro.config.mjs`
- Create: `site/tsconfig.json`
- Create: `site/src/pages/index.astro`
- Create: `.gitignore` (repo root)

**Interfaces:**
- Consumes: nothing
- Produces: a buildable Astro project at `site/`, `npm run build` emitting `site/dist/index.html`

- [ ] **Step 1: Create the root `.gitignore`**

```
node_modules/
dist/
.astro/
.superpowers/

# terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
.terraform.lock.hcl

# playwright
test-results/
playwright-report/
```

- [ ] **Step 2: Create `site/package.json`**

```json
{
  "name": "developer-site",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "check": "astro check",
    "test": "vitest run",
    "test:a11y": "playwright test"
  },
  "dependencies": {
    "astro": "^7.0.0"
  },
  "devDependencies": {
    "@astrojs/check": "^0.9.0",
    "typescript": "^5.6.0",
    "vitest": "^4.0.0"
  }
}
```

- [ ] **Step 3: Create `site/astro.config.mjs`**

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://example.com',
  build: { format: 'file' },
});
```

The `site` value is a placeholder until the domain is registered. `format: 'file'` emits `dist/index.html` rather than `dist/index/index.html`, which matches the S3 sync and `default_root_object` in the spec.

- [ ] **Step 4: Create `site/tsconfig.json`**

```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"]
}
```

- [ ] **Step 5: Create a minimal `site/src/pages/index.astro`**

```astro
---
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Scaffold</title>
  </head>
  <body>
    <p>scaffold</p>
  </body>
</html>
```

- [ ] **Step 6: Install and build**

Run from `site/`:

```
npm install
npm run build
```

Expected: `site/dist/index.html` exists and contains `scaffold`.

- [ ] **Step 7: Commit**

```bash
git add .gitignore site/package.json site/package-lock.json site/astro.config.mjs site/tsconfig.json site/src/pages/index.astro
git commit -m "Task 1: scaffold Astro project

Placeholder site URL until the domain is registered. build.format=file
emits dist/index.html to match the S3 default_root_object."
```

---

### Task 2: `sortProjects()` with tests

**Files:**
- Create: `site/src/lib/sortProjects.ts`
- Create: `site/src/lib/sortProjects.test.ts`
- Create: `site/vitest.config.ts`

**Interfaces:**
- Consumes: nothing
- Produces: `sortProjects<T extends SortableProject>(entries: T[]): T[]` and the exported type `SortableProject = { data: { order: number; draft: boolean } }`. Task 8 calls this with `CollectionEntry<'projects'>[]`.

The function is generic over a **structural** shape rather than typed against `CollectionEntry`. `astro:content` is a virtual module that does not resolve under vitest, and a pure function should not depend on the framework anyway. The generic still accepts real collection entries at the call site.

- [ ] **Step 1: Create `site/vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    environment: 'node',
  },
});
```

- [ ] **Step 2: Write the failing test**

Create `site/src/lib/sortProjects.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { sortProjects } from './sortProjects';

const entry = (order: number, draft = false) => ({ data: { order, draft } });

describe('sortProjects', () => {
  it('sorts ascending by order', () => {
    const result = sortProjects([entry(30), entry(10), entry(20)]);
    expect(result.map(e => e.data.order)).toEqual([10, 20, 30]);
  });

  it('excludes drafts', () => {
    const result = sortProjects([entry(10), entry(20, true), entry(30)]);
    expect(result.map(e => e.data.order)).toEqual([10, 30]);
  });

  it('does not mutate the input array', () => {
    const input = [entry(30), entry(10)];
    sortProjects(input);
    expect(input.map(e => e.data.order)).toEqual([30, 10]);
  });

  it('returns an empty array when every entry is a draft', () => {
    expect(sortProjects([entry(10, true)])).toEqual([]);
  });
});
```

The non-mutation test matters because `Array.prototype.sort` sorts in place. Sorting the array `getCollection` returned would mutate Astro's cached collection.

- [ ] **Step 3: Run the test to verify it fails**

Run from `site/`: `npx vitest run src/lib/sortProjects.test.ts`

Expected: FAIL, "Failed to resolve import ./sortProjects".

- [ ] **Step 4: Write the implementation**

Create `site/src/lib/sortProjects.ts`:

```ts
export type SortableProject = {
  data: { order: number; draft: boolean };
};

export function sortProjects<T extends SortableProject>(entries: T[]): T[] {
  return entries
    .filter(entry => !entry.data.draft)
    .sort((a, b) => a.data.order - b.data.order);
}
```

`filter` returns a new array, so the subsequent `sort` never touches the input.

- [ ] **Step 5: Run the tests to verify they pass**

Run from `site/`: `npx vitest run`

Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add site/vitest.config.ts site/src/lib/
git commit -m "Task 2: sortProjects with tests

Generic over a structural shape rather than CollectionEntry so the
function stays framework-free and testable without the astro:content
virtual module."
```

---

### Task 3: Content collections and seed content

**Files:**
- Create: `site/src/content.config.ts`
- Create: `site/src/content/site.yml`
- Create: `site/src/content/about.md`
- Create: `site/src/content/projects/project-one.md`
- Create: `site/src/content/projects/project-two.md`

**Interfaces:**
- Consumes: nothing
- Produces: three collections queryable as `getEntry('site', 'site')`, `getEntry('about', 'about')`, `getCollection('projects')`. Field names are fixed here and used verbatim by Tasks 6, 7, and 8.

- [ ] **Step 1: Create `site/src/content.config.ts`**

```ts
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const site = defineCollection({
  loader: glob({ pattern: 'site.yml', base: './src/content' }),
  schema: z.object({
    name: z.string(),
    role: z.string(),
    portraitInitials: z.string().max(3),
    eyebrowLeft: z.string(),
    eyebrowRight: z.string(),
    badges: z.array(z.object({
      text: z.string(),
      kind: z.enum(['default', 'accent', 'rec', 'warn']).default('default'),
    })),
    links: z.array(z.object({
      label: z.string(),
      href: z.string().url(),
    })).default([]),
  }),
});

const about = defineCollection({
  loader: glob({ pattern: 'about.md', base: './src/content' }),
  schema: z.object({
    placeholder: z.boolean().default(false),
  }),
});

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: ({ image }) => z.object({
    title: z.string(),
    blurb: z.string().max(120),
    stack: z.array(z.string()).default([]),
    year: z.number().int(),
    order: z.number().int(),
    thumb: image().optional(),
    live: z.string().url().optional(),
    repo: z.string().url().optional(),
    draft: z.boolean().default(false),
    placeholder: z.boolean().default(false),
  }).refine(d => d.live || d.repo, {
    message: 'a project needs a live URL, a repo URL, or both',
  }),
});

export const collections = { site, about, projects };
```

- [ ] **Step 2: Create `site/src/content/site.yml`**

```yaml
name: Phil Nguyen
role: One line about what you do. Edit this in src/content/site.yml.
portraitInitials: PN
eyebrowLeft: PORTFOLIO // IT & SOFTWARE
eyebrowRight: "2026"
badges:
  - text: Infrastructure
    kind: accent
  - text: Security
  - text: Automation
  - text: AI
links: []
```

- [ ] **Step 3: Create `site/src/content/about.md`**

```markdown
---
placeholder: true
---

Write two or three paragraphs here. Markdown works, so headings, **bold**, and
links all render.

Set `placeholder: false` in the frontmatter when this is real, and the dashed
frame around it disappears.
```

- [ ] **Step 4: Create the two seed projects**

`site/src/content/projects/project-one.md`:

```markdown
---
title: Project title
blurb: One line on what it does.
stack: ["stack"]
year: 2026
order: 10
repo: https://github.com/example/placeholder
placeholder: true
---
```

`site/src/content/projects/project-two.md`:

```markdown
---
title: Project title
blurb: One line on what it does.
stack: ["stack"]
year: 2026
order: 20
repo: https://github.com/example/placeholder
placeholder: true
---
```

- [ ] **Step 5: Verify the build succeeds**

Run from `site/`: `npm run build`

Expected: build succeeds. Astro generates `.astro/types.d.ts` with the collection types.

- [ ] **Step 6: Verify the schema actually rejects bad input**

This step proves the guarantee rather than assuming it. Create `site/src/content/projects/tmp-bad.md`:

```markdown
---
title: No links
blurb: This entry has neither a live URL nor a repo URL.
year: 2026
order: 99
---
```

Run: `npm run build`

Expected: FAIL, with the message `a project needs a live URL, a repo URL, or both`.

Then delete the file:

```
rm site/src/content/projects/tmp-bad.md
```

Run `npm run build` again. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add site/src/content.config.ts site/src/content/
git commit -m "Task 3: content collections and seed content

Three collections, all schema-validated at build time. The refine on
projects rejects an entry with neither a live nor a repo URL, verified
by a deliberate failing build."
```

---

### Task 4: Token port, font, and the contrast overrides

**Files:**
- Create: `site/src/styles/tokens.css`
- Create: `site/public/fonts/anton.woff2` (copied)

**Interfaces:**
- Consumes: nothing
- Produces: CSS custom properties consumed by every rule in `site.css`. Names match `the_LAB/html_artifacts/docs/artifacts.css` exactly, plus one addition: `--accent-text`.

**Three divergences from html_artifacts, per ADR 0004:**

1. Anton ships as a file with a preload hint, not base64 inside the CSS.
2. `--accent-text` is a **new token**. `--accent` at `#e8611c` measures 3.13:1 on `--bg` and fails AA for text. Rather than darkening `--accent` globally, which dulls the wordmark dot, chevrons, and borders that carry the identity, the darkened value lives in a separate token used only where accent-colored **text** appears. Dark mode needs no override, since `#f6832f` measures 6.93:1.
3. `--ink-faint` keeps its value and loses its text uses. At AA on this background it would have to darken to roughly `#6f6c62`, which is indistinguishable from `--ink-dim` at `#6d6a61` and collapses the two-step hierarchy. Instead, every rule in `site.css` that renders text uses `--ink-dim` (4.97:1 light, 5.80:1 dark), and `--ink-faint` survives for non-text ornament only.

- [ ] **Step 1: Copy the font**

```powershell
New-Item -ItemType Directory -Force site/public/fonts
Copy-Item ../../html_artifacts/docs/authoring/assets/anton.woff2 site/public/fonts/anton.woff2
```

Adjust the source path to wherever `the_LAB/html_artifacts` sits relative to this repo. The file is 8,680 bytes.

- [ ] **Step 2: Create `site/src/styles/tokens.css`**

```css
/* Design tokens. AUTHORITY: the_LAB/html_artifacts docs/specs/0001-artifact-system.md,
   section "Palette tokens". This file is a second implementation of that table.
   Divergences are recorded in docs/adr/0004-visual-identity-port.md and are
   limited to: font delivery, the added --accent-text, and the usage rule that
   --ink-faint never carries text. Do not edit a value here without updating
   that ADR. Layout rules belong in site.css, never here. */

@font-face {
  font-family: 'Anton';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  /* Not content-hashed. Rename the file if the face is ever replaced, because
     the deploy sync serves everything outside *.html as immutable for a year. */
  src: url('/fonts/anton.woff2') format('woff2');
}

:root {
  color-scheme: light dark;

  --bg: #f7f5f0;
  --panel: #eeece4;
  --panel-2: #e6e3d9;
  --ink: #22201b;
  --ink-dim: #6d6a61;
  --ink-faint: #97948a;
  --line: #e2dfd4;
  --tick: #cdcabf;
  --accent: #e8611c;
  --accent-text: #b84a10;
  --accent-soft: rgba(232, 97, 28, .10);
  --accent-border: rgba(232, 97, 28, .36);
  --rec: #2f8f5b;
  --rec-soft: rgba(47, 143, 91, .10);
  --rec-border: rgba(47, 143, 91, .34);
  --warn: #cf4b2e;
  --warn-soft: rgba(207, 75, 46, .10);
  --warn-border: rgba(207, 75, 46, .34);
  --grid: none;

  --font: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, "Cascadia Code", Consolas, monospace;
  --display: "Anton", "Arial Narrow", "Roboto Condensed", system-ui, sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #17181b;
    --panel: #202226;
    --panel-2: #26282c;
    --ink: #eae8e2;
    --ink-dim: #97948b;
    --ink-faint: #6f6c64;
    --line: #303237;
    --tick: #46484e;
    --accent: #f6832f;
    --accent-text: #f6832f;
    --accent-soft: rgba(246, 131, 47, .12);
    --accent-border: rgba(246, 131, 47, .40);
    --rec: #5ec98a;
    --rec-soft: rgba(94, 201, 138, .12);
    --rec-border: rgba(94, 201, 138, .40);
    --warn: #ff6b4a;
    --warn-soft: rgba(255, 107, 74, .12);
    --warn-border: rgba(255, 107, 74, .40);
    --grid:
      repeating-linear-gradient(0deg, rgba(255,255,255,.03) 0 1px, transparent 1px 22px),
      repeating-linear-gradient(90deg, rgba(255,255,255,.03) 0 1px, transparent 1px 22px);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add site/src/styles/tokens.css site/public/fonts/anton.woff2
git commit -m "Task 4: port design tokens and ship Anton

Adds --accent-text so the failing 3.13:1 link color darkens without
dulling the decorative accent. --ink-faint keeps its value and loses
its text uses instead, because darkening it to AA collapses it into
--ink-dim. Implements ADR-0004."
```

---

### Task 5: Base layout, HUD, and page shell

**Files:**
- Create: `site/src/layouts/Base.astro`
- Create: `site/src/components/Hud.astro`
- Create: `site/src/styles/site.css`
- Modify: `site/src/pages/index.astro` (full rewrite)

**Interfaces:**
- Consumes: `tokens.css` from Task 4
- Produces: `Base.astro` accepting `{ title: string; description: string }` and rendering a default slot inside `main.wrap`. Tasks 6 through 9 add sections into that slot.

- [ ] **Step 1: Create `site/src/components/Hud.astro`**

```astro
---
/* Decorative corner furniture. aria-hidden because it carries no information. */
---
<span class="tick tl" aria-hidden="true">+</span>
<span class="tick tr" aria-hidden="true">&#9678;</span>
<span class="tick bl" aria-hidden="true">+</span>
<span class="tick br" aria-hidden="true">+</span>
```

- [ ] **Step 2: Create `site/src/layouts/Base.astro`**

```astro
---
import '../styles/tokens.css';
import '../styles/site.css';
import Hud from '../components/Hud.astro';

interface Props {
  title: string;
  description: string;
}

const { title, description } = Astro.props;
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <link
      rel="preload"
      href="/fonts/anton.woff2"
      as="font"
      type="font/woff2"
      crossorigin
    />
  </head>
  <body>
    <Hud />
    <main class="wrap">
      <slot />
    </main>
  </body>
</html>
```

- [ ] **Step 3: Create `site/public/favicon.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <rect width="32" height="32" fill="#f7f5f0"/>
  <circle cx="16" cy="16" r="6" fill="#e8611c"/>
</svg>
```

- [ ] **Step 4: Create `site/src/styles/site.css` with the shell rules**

```css
/* Layout for this site. Design tokens live in tokens.css and are never
   redefined here. */

* { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }

body {
  margin: 0;
  min-height: 100vh;
  color: var(--ink);
  line-height: 1.62;
  font-family: var(--font);
  font-size: 16px;
  background-color: var(--bg);
  background-image: var(--grid);
  background-attachment: fixed;
}

.tick {
  position: fixed;
  z-index: 40;
  color: var(--tick);
  font-size: 13px;
  line-height: 1;
  pointer-events: none;
}
.tick.tl { top: 14px; left: 14px; }
.tick.tr { top: 13px; right: 14px; }
.tick.bl { bottom: 14px; left: 14px; }
.tick.br { bottom: 14px; right: 14px; }

.wrap {
  max-width: 840px;
  margin: 0 auto;
  padding: 56px 30px 96px;
}

a { color: var(--accent-text); }

code {
  font-family: var(--mono);
  font-size: .85em;
  background: var(--panel-2);
  border: 1px solid var(--line);
  border-radius: 5px;
  padding: .08em .4em;
  color: var(--accent-text);
}

:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 3px;
}
```

- [ ] **Step 5: Rewrite `site/src/pages/index.astro`**

```astro
---
import Base from '../layouts/Base.astro';
import { getEntry } from 'astro:content';

const site = await getEntry('site', 'site');
if (!site) throw new Error('src/content/site.yml is missing');
---
<Base title={site.data.name} description={site.data.role}>
  <p>shell</p>
</Base>
```

- [ ] **Step 6: Verify the build and inspect the output**

Run from `site/`:

```
npm run build
```

Expected: build succeeds.

Then confirm the zero-JavaScript constraint holds, from `site/`:

```powershell
Get-ChildItem dist -Recurse -Filter *.js
```

Expected: no results.

- [ ] **Step 7: Commit**

```bash
git add site/src/layouts/ site/src/components/Hud.astro site/src/styles/site.css site/src/pages/index.astro site/public/favicon.svg
git commit -m "Task 5: base layout, HUD furniture, page shell"
```

---

### Task 6: Header

**Files:**
- Create: `site/src/components/Eyebrow.astro`
- Create: `site/src/components/Wordmark.astro`
- Modify: `site/src/pages/index.astro`
- Modify: `site/src/styles/site.css` (append)

**Interfaces:**
- Consumes: the `site` collection entry from Task 3, `Base.astro` from Task 5
- Produces: `Eyebrow` accepting `{ left: string; right?: string }`, `Wordmark` accepting `{ name: string }`

- [ ] **Step 1: Create `site/src/components/Eyebrow.astro`**

```astro
---
interface Props {
  left: string;
  right?: string;
}

const { left, right } = Astro.props;
---
<p class="eyebrow">
  <span>{left}</span>
  {right && <span class="idx">{right}</span>}
</p>
```

- [ ] **Step 2: Create `site/src/components/Wordmark.astro`**

```astro
---
interface Props {
  name: string;
}

const { name } = Astro.props;
---
<h1 class="wordmark">{name}<span class="dot" aria-hidden="true">.</span></h1>
```

- [ ] **Step 3: Append the header rules to `site/src/styles/site.css`**

```css
/* ---- header ---- */

.eyebrow {
  font-family: var(--mono);
  font-size: .72rem;
  letter-spacing: .2em;
  text-transform: uppercase;
  color: var(--accent-text);
  margin: 0 0 16px;
  display: flex;
  justify-content: space-between;
  gap: 12px;
}
.eyebrow .idx { color: var(--ink-dim); }

.head {
  display: grid;
  grid-template-columns: 104px 1fr;
  gap: 0 26px;
  align-items: start;
}

.portrait {
  width: 104px;
  height: 120px;
  border: 1px solid var(--line);
  background: var(--panel-2);
  background-image: repeating-linear-gradient(
    135deg, rgba(0,0,0,.035) 0 6px, transparent 6px 12px
  );
  position: relative;
}
.portrait span {
  position: absolute;
  bottom: 6px;
  left: 7px;
  font-family: var(--mono);
  font-size: .55rem;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-dim);
}

.wordmark {
  font-family: var(--display);
  font-weight: 400;
  font-synthesis: none;
  text-transform: uppercase;
  font-size: clamp(2.6rem, 1.6rem + 4vw, 4.4rem);
  line-height: .86;
  letter-spacing: .01em;
  margin: -8px 0 0;
  color: var(--ink);
}
.wordmark .dot { color: var(--accent); }

.role {
  font-weight: 650;
  font-size: clamp(1.05rem, .95rem + .6vw, 1.32rem);
  letter-spacing: -.01em;
  margin: 14px 0 16px;
  max-width: 34ch;
}

.meta {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin: 0;
}
.badge {
  font-family: var(--mono);
  font-size: .68rem;
  letter-spacing: .07em;
  text-transform: uppercase;
  padding: 3px 9px;
  border: 1px solid var(--line);
  color: var(--ink-dim);
  background: var(--panel);
}
.badge--accent {
  color: var(--accent-text);
  border-color: var(--accent-border);
  background: var(--accent-soft);
}
.badge--rec {
  color: var(--rec);
  border-color: var(--rec-border);
  background: var(--rec-soft);
}
.badge--warn {
  color: var(--warn);
  border-color: var(--warn-border);
  background: var(--warn-soft);
}

.links {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-top: 14px;
}
.links a {
  font-family: var(--mono);
  font-size: .64rem;
  letter-spacing: .09em;
  text-transform: uppercase;
  color: var(--ink-dim);
  border: 1px solid var(--line);
  background: var(--panel);
  padding: 6px 11px;
  text-decoration: none;
}
.links a:hover {
  color: var(--accent-text);
  border-color: var(--accent-border);
}
```

`.links` is styled now even though `site.yml` ships an empty array, so adding a link later is a content edit with no CSS work.

- [ ] **Step 4: Update `site/src/pages/index.astro`**

```astro
---
import Base from '../layouts/Base.astro';
import Eyebrow from '../components/Eyebrow.astro';
import Wordmark from '../components/Wordmark.astro';
import { getEntry } from 'astro:content';

const site = await getEntry('site', 'site');
if (!site) throw new Error('src/content/site.yml is missing');
const { name, role, portraitInitials, eyebrowLeft, eyebrowRight, badges, links } = site.data;
---
<Base title={name} description={role}>
  <Eyebrow left={eyebrowLeft} right={eyebrowRight} />

  <header class="head">
    <div class="portrait"><span>{portraitInitials}</span></div>
    <div>
      <Wordmark name={name} />
      <p class="role">{role}</p>
      <div class="meta">
        {badges.map(b => <span class={`badge badge--${b.kind}`}>{b.text}</span>)}
      </div>
      {links.length > 0 && (
        <div class="links">
          {links.map(l => <a href={l.href}>{l.label}</a>)}
        </div>
      )}
    </div>
  </header>
</Base>
```

- [ ] **Step 5: Verify visually**

Run from `site/`: `npm run dev`, then open the printed localhost URL.

Expected: the Anton wordmark reads "PHIL NGUYEN." with an orange period, four badges with Infrastructure in accent styling, a hatched portrait panel showing "PN", and no link row.

- [ ] **Step 6: Commit**

```bash
git add site/src/components/Eyebrow.astro site/src/components/Wordmark.astro site/src/styles/site.css site/src/pages/index.astro
git commit -m "Task 6: header with eyebrow, wordmark, badges"
```

---

### Task 7: About section and the Stub component

**Files:**
- Create: `site/src/components/SectionHead.astro`
- Create: `site/src/components/Stub.astro`
- Modify: `site/src/pages/index.astro`
- Modify: `site/src/styles/site.css` (append)

**Interfaces:**
- Consumes: the `about` collection entry from Task 3
- Produces: `SectionHead` accepting `{ index: string; kicker: string; heading: string; id?: string }`, `Stub` accepting `{ file: string }` and wrapping a default slot

- [ ] **Step 1: Create `site/src/components/SectionHead.astro`**

```astro
---
interface Props {
  index: string;
  kicker: string;
  heading: string;
  id?: string;
}

const { index, kicker, heading, id } = Astro.props;
---
<p class="kicker">{index} &middot; {kicker}</p>
<h2 id={id}>{heading}</h2>
```

- [ ] **Step 2: Create `site/src/components/Stub.astro`**

```astro
---
interface Props {
  file: string;
}

const { file } = Astro.props;
---
<div class="stub">
  <span class="stub-tag">Placeholder &middot; {file}</span>
  <slot />
</div>
```

- [ ] **Step 3: Append the section and stub rules to `site/src/styles/site.css`**

```css
/* ---- sections ---- */

section { margin-top: 44px; }

.kicker {
  font-family: var(--mono);
  font-size: .72rem;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--ink-dim);
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 14px;
}
.kicker::before {
  content: "\00BB";
  color: var(--accent);
  font-size: 1rem;
}

h2 {
  font-family: var(--display);
  font-weight: 400;
  font-synthesis: none;
  text-transform: uppercase;
  font-size: 1.5rem;
  letter-spacing: .01em;
  margin: 0 0 14px;
  color: var(--ink);
}

.prose p {
  margin: 0 0 14px;
  max-width: 68ch;
  color: var(--ink-dim);
}
.prose strong { color: var(--ink); font-weight: 650; }
.prose p:last-child { margin-bottom: 0; }

/* ---- placeholder frame ---- */

.stub {
  border: 1px dashed var(--line);
  padding: 16px 18px;
  color: var(--ink-dim);
}
.stub-tag {
  font-family: var(--mono);
  font-size: .62rem;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-dim);
  display: block;
  margin-bottom: 9px;
}
```

- [ ] **Step 4: Update `site/src/pages/index.astro`**

Add these imports below the existing ones:

```ts
import SectionHead from '../components/SectionHead.astro';
import Stub from '../components/Stub.astro';
import { render } from 'astro:content';
```

Add this below the `site` lookup in the frontmatter:

```ts
const about = await getEntry('about', 'about');
if (!about) throw new Error('src/content/about.md is missing');
const { Content: AboutContent } = await render(about);
```

Add this section after the closing `</header>`:

```astro
  <section id="about">
    <SectionHead index="01" kicker="About" heading="About" />
    {about.data.placeholder ? (
      <Stub file="src/content/about.md">
        <div class="prose"><AboutContent /></div>
      </Stub>
    ) : (
      <div class="prose"><AboutContent /></div>
    )}
  </section>
```

- [ ] **Step 5: Verify**

Run from `site/`: `npm run build`

Expected: build succeeds. Open `npm run dev` and confirm the About section shows a dashed frame labelled `Placeholder · src/content/about.md` wrapping the placeholder prose.

Then flip `placeholder: false` in `about.md`, reload, and confirm the dashed frame disappears and the prose renders plainly. Set it back to `true` before committing.

- [ ] **Step 6: Commit**

```bash
git add site/src/components/SectionHead.astro site/src/components/Stub.astro site/src/styles/site.css site/src/pages/index.astro
git commit -m "Task 7: About section and the placeholder frame

The placeholder boolean is the only switch. Populated content renders
through the same path with the frame omitted."
```

---

### Task 8: Project cards

**Files:**
- Create: `site/src/components/ProjectCard.astro`
- Modify: `site/src/pages/index.astro`
- Modify: `site/src/styles/site.css` (append)

**Interfaces:**
- Consumes: `sortProjects` from Task 2, the `projects` collection from Task 3, `SectionHead` and `Stub` from Task 7
- Produces: `ProjectCard` accepting `{ entry: CollectionEntry<'projects'>; index: number }`

- [ ] **Step 1: Create `site/src/components/ProjectCard.astro`**

```astro
---
import { Image } from 'astro:assets';
import type { CollectionEntry } from 'astro:content';

interface Props {
  entry: CollectionEntry<'projects'>;
  index: number;
}

const { entry, index } = Astro.props;
const { title, blurb, stack, year, thumb, live, repo, placeholder } = entry.data;
const idx = String(index).padStart(2, '0');
---
<article class:list={['card', { 'card--stub': placeholder }]}>
  <div class="thumb">
    {thumb
      ? <Image src={thumb} alt="" width={640} height={360} loading="lazy" />
      : <em class="thumb-empty">no image yet</em>
    }
    <i class="thumb-idx" aria-hidden="true">{idx}</i>
  </div>
  <div class="card-body">
    <h3>{title}</h3>
    <p class="blurb">{blurb}</p>
    <div class="chips">
      {stack.map(s => <span class="chip">{s}</span>)}
      <span class="chip chip--year">{year}</span>
    </div>
    {(live || repo) && (
      <div class="card-links">
        {live && <a href={live} class="card-link card-link--live">Live</a>}
        {repo && <a href={repo} class="card-link">Source</a>}
      </div>
    )}
  </div>
</article>
```

The Live and Source links are derived from which URLs exist. There is no `type` field, and the schema's `refine` guarantees at least one is present.

- [ ] **Step 2: Append the card rules to `site/src/styles/site.css`**

```css
/* ---- project cards ---- */

.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
}

.card {
  border: 1px solid var(--line);
  background: var(--panel);
  display: flex;
  flex-direction: column;
}
.card--stub {
  border-style: dashed;
  background: transparent;
}

.thumb {
  aspect-ratio: 16 / 9;
  background: var(--panel-2);
  border-bottom: 1px solid var(--line);
  position: relative;
  overflow: hidden;
  background-image:
    repeating-linear-gradient(0deg, rgba(0,0,0,.03) 0 1px, transparent 1px 14px),
    repeating-linear-gradient(90deg, rgba(0,0,0,.03) 0 1px, transparent 1px 14px);
}
.card--stub .thumb { border-bottom-style: dashed; }
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.thumb-idx {
  position: absolute;
  top: 8px;
  left: 10px;
  font-style: normal;
  font-family: var(--mono);
  font-size: .62rem;
  letter-spacing: .14em;
  color: var(--accent-text);
}
.thumb-empty {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  font-style: normal;
  font-family: var(--mono);
  font-size: .62rem;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-dim);
}

.card-body {
  padding: 13px 15px 15px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.card-body h3 {
  font-size: 1rem;
  font-weight: 650;
  margin: 0;
  letter-spacing: -.005em;
  color: var(--ink);
}
.blurb {
  font-size: .86rem;
  color: var(--ink-dim);
  margin: 0 0 7px;
  line-height: 1.5;
}

.chips { display: flex; gap: 5px; flex-wrap: wrap; }
.chip {
  font-family: var(--mono);
  font-size: .6rem;
  letter-spacing: .08em;
  text-transform: uppercase;
  color: var(--ink-dim);
  border: 1px solid var(--line);
  padding: 2px 6px;
}
.chip--year { font-variant-numeric: tabular-nums; }

.card-links { display: flex; gap: 8px; margin-top: 10px; }
.card-link {
  font-family: var(--mono);
  font-size: .62rem;
  letter-spacing: .1em;
  text-transform: uppercase;
  color: var(--ink-dim);
  border: 1px solid var(--line);
  padding: 3px 8px;
  text-decoration: none;
}
.card-link:hover { color: var(--accent-text); border-color: var(--accent-border); }
.card-link--live {
  color: var(--accent-text);
  border-color: var(--accent-border);
  background: var(--accent-soft);
}
```

- [ ] **Step 3: Update `site/src/pages/index.astro`**

Add these imports:

```ts
import ProjectCard from '../components/ProjectCard.astro';
import { getCollection } from 'astro:content';
import { sortProjects } from '../lib/sortProjects';
```

Add this to the frontmatter:

```ts
const projects = sortProjects(await getCollection('projects'));
const allPlaceholder = projects.length > 0 && projects.every(p => p.data.placeholder);
```

Add this section after the About section:

```astro
  <section id="work">
    <SectionHead index="02" kicker="Selected work" heading="Stuff I've made" />
    <div class="grid">
      {projects.map((entry, i) => <ProjectCard entry={entry} index={i + 1} />)}
    </div>
    {allPlaceholder && (
      <div class="stub" style="margin-top:16px">
        <span class="stub-tag">Placeholder &middot; src/content/projects/</span>
        Drop a markdown file per project in this folder. Each one becomes a card.
        Delete these stubs once you have real entries.
      </div>
    )}
  </section>
```

- [ ] **Step 4: Verify**

Run from `site/`: `npm run build && npm run dev`

Expected: two dashed cards, each showing "no image yet", a mono index, a Source link, and a stack chip plus a year chip. Below the grid, a dashed note naming `src/content/projects/`.

- [ ] **Step 5: Verify a populated card**

Temporarily edit `project-one.md`: set `placeholder: false`, change `title` to `Real project`, and add `live: https://example.com`.

Run `npm run dev`. Expected: card one has a solid border, both a Live and a Source link, and the grid note disappears (because not every entry is a placeholder now). Revert the edits before committing.

- [ ] **Step 6: Commit**

```bash
git add site/src/components/ProjectCard.astro site/src/styles/site.css site/src/pages/index.astro
git commit -m "Task 8: project cards with derived link chips

Live and Source chips come from which URLs exist rather than a type
field, so there is one source of truth."
```

---

### Task 9: Responsive collapse

**Files:**
- Modify: `site/src/styles/site.css` (append)

**Interfaces:**
- Consumes: every rule from Tasks 5 through 8
- Produces: nothing new

- [ ] **Step 1: Append the breakpoint to `site/src/styles/site.css`**

```css
/* ---- narrow ---- */

@media (max-width: 640px) {
  .wrap { padding: 44px 18px 70px; }

  .head {
    grid-template-columns: 1fr;
    gap: 18px 0;
  }
  .portrait { width: 88px; height: 100px; }

  .grid { grid-template-columns: 1fr; }

  .eyebrow {
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }
}

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; }
}
```

- [ ] **Step 2: Verify at narrow width**

Run `npm run dev`, open dev tools, and set the viewport to 375px wide.

Expected: the portrait sits above the wordmark rather than beside it, cards stack one across, the eyebrow wraps to two lines, and no horizontal scrollbar appears.

- [ ] **Step 3: Commit**

```bash
git add site/src/styles/site.css
git commit -m "Task 9: responsive collapse at 640px"
```

---

### Task 10: Accessibility check in both themes

**Files:**
- Create: `site/playwright.config.ts`
- Create: `site/tests/a11y.spec.ts`
- Modify: `site/package.json` (devDependencies)

**Interfaces:**
- Consumes: the built site from Tasks 5 through 9
- Produces: `npm run test:a11y` passing with zero axe violations in both color schemes

**Why Playwright rather than `@axe-core/cli`,** which the spec named: the whole point of this check is the contrast overrides from Task 4, and verifying dark mode requires emulating `prefers-color-scheme: dark`. `@axe-core/cli` has no way to set that. jsdom is also disqualified, because axe's color-contrast rule needs real rendering and jsdom does not compute it.

- [ ] **Step 1: Install the dependencies**

Run from `site/`:

```
npm install -D @playwright/test @axe-core/playwright
npx playwright install chromium
```

- [ ] **Step 2: Create `site/playwright.config.ts`**

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  webServer: {
    command: 'npm run build && npm run preview',
    url: 'http://localhost:4321',
    reuseExistingServer: false,
    timeout: 120_000,
  },
  use: { baseURL: 'http://localhost:4321' },
});
```

- [ ] **Step 3: Write the failing test**

Create `site/tests/a11y.spec.ts`:

```ts
import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

for (const colorScheme of ['light', 'dark'] as const) {
  test(`no axe violations in ${colorScheme} mode`, async ({ page }) => {
    await page.emulateMedia({ colorScheme });
    await page.goto('/');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });
}

test('the built page ships no JavaScript', async ({ page }) => {
  const scripts: string[] = [];
  page.on('response', r => {
    if (r.url().endsWith('.js')) scripts.push(r.url());
  });
  await page.goto('/');
  const inline = await page.locator('script').count();

  expect(scripts).toEqual([]);
  expect(inline).toBe(0);
});
```

- [ ] **Step 4: Run it**

Run from `site/`: `npm run test:a11y`

Expected: all three tests PASS. If a contrast violation appears, the token values in Task 4 are wrong and get fixed there, not worked around here.

- [ ] **Step 5: Commit**

```bash
git add site/playwright.config.ts site/tests/ site/package.json site/package-lock.json
git commit -m "Task 10: axe check in both color schemes plus a zero-JS assertion

Playwright rather than @axe-core/cli because verifying the dark-mode
contrast overrides requires emulating prefers-color-scheme, which the
CLI cannot do."
```

---

## Definition of done

Every box above is checked, and from `site/`:

- `npm run check` reports no errors
- `npm run test` passes
- `npm run test:a11y` passes
- `npm run build` succeeds and `dist/` contains no `.js` files
- The rendered page matches `mockups/skeleton-state.html` in light mode
- A dark-mode preview has been produced and approved, per the spec's verification section

Spec success criteria 1 through 3 and 8 depend on the infrastructure and are verified by the separate Terraform plan.
