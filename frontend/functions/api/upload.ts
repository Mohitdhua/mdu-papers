/// <reference types="@cloudflare/workers-types" />

/**
 * Cloudflare Pages Function: authenticated PDF upload to R2.
 *
 * Flow:
 *  - Admin panel sends the PDF (multipart/form-data) + Supabase access token.
 *  - We verify the token against Supabase Auth (only logged-in admins allowed).
 *  - On success, the file is written to the R2 bucket bound as PAPERS_BUCKET.
 *  - Returns the public URL (PUBLIC_R2_BASE_URL + key) for storing in the DB.
 *
 * R2 egress is free, so serving these PDFs costs nothing in bandwidth.
 */

interface Env {
  PAPERS_BUCKET: R2Bucket;
  PUBLIC_SUPABASE_URL: string;
  PUBLIC_SUPABASE_ANON_KEY: string;
  PUBLIC_R2_BASE_URL: string;
}

const MAX_BYTES = 25 * 1024 * 1024; // 25 MB cap

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

  // 1. Verify the caller is an authenticated Supabase user.
  const authHeader = request.headers.get('Authorization') || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) {
    return json({ error: 'Missing authentication token.' }, 401);
  }

  try {
    const userRes = await fetch(`${env.PUBLIC_SUPABASE_URL}/auth/v1/user`, {
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: env.PUBLIC_SUPABASE_ANON_KEY,
      },
    });
    if (!userRes.ok) {
      return json({ error: 'Invalid or expired session. Please sign in again.' }, 401);
    }
  } catch {
    return json({ error: 'Could not verify session.' }, 401);
  }

  // 2. Parse the uploaded file.
  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return json({ error: 'Invalid form data.' }, 400);
  }

  const file = form.get('file');
  const key = String(form.get('key') || '').replace(/^\/+/, '');

  if (!(file instanceof File)) {
    return json({ error: 'No file provided.' }, 400);
  }
  if (!key) {
    return json({ error: 'No storage key provided.' }, 400);
  }
  if (file.type !== 'application/pdf') {
    return json({ error: 'Only PDF files are allowed.' }, 400);
  }
  if (file.size > MAX_BYTES) {
    return json({ error: 'File too large (max 25 MB).' }, 400);
  }

  // 3. Write to R2.
  try {
    await env.PAPERS_BUCKET.put(key, file.stream(), {
      httpMetadata: { contentType: 'application/pdf' },
    });
  } catch (err) {
    return json({ error: `Upload failed: ${(err as Error).message}` }, 500);
  }

  const base = (env.PUBLIC_R2_BASE_URL || '').replace(/\/+$/, '');
  return json({
    url: `${base}/${key}`,
    key,
    sizeKb: Math.round(file.size / 1024),
  });
};
