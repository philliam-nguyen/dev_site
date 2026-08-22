import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://phillip-nguyen.dev',
  build: {
    format: 'file',
    // Pinned: 'auto' flips to an inline <style> under ~4 kB, which would
    // silently invalidate style-src 'self' in the CloudFront CSP.
    inlineStylesheets: 'never',
  },
});
