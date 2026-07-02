/// <reference types="@cloudflare/workers-types" />

/**
 * Cloudflare Pages Function: Authenticated student paper approval.
 *
 * Flow:
 *  - Verifies the administrator's Supabase session token.
 *  - Reads the paperId from the POST request body.
 *  - Queries Supabase to fetch the paper's current path, course slug, semester, and subject slug.
 *  - If the paper's R2 key is in the "submissions/" folder:
 *     - Computes the target organized path: e.g. "bca/sem-1/mathematics-i-nov-dec-2024.pdf".
 *     - Copies the object inside the R2 bucket to the new organized path.
 *     - Deletes the temporary file from the "submissions/" directory.
 *     - Updates Supabase with the new URL, new R2 key, and is_verified = true.
 *  - If already organized:
 *     - Simply sets is_verified = true.
 */

interface Env {
  PAPERS_BUCKET: R2Bucket;
  PUBLIC_SUPABASE_URL: string;
  PUBLIC_SUPABASE_ANON_KEY: string;
  PUBLIC_R2_BASE_URL: string;
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

// Slugify helper matching frontend utility exactly
function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

export const onRequestOptions: PagesFunction<Env> = async () =>
  new Response(null, { headers: corsHeaders });

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const { request, env } = context;

  // 1. Verify caller is an authenticated administrator
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

  // 2. Parse request body
  let body: { paperId?: number };
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400);
  }

  const { paperId } = body;
  if (!paperId) {
    return json({ error: 'Missing paperId parameter.' }, 400);
  }

  const supabaseHeaders = {
    'apikey': env.PUBLIC_SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${env.PUBLIC_SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  try {
    // 3. Fetch paper along with its nested subject and course metadata
    const fetchPaperUrl = `${env.PUBLIC_SUPABASE_URL}/rest/v1/papers?id=eq.${paperId}&select=*,subject:subjects(*,course:courses(*))`;
    const paperRes = await fetch(fetchPaperUrl, { headers: supabaseHeaders });
    
    if (!paperRes.ok) {
      return json({ error: 'Failed to fetch paper details from database.' }, 500);
    }

    const papers = await paperRes.json() as any[];
    if (!papers || papers.length === 0) {
      return json({ error: 'Paper not found in database.' }, 404);
    }

    const paper = papers[0];
    const { r2_key, year, exam_session, subject } = paper;
    
    if (!subject || !subject.course) {
      return json({ error: 'Paper subject or course relations are missing.' }, 400);
    }

    const courseSlug = subject.course.slug;
    const semester = subject.semester;
    const subjectSlug = subject.slug;

    // Check if the file is in submissions or already organized
    const isTemporary = r2_key && r2_key.startsWith('submissions/');

    let finalR2Key = r2_key;
    let finalPdfUrl = paper.pdf_url;

    // 4. File-moving inside R2 if the paper key is temporary
    if (isTemporary) {
      const sessionSlug = slugify(exam_session);
      const targetKey = `${courseSlug}/sem-${semester}/${subjectSlug}-${sessionSlug}-${year}.pdf`;

      // Copy file within R2
      try {
        await env.PAPERS_BUCKET.copy(r2_key, targetKey);
      } catch (copyErr) {
        console.error('[approve-api] R2 copy failed:', copyErr);
        return json({ error: `Failed to move file to organized folder: ${(copyErr as Error).message}` }, 500);
      }

      // Delete the old file from submissions folder in R2
      try {
        await env.PAPERS_BUCKET.delete(r2_key);
      } catch (delErr) {
        console.warn('[approve-api] R2 source deletion failed (non-blocking):', delErr);
      }

      finalR2Key = targetKey;
      const baseR2Url = (env.PUBLIC_R2_BASE_URL || '').replace(/\/+$/, '');
      finalPdfUrl = `${baseR2Url}/${targetKey}`;
    }

    // 5. Update database record to make it verified and link to the new path
    const updateRes = await fetch(`${env.PUBLIC_SUPABASE_URL}/rest/v1/papers?id=eq.${paperId}`, {
      method: 'PATCH',
      headers: supabaseHeaders,
      body: JSON.stringify({
        is_verified: true,
        pdf_url: finalPdfUrl,
        r2_key: finalR2Key,
      }),
    });

    if (!updateRes.ok) {
      const errMsg = await updateRes.text();
      console.error('[approve-api] Database update failed:', errMsg);
      return json({ error: 'Failed to update paper verification status in database.' }, 500);
    }

    return json({
      success: true,
      message: 'Paper approved and sorted successfully!',
      r2Key: finalR2Key,
      pdfUrl: finalPdfUrl,
    });
  } catch (err) {
    console.error('[approve-api] Exception caught:', err);
    return json({ error: `Approval failed: ${(err as Error).message}` }, 500);
  }
};
