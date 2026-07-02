/// <reference types="@cloudflare/workers-types" />

/**
 * Cloudflare Pages Function: authenticated PDF deletion from R2.
 * Verifies the Supabase session, then deletes the object by key.
 */

interface Env {
  PAPERS_BUCKET: R2Bucket;
  SUBMISSIONS_BUCKET: R2Bucket;
  PUBLIC_SUPABASE_URL: string;
  PUBLIC_SUPABASE_ANON_KEY: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

export const onRequestOptions: PagesFunction<Env> = async () =>
  new Response(null, { headers: corsHeaders });

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const { request, env } = context;

  const token = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'Missing authentication token.' }, 401);

  try {
    const userRes = await fetch(`${env.PUBLIC_SUPABASE_URL}/auth/v1/user`, {
      headers: { Authorization: `Bearer ${token}`, apikey: env.PUBLIC_SUPABASE_ANON_KEY },
    });
    if (!userRes.ok) return json({ error: 'Invalid or expired session.' }, 401);
  } catch {
    return json({ error: 'Could not verify session.' }, 401);
  }

  let body: { key?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400);
  }

  const key = (body.key || '').replace(/^\/+/, '');
  if (!key) return json({ error: 'No key provided.' }, 400);

  try {
    const isSubmission = key.startsWith('submissions/');
    if (isSubmission) {
      await env.SUBMISSIONS_BUCKET.delete(key);
    } else {
      await env.PAPERS_BUCKET.delete(key);
    }
  } catch (err) {
    return json({ error: `Delete failed: ${(err as Error).message}` }, 500);
  }

  return json({ ok: true });
};
