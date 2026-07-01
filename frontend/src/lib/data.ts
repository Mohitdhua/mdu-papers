import { supabase, isSupabaseConfigured } from './supabase';
import { mockCourses, mockSubjects, mockPapers, mockSolutions } from './mockData';
import type { Course, Subject, Paper, SearchEntry, RecentPaper, Solution } from './types';
import { subjectUrl, paperUrl, paperSlug } from './utils';

/**
 * Helper to fetch all rows from Supabase, bypassing the 1000-row API limit.
 */
async function fetchAllRows<T>(
  fetchFn: (from: number, to: number) => any
): Promise<T[]> {
  let allData: T[] = [];
  let from = 0;
  const limit = 1000;
  while (true) {
    const { data, error } = await fetchFn(from, from + limit - 1);
    if (error) {
      console.error('[data] fetchAllRows error:', error);
      throw error;
    }
    if (!data || data.length === 0) break;
    allData = allData.concat(data as T[]);
    if (data.length < limit) break;
    from += limit;
  }
  return allData;
}

/**
 * Data access layer. Every function transparently uses Supabase when it is
 * configured, otherwise falls back to the local mock dataset so the site
 * builds and runs without any backend.
 *
 * These are all read functions intended to run at build time (SSG).
 */

/**
 * "Content gating": when running on the real backend we only publish courses
 * and subjects that actually have at least one paper (avoids thin/empty pages
 * that hurt SEO). In mock/dev mode (Supabase not configured) we show everything
 * so the full design is visible during development.
 */
const GATE_EMPTY = isSupabaseConfigured;

/** Cache of subjectIds that have >=1 paper (built once per build run). */
let _subjectsWithPapers: Set<number> | null = null;
async function subjectsWithPapers(): Promise<Set<number>> {
  if (_subjectsWithPapers) return _subjectsWithPapers;
  const ids = new Set<number>();
  if (isSupabaseConfigured && supabase) {
    try {
      const data = await fetchAllRows<{ subject_id: number }>((from, to) =>
        supabase.from('papers').select('subject_id').range(from, to)
      );
      for (const row of data) ids.add(row.subject_id);
    } catch (err) {
      console.error('[data] Failed to load subjects with papers:', err);
    }
  } else {
    for (const p of mockPapers) ids.add(p.subject_id);
  }
  _subjectsWithPapers = ids;
  return ids;
}

/** Cache of courseIds that have >=1 paper. */
let _coursesWithPapers: Set<number> | null = null;
async function coursesWithPapers(): Promise<Set<number>> {
  if (_coursesWithPapers) return _coursesWithPapers;
  const subjIds = await subjectsWithPapers();
  // Map subjects -> course.
  let subjects: Subject[] = mockSubjects;
  if (isSupabaseConfigured && supabase) {
    try {
      subjects = await fetchAllRows<Subject>((from, to) =>
        supabase.from('subjects').select('id, course_id').range(from, to)
      );
    } catch (err) {
      console.error('[data] Failed to load subjects for coursesWithPapers:', err);
    }
  }
  const ids = new Set<number>();
  for (const s of subjects) {
    if (subjIds.has(s.id)) ids.add(s.course_id);
  }
  _coursesWithPapers = ids;
  return ids;
}

// ---------- Courses ----------

export async function getCourses(): Promise<Course[]> {
  if (isSupabaseConfigured && supabase) {
    const { data, error } = await supabase.from('courses').select('*').order('id');
    if (error) {
      console.warn('[data] getCourses fell back to mock:', error.message);
    } else if (data) {
      return await attachRealPaperCounts(data as Course[]);
    }
  }
  return isSupabaseConfigured ? [] : attachCoursePaperCounts(structuredClone(mockCourses));
}

export async function getCourseBySlug(slug: string): Promise<Course | null> {
  const courses = await getCourses();
  return courses.find((c) => c.slug === slug) ?? null;
}

export async function getPopularCourses(): Promise<Course[]> {
  const courses = await getVisibleCourses();
  return courses.filter((c) => c.is_popular);
}

/**
 * Courses to actually publish/list. In production this excludes courses with
 * zero papers (avoids empty pages). In dev/mock mode returns all courses.
 */
