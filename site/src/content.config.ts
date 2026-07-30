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
