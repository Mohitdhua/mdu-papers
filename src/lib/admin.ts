import { createClient, type SupabaseClient, type Session } from '@supabase/supabase-js';
import type { Course, Subject, Paper, DegreeType, ExamSession, Solution, BlogPost } from './types';

/**
 * Browser-side Supabase client and admin operations for the upload panel.
 * This runs entirely in the user's browser (the site is static), authenticated
 * via Supabase Auth. RLS policies restrict writes to authenticated users.
 */

const url = import.meta.env.PUBLIC_SUPABASE_URL;
const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export const adminConfigured: boolean = Boolean(
  url && anonKey && !url.includes('your-project') && !anonKey.includes('your-anon-key')
);

let _client: SupabaseClient | null = null;
export function getClient(): SupabaseClient {
  if (!_client) {
    if (!adminConfigured) {
      throw new Error(
        'Supabase is not configured. Set PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY in your .env file.'
      );
    }
    _client = createClient(url, anonKey, {
      auth: { persistSession: true, autoRefreshToken: true },
    });
  }
  return _client;
}

/** Cloudflare R2 serves the PDFs (zero egress cost). Uploads go through the
 *  authenticated /api/upload Pages Function. */

// ---------- Auth ----------

export async function getSession(): Promise<Session | null> {
  const { data } = await getClient().auth.getSession();
  return data.session;
}

export async function signIn(email: string, password: string) {
  return getClient().auth.signInWithPassword({ email, password });
}

export async function signOut() {
  return getClient().auth.signOut();
}

export function onAuthChange(cb: (session: Session | null) => void) {
  return getClient().auth.onAuthStateChange((_event, session) => cb(session));
}

// ---------- Courses ----------

export async function listCourses(): Promise<Course[]> {
  const { data, error } = await getClient().from('courses').select('*').order('name');
  if (error) throw error;
  return (data as Course[]) ?? [];
}

export async function createCourse(input: Omit<Course, 'id' | 'created_at' | 'paper_count'>) {
  return getClient().from('courses').insert(input).select().single();
}

export async function deleteCourse(id: number) {
  return getClient().from('courses').delete().eq('id', id);
}

// ---------- Subjects ----------

export async function listSubjects(courseId?: number): Promise<Subject[]> {
  let q = getClient().from('subjects').select('*').order('semester');
  if (courseId) q = q.eq('course_id', courseId);
  const { data, error } = await q;
  if (error) throw error;
  return (data as Subject[]) ?? [];
}

export async function createSubject(
  input: Omit<Subject, 'id' | 'created_at' | 'paper_count'>
) {
  return getClient().from('subjects').insert(input).select().single();
}

export async function deleteSubject(id: number) {
  return getClient().from('subjects').delete().eq('id', id);
}

// ---------- Papers ----------

export async function listPapers(subjectId?: number): Promise<Paper[]> {
  let q = getClient().from('papers').select('*').order('year', { ascending: false });
  if (subjectId) q = q.eq('subject_id', subjectId);
  const { data, error } = await q;
  if (error) throw error;
  return (data as Paper[]) ?? [];
}

export async function createPaper(input: {
  subject_id: number;
  year: number;
  exam_session: ExamSession;
  pdf_url: string;
  r2_key: string | null;
  topics: string | null;
  pdf_size_kb: number | null;
  page_count: number | null;
  is_verified: boolean;
}) {
  return getClient().from('papers').insert(input).select().single();
}

export async function deletePaper(id: number) {
  return getClient().from('papers').delete().eq('id', id);
}

/** Get the current user's access token (for authenticating R2 function calls). */
async function getAccessToken(): Promise<string> {
  const { data } = await getClient().auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error('Not signed in.');
  return token;
}

/**
 * Upload a PDF to Cloudflare R2 via the authenticated Pages Function.
 * R2 has zero egress cost, so serving these files is free regardless of traffic.
 * Returns the public URL and the object key (stored for later deletion).
 */
export async function uploadPaperPdf(
  file: File,
  key: string
): Promise<{ url: string; sizeKb: number; key: string }> {
  const token = await getAccessToken();
  const form = new FormData();
  form.append('file', file);
  form.append('key', key);

  const res = await fetch('/api/upload', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const data = (await res.json()) as { url?: string; sizeKb?: number; key?: string; error?: string };
  if (!res.ok || data.error) {
    throw new Error(data.error || 'Upload failed.');
  }
  return { url: data.url!, sizeKb: data.sizeKb!, key: data.key! };
}

/** Delete a PDF object from R2 via the authenticated Pages Function. */
export async function deletePaperPdf(key: string): Promise<void> {
  if (!key) return;
  const token = await getAccessToken();
  await fetch('/api/delete', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ key }),
  });
}

// ---------- Solutions ----------

export async function getSolution(paperId: number) {
  const { data, error } = await getClient()
    .from('solutions')
    .select('*')
    .eq('paper_id', paperId)
    .maybeSingle();
  if (error) throw error;
  return data as Solution | null;
}

/** Create or update (upsert) the solution for a paper. */
export async function upsertSolution(input: {
  paper_id: number;
  content: string | null;
  solution_pdf_url: string | null;
  author: string;
  is_published: boolean;
}) {
  return getClient()
    .from('solutions')
    .upsert({ ...input, updated_at: new Date().toISOString() }, { onConflict: 'paper_id' })
    .select()
    .single();
}

export async function deleteSolution(paperId: number) {
  return getClient().from('solutions').delete().eq('paper_id', paperId);
}

// ---------- Blog ----------

export async function listBlogPosts(): Promise<BlogPost[]> {
  const { data, error } = await getClient()
    .from('blog_posts')
    .select('*')
    .order('pub_date', { ascending: false });
  if (error) throw error;
  return (data as BlogPost[]) ?? [];
}

export async function upsertBlogPost(input: {
  id?: number;
  slug: string;
  title: string;
  description: string;
  content: string;
  author: string;
  tags: string[];
  is_published: boolean;
}) {
  const payload = { ...input, updated_at: new Date().toISOString() };
  return getClient().from('blog_posts').upsert(payload, { onConflict: 'slug' }).select().single();
}

export async function deleteBlogPost(id: number) {
  return getClient().from('blog_posts').delete().eq('id', id);
}

export const DEGREE_TYPES: DegreeType[] = ['UG', 'PG'];
export const EXAM_SESSIONS: ExamSession[] = ['May/June', 'Nov/Dec', 'Supplementary', 'Re-appear'];