export async function getVisibleCourses(): Promise<Course[]> {
  const courses = await getCourses();
  if (!GATE_EMPTY) return courses;
  const allowed = await coursesWithPapers();
  return courses.filter((c) => allowed.has(c.id));
}

/** Real paper counts (Supabase): sum each course's subjects' paper_count. */
async function attachRealPaperCounts(courses: Course[]): Promise<Course[]> {
  if (!supabase) return courses;
  // Pull all subjects once and aggregate per course.
  let data: { course_id: number; paper_count: number | null }[] = [];
  try {
    data = await fetchAllRows<{ course_id: number; paper_count: number | null }>((from, to) =>
      supabase.from('subjects').select('course_id, paper_count').range(from, to)
    );
  } catch (err) {
    console.error('[data] Failed to load real paper counts:', err);
    return courses.map((c) => ({ ...c, paper_count: 0 }));
  }
  const totals = new Map<number, number>();
  for (const row of data) {
    totals.set(row.course_id, (totals.get(row.course_id) ?? 0) + (row.paper_count ?? 0));
  }
  return courses.map((c) => ({ ...c, paper_count: totals.get(c.id) ?? 0 }));
}

function attachCoursePaperCounts(courses: Course[]): Course[] {
  // Compute total papers per course from subjects/papers (mock) for display.
  return courses.map((course) => {
    const subjectIds = mockSubjects.filter((s) => s.course_id === course.id).map((s) => s.id);
    const count = mockPapers.filter((p) => subjectIds.includes(p.subject_id)).length;
    return { ...course, paper_count: course.paper_count ?? count };
  });
}

// ---------- Subjects ----------

export async function getSubjectsByCourse(courseId: number): Promise<Subject[]> {
  if (isSupabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('subjects')
      .select('*')
      .eq('course_id', courseId)
      .order('semester');
    if (!error && data) return data as Subject[];
  }
  return isSupabaseConfigured ? [] : mockSubjects.filter((s) => s.course_id === courseId);
}

/**
 * Subjects to actually publish for a course. In production this excludes
 * subjects with zero papers; in dev/mock mode returns all subjects.
 */
export async function getVisibleSubjectsByCourse(courseId: number): Promise<Subject[]> {
  const subjects = await getSubjectsByCourse(courseId);
  if (!GATE_EMPTY) return subjects;
  const allowed = await subjectsWithPapers();
  return subjects.filter((s) => allowed.has(s.id));
}

export async function getSubjectsBySemester(courseId: number, semester: number): Promise<Subject[]> {
  const subjects = await getVisibleSubjectsByCourse(courseId);
  return subjects
    .filter((s) => s.semester === semester)
    .sort((a, b) => b.paper_count - a.paper_count);
}

export async function getSubjectBySlug(
  courseId: number,
  semester: number,
  slug: string
): Promise<Subject | null> {
  const subjects = await getSubjectsBySemester(courseId, semester);
  return subjects.find((s) => s.slug === slug) ?? null;
}

/** Return the distinct semester numbers that actually have subjects. */
export async function getSemestersWithSubjects(courseId: number): Promise<number[]> {
  const subjects = await getSubjectsByCourse(courseId);
  return [...new Set(subjects.map((s) => s.semester))].sort((a, b) => a - b);
}

// ---------- Papers ----------

export async function getPapersBySubject(subjectId: number): Promise<Paper[]> {
  if (isSupabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('papers')
      .select('*')
      .eq('subject_id', subjectId)
      .order('year', { ascending: false });
    if (!error && data) return data as Paper[];
  }
  return isSupabaseConfigured ? [] : mockPapers
    .filter((p) => p.subject_id === subjectId)
    .sort((a, b) => b.year - a.year || a.exam_session.localeCompare(b.exam_session));
}

// ---------- Aggregate / cross-cutting queries ----------

