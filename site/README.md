# Developer site

A single-page static site built with Astro, served from S3 behind CloudFront.
The built page ships no JavaScript.

## Commands

Run from this directory.

```
npm run dev        local server with hot reload
npm run build      emits dist/
npm run check      astro check: type errors and diagnostics
npm test           vitest, covering the one pure function
npm run test:a11y  playwright and axe, in both color schemes
```

`npm run test:a11y` drives a real browser. Install it once with
`npx playwright install chromium`; `npm ci` does not.

**Node 22.12 or newer.** Astro 7 requires it, and support for 18 and 20 was
dropped in v6.

## Publishing

Everything you edit lives in `src/content/`.

| File | Holds |
|---|---|
| `site.yml` | name, role line, eyebrow text, badges, links |
| `about.md` | the About prose |
| `projects/*.md` | one file per card |

A project needs `title`, `blurb`, `stack`, `year`, and `order`. Number `order`
sparsely by tens so you can insert an entry between two others without
renumbering the rest. `year` is displayed but never sorted on, which is what
lets you lead with an older project.

Give it a `live` URL, a `repo` URL, or both, and the card renders whichever
links exist. There is no type field. Both must be `https`.

Drop a `thumb` image beside the markdown to replace the blueprint placeholder.
Images have to live under `src/` to be optimized; `public/` files are copied
untouched.

Set `placeholder: false` on `about.md` or a project to drop its dashed frame.

A schema error fails the build rather than rendering a broken card, so a typo
in a frontmatter key is caught before it ships.

## Design

`../docs/specs/0001-developer-site.md` is the authoritative design.
`../docs/adr/` records each decision, what it beat, and why.

The palette is a second implementation of a table owned by another project.
Do not change a value in `src/styles/tokens.css` without reading
`../docs/adr/0004-visual-identity-port.md` first.
