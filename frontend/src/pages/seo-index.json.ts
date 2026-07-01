import type { APIRoute } from 'astro';
import { buildSeoIndex } from '@lib/seoData';

/** Static JSON of every page's SEO metadata, consumed by the SERP preview tool.
 *  Dev-only: not exposed in production builds. */
export const GET: APIRoute = async () => {
  if (import.meta.env.PROD) {
    return new Response('Not found', { status: 404 });
  }
  const index = await buildSeoIndex();
  return new Response(JSON.stringify(index), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
};