/** Recently added papers across the whole site (for homepage). */
export async function getRecentPapers(limit = 8): Promise<RecentPaper[]> {
  const courses = await getCourses();
  const courseById = new Map(courses.map((c) => [c.id, c]));

  // Use real data when Supabase is configured, else mock.
  if (isSupabaseConfigured && supabase) {
    const { data: papersData } = await supabase
      .from('papers')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);
    
    let subjectsData: Subject[] = [];
    try {
      subjectsData = await fetchAllRows<Subject>((from, to) =>
        supabase.from('subjects').select('*').range(from, to)
      );
    } catch (err) {
      console.error('[data] Failed to load subjects for recent papers:', err);
    }

    const subjectById = new Map(
      subjectsData.map((s) => [s.id, s])
    );
    const result: RecentPaper[] = [];
    for (const paper of (papersData as Paper[]) ?? []) {
      const subject = subjectById.get(paper.subject_id);
      if (!subject) continue;
      const course = courseById.get(subject.course_id);
      if (!course) continue;
      result.push({
        paper,
        subject,
        course,
        url: subjectUrl(course.slug, subject.semester, subject.slug),
      });
    }
    return result;
  }

  // Mock fallback.
  const subjectById = new Map(mockSubjects.map((s) => [s.id, s]));
  const sorted = [...mockPapers]
    .sort((a, b) => b.year - a.year || b.id - a.id)
    .slice(0, limit);
  const result: RecentPaper[] = [];
  for (const paper of sorted) {
    const subject = subjectById.get(paper.subject_id);
    if (!subject) continue;
    const course = courseById.get(subject.course_id);
    if (!course) continue;
    result.push({
      paper,
      subject,
      course,
      url: subjectUrl(course.slug, subject.semester, subject.slug),
    });
  }
  return result;
}

/** Site-wide statistics for the homepage counters. */
export async function getSiteStats(): Promise<{
  papers: number;
  courses: number;
  downloads: number;
  subjects: number;
}> {
  const courses = await getCourses();

  if (isSupabaseConfigured && supabase) {
    const [{ count: paperCount }, { count: subjectCount }, dlData] = await Promise.all([
      supabase.from('papers').select('*', { count: 'exact', head: true }),
      supabase.from('subjects').select('*', { count: 'exact', head: true }),
      fetchAllRows<{ download_count: number }>((from, to) =>
        supabase.from('papers').select('download_count').range(from, to)
      ).catch(() => []),
    ]);
    const downloads = dlData.reduce(
      (sum, p) => sum + (p.download_count ?? 0),
      0
    );
    return {
      papers: paperCount ?? 0,
      courses: courses.length,
      downloads,
      subjects: subjectCount ?? 0,
    };
  }

  const downloads = mockPapers.reduce((sum, p) => sum + p.download_count, 0);
  return {
    papers: mockPapers.length,
    courses: courses.length,
    downloads: Math.max(downloads, 50000),
    subjects: mockSubjects.length,
  };
}

/** Build the full search index consumed by the client-side fuzzy search. */
export async function buildSearchIndex(): Promise<SearchEntry[]> {
  const all = await getAllPapersWithContext();
  return all.map(({ paper, subject, course, url }) => ({
    course: course.name,
    courseSlug: course.slug,
    semester: subject.semester,
    subject: subject.name,
    year: paper.year,
    session: paper.exam_session,
    url, // now links directly to the individual paper page
    pdf: paper.pdf_url,
  }));
}

/** Years range string for a list of papers, e.g. "2019–2024". */
export function yearsRange(papers: Paper[]): string {
  if (papers.length === 0) return '—';
  const years = papers.map((p) => p.year);
  const min = Math.min(...years);
  const max = Math.max(...years);
  return min === max ? `${min}` : `${min}–${max}`;
}

/**
 * A single paper joined with its full subject + course context, including the
 * computed SEO slug and URL. Used to build per-paper static pages.
 */
export interface PaperWithContext {
  paper: Paper;
  subject: Subject;
  course: Course;
  slug: string;
  url: string;
}

/** Build the unique paper slug (session + year), disambiguating collisions. */
function computePaperSlugs(papers: Paper[]): Map<number, string> {
  const slugs = new Map<number, string>();
  const used = new Set<string>();
  for (const p of papers) {
    let slug = paperSlug({ year: p.year, session: p.exam_session });
    while (used.has(slug)) {
      slug = `${slug}-${p.id}`;
    }
    used.add(slug);
    slugs.set(p.id, slug);
  }
  return slugs;
}

/**
 * Return every paper across the site joined with its subject + course context
 * and a unique SEO slug. Used by getStaticPaths for per-paper pages.
 */
