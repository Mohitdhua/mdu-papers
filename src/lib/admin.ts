import { createClient, type SupabaseClient, type Session } from '@supabase/supabase-js';
import type { Course, Subject, Paper, DegreeType, ExamSession, Solution } from './types';

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

/** Name of the Supabase Storage bucket used for paper PDFs. */
export const PAPERS_BUCKET = 'papers';

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
  pdf_size_kb: number | null;
  page_count: number | null;
  is_verified: boolean;
}) {
  return getClient().from('papers').insert(input).select().single();
}

export async function deletePaper(id: number) {
  return getClient().from('papers').delete().eq('id', id);
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

/**
 * Upload a PDF to Supabase Storage and return its public URL.
 * The bucket must exist and be public (see supabase/storage.sql).
 */
export async function uploadPaperPdf(
  file: File,
  path: string
): Promise<{ url: string; sizeKb: number }> {
  const client = getClient();
  const { error } = await client.storage.from(PAPERS_BUCKET).upload(path, file, {
    cacheControl: '3600',
    upsert: true,
    contentType: 'application/pdf',
  });
  if (error) throw error;
  const { data } = client.storage.from(PAPERS_BUCKET).getPublicUrl(path);
  return { url: data.publicUrl, sizeKb: Math.round(file.size / 1024) };
}

export const DEGREE_TYPES: DegreeType[] = ['UG', 'PG'];
export const EXAM_SESSIONS: ExamSession[] = ['May/June', 'Nov/Dec', 'Supplementary', 'Re-appear'];
