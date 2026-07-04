import { defineConfig } from 'astro/config';
import preact from '@astrojs/preact';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
  site: 'https://mdupapers.com', // Replace with actual domain
  integrations: [
    preact(),
    sitemap({
      filter: (page) => !page.includes('/search') && !page.includes('/seo-preview'),
    }),
  ],
  output: 'static', // Static Site Generation (SSG)
  trailingSlash: 'always',
  prefetch: {
    prefetchAll: true,
    defaultStrategy: 'viewport',
  },
});