export async function getAllPapersWithContext(): Promise<PaperWithContext[]> {
  const courses = await getCourses();
  const courseById = new Map(courses.map((c) => [c.id, c]));

  // Source subjects + papers from Supabase when configured, else mock.
  let subjects: Subject[] = mockSubjects;
  let papers: Paper[] = mockPapers;
  if (isSupabaseConfigured && supabase) {
    try {
      const [subjectsData, papersData] = await Promise.all([
        fetchAllRows<Subject>((from, to) =>
          supabase.from('subjects').select('*').range(from, to)
        ),
        fetchAllRows<Paper>((from, to) =>
          supabase.from('papers').select('*').range(from, to)
        ),
      ]);
      subjects = subjectsData;
      papers = papersData;
    } catch (err) {
      console.error('[data] Failed to load data for getAllPapersWithContext:', err);
    }
  }

  const subjectById = new Map(subjects.map((s) => [s.id, s]));

  // Group papers by subject so we can compute collision-free slugs.
  const bySubject = new Map<number, Paper[]>();
  for (const paper of papers) {
    if (!bySubject.has(paper.subject_id)) bySubject.set(paper.subject_id, []);
    bySubject.get(paper.subject_id)!.push(paper);
  }

  const result: PaperWithContext[] = [];
  for (const [subjectId, subjectPapers] of bySubject) {
    const subject = subjectById.get(subjectId);
    if (!subject) continue;
    const course = courseById.get(subject.course_id);
    if (!course) continue;
    const slugs = computePaperSlugs(subjectPapers);
    for (const paper of subjectPapers) {
      const slug = slugs.get(paper.id)!;
      result.push({
        paper,
        subject,
        course,
        slug,
        url: paperUrl(course.slug, subject.semester, subject.slug, slug),
      });
    }
  }
  return result;
}

/** Map of paperId -> slug for a single subject (used on the subject page). */
export async function getPaperSlugMap(subjectId: number): Promise<Map<number, string>> {
  const papers = await getPapersBySubject(subjectId);
  return computePaperSlugs(papers);
}

// ---------- Solutions ----------

/** Fetch the published solution for a paper, if one exists. */
export async function getSolutionByPaper(paperId: number): Promise<Solution | null> {
  if (isSupabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('solutions')
      .select('*')
      .eq('paper_id', paperId)
      .eq('is_published', true)
      .maybeSingle();
    if (!error && data) return data as Solution;
    if (!error) return null;
  }
  return isSupabaseConfigured ? null : mockSolutions.find((s) => s.paper_id === paperId && s.is_published) ?? null;
}

/** Set of paper IDs that have a published solution (for badges). */
export async function getPaperIdsWithSolutions(): Promise<Set<number>> {
  if (isSupabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('solutions')
      .select('paper_id')
      .eq('is_published', true);
    if (!error && data) return new Set(data.map((r) => (r as { paper_id: number }).paper_id));
  }
  return isSupabaseConfigured ? new Set<number>() : new Set(mockSolutions.filter((s) => s.is_published).map((s) => s.paper_id));
}


// ---------- Blog ----------

import type { BlogPost } from './types';

/** A normalized blog post for rendering, from either Markdown or the DB. */
export interface UnifiedBlogPost {
  slug: string;
  title: string;
  description: string;
  author: string;
  tags: string[];
  pubDate: Date;
  /** Raw markdown body (rendered by the page with `marked`). */
  body: string;
  source: 'db' | 'markdown';
}

/** Fetch published blog posts from Supabase (empty if not configured). */
export async function getDbBlogPosts(): Promise<UnifiedBlogPost[]> {
  if (!isSupabaseConfigured || !supabase) return [];
  const { data, error } = await supabase
    .from('blog_posts')
    .select('*')
    .eq('is_published', true)
    .order('pub_date', { ascending: false });
  if (error || !data) return [];
  return (data as BlogPost[]).map((p) => ({
    slug: p.slug,
    title: p.title,
    description: p.description,
    author: p.author,
    tags: p.tags ?? [],
    pubDate: new Date(p.pub_date),
    body: p.content,
    source: 'db' as const,
  }));
}
