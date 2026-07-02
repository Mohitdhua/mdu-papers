/// <reference types="@cloudflare/workers-types" />

/**
 * Cloudflare Pages Function: Public PDF paper submission (Contribute).
 *
 * Flow:
 *  - User uploads a PDF and metadata (course_id, semester, subject_id / custom_subject_name, year, session).
 *  - We validate that the file is a PDF and under 10MB.
 *  - We write the file to the R2 bucket under "submissions/[uuid].pdf".
 *  - We insert the record into Supabase as unverified (is_verified = false, uploaded_by = 'student').
 *  - If custom_subject_name is provided, we create a new subject (with paper_count = 0) first, then insert.
 */

interface Env {
  PAPERS_BUCKET: R2Bucket;
  PUBLIC_SUPABASE_URL: string;
  PUBLIC_SUPABASE_ANON_KEY: string;
  PUBLIC_R2_BASE_URL: string;
}

const MAX_BYTES = 10 * 1024 * 1024; // 10 MB cap for public uploads

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
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

  // 1. Parse the uploaded data
  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return json({ error: 'Invalid form data.' }, 400);
  }

  const file = form.get('file');
  const courseId = Number(form.get('course_id'));
  const semester = Number(form.get('semester'));
  const subjectIdVal = form.get('subject_id');
  const customSubjectName = String(form.get('custom_subject_name') || '').trim();
  const year = Number(form.get('year'));
  const examSession = String(form.get('exam_session') || '').trim();
  const pageCountVal = form.get('page_count');
  const topics = String(form.get('topics') || '').trim();

  // Basic validation
  if (!(file instanceof File)) {
    return json({ error: 'No PDF file provided.' }, 400);
  }
  if (file.type !== 'application/pdf') {
    return json({ error: 'Only PDF files are allowed.' }, 400);
  }
  if (file.size > MAX_BYTES) {
    return json({ error: 'File is too large (max 10 MB).' }, 400);
  }
  if (!courseId || !semester || !year || !examSession) {
    return json({ error: 'Missing required metadata (course, semester, year, or session).' }, 400);
  }

  // Validate session choice
  const validSessions = ['May/June', 'Nov/Dec', 'Supplementary', 'Re-appear'];
  if (!validSessions.includes(examSession)) {
    return json({ error: 'Invalid exam session.' }, 400);
  }

  const uuid = crypto.randomUUID();
  const r2Key = `submissions/${uuid}.pdf`;

  // 2. Write file to Cloudflare R2
  try {
    await env.PAPERS_BUCKET.put(r2Key, file.stream(), {
      httpMetadata: { contentType: 'application/pdf' },
    });
  } catch (err) {
    return json({ error: `Storage upload failed: ${(err as Error).message}` }, 500);
  }

  const baseR2Url = (env.PUBLIC_R2_BASE_URL || '').replace(/\/+$/, '');
  const pdfUrl = `${baseR2Url}/${r2Key}`;
  const sizeKb = Math.round(file.size / 1024);
  const pageCount = pageCountVal ? Number(pageCountVal) : null;

  // 3. Supabase REST API helper functions
  const headers = {
    'apikey': env.PUBLIC_SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${env.PUBLIC_SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  try {
    let finalSubjectId = subjectIdVal ? Number(subjectIdVal) : null;

    // 4. Handle custom subject if subject_id is not specified
    if (!finalSubjectId && customSubjectName) {
      // Generate standard slug for the suggested subject
      const subjectSlug = customSubjectName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');

      if (!subjectSlug) {
        return json({ error: 'Invalid custom subject name.' }, 400);
      }

      // Check if a subject with this slug already exists for this course + semester
      const checkRes = await fetch(
        `${env.PUBLIC_SUPABASE_URL}/rest/v1/subjects?course_id=eq.${courseId}&semester=eq.${semester}&slug=eq.${subjectSlug}`,
        { headers }
      );
      
      if (checkRes.ok) {
        const existingSubjects = await checkRes.json() as { id: number }[];
        if (existingSubjects && existingSubjects.length > 0) {
          finalSubjectId = existingSubjects[0].id;
        }
      }

      // If not found, create new unverified subject (starts with paper_count = 0)
      if (!finalSubjectId) {
        const createSubjRes = await fetch(`${env.PUBLIC_SUPABASE_URL}/rest/v1/subjects`, {
          method: 'POST',
          headers,
          body: JSON.stringify({
            course_id: courseId,
            semester,
            name: customSubjectName,
            slug: subjectSlug,
            paper_count: 0,
          }),
        });

        if (!createSubjRes.ok) {
          const errMsg = await createSubjRes.text();
          console.error('[submit-api] Subject creation failed:', errMsg);
          return json({ error: 'Failed to create new subject in database.' }, 500);
        }

        const createdSubjects = await createSubjRes.json() as { id: number }[];
        if (createdSubjects && createdSubjects.length > 0) {
          finalSubjectId = createdSubjects[0].id;
        } else {
          return json({ error: 'Subject creation did not return any records.' }, 500);
        }
      }
    }

    if (!finalSubjectId) {
      return json({ error: 'Please select a subject or provide a custom subject name.' }, 400);
    }

    // 5. Insert paper row into papers table
    const createPaperRes = await fetch(`${env.PUBLIC_SUPABASE_URL}/rest/v1/papers`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        subject_id: finalSubjectId,
        year,
        exam_session: examSession,
        pdf_url: pdfUrl,
        r2_key: r2Key,
        topics: topics || null,
        pdf_size_kb: sizeKb,
        page_count: pageCount,
        is_verified: false, // Must be unverified
        uploaded_by: 'student', // Public submission
      }),
    });

    if (!createPaperRes.ok) {
      const errMsg = await createPaperRes.text();
      console.error('[submit-api] Paper creation failed:', errMsg);
      return json({ error: 'Failed to save paper metadata to database.' }, 500);
    }

    return json({
      success: true,
      message: 'Paper submitted successfully! Pending admin approval.',
      pdfUrl,
    });
  } catch (err) {
    console.error('[submit-api] Exception caught:', err);
    return json({ error: `Submission failed: ${(err as Error).message}` }, 500);
  }
};
