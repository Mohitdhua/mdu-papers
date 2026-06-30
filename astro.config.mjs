import { defineConfig } from 'astro/config';
import preact from '@astrojs/preact';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
  site: 'https://mdupapers.com', // Replace with actual domain
  integrations: [preact(), sitemap()],
  output: 'static', // Static Site Generation (SSG)
  prefetch: {
    prefetchAll: true,
    defaultStrategy: 'viewport',
  },
});
