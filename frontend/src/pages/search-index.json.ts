import type { APIRoute } from 'astro';
import { buildSearchIndex } from '@lib/data';

/** Generates a static search-index.json at build time for client-side fuzzy search. */
export const GET: APIRoute = async () => {
  const index = await buildSearchIndex();
  return new Response(JSON.stringify(index), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
