/** Shared domain types mirroring the Supabase schema. */

export type DegreeType = 'UG' | 'PG';

export type ExamSession = 'May/June' | 'Nov/Dec' | 'Supplementary' | 'Re-appear';

export interface Course {
  id: number;
  name: string;
  full_name: string;
  degree_type: DegreeType;
  slug: string;
  total_semesters: number;
  icon_emoji: string;
  is_popular: boolean;
  created_at?: string;
  /** Aggregate paper count, computed at query time. */
  paper_count?: number;
}

export interface Subject {
  id: number;
  course_id: number;
  semester: number;
  name: string;
  subject_code: string | null;
  slug: string;
  paper_count: number;
  created_at?: string;
}

export interface Paper {
  id: number;
  subject_id: number;
  year: number;
  exam_session: ExamSession;
  pdf_url: string;
  /** Object key in Cloudflare R2 (used for deletion). */
  r2_key?: string | null;
  /** Comma/line separated main topics asked in this paper (admin-entered). */
  topics?: string | null;
  pdf_size_kb: number | null;
  page_count: number | null;
  download_count: number;
  is_verified: boolean;
  uploaded_by: string;
  created_at?: string;
}

/**
 * A worked solution for a paper. Content is markdown (rendered on the paper
 * page). Optionally links to a separate solution PDF as well.
 */
export interface Solution {
  id: number;
  paper_id: number;
  content: string | null;
  solution_pdf_url: string | null;
  author: string;
  is_published: boolean;
  created_at?: string;
  updated_at?: string;
}

/** A blog post stored in the database (admin-managed). */
export interface BlogPost {
  id: number;
  slug: string;
  title: string;
  description: string;
  content: string;
  author: string;
  tags: string[];
  is_published: boolean;
  pub_date: string;
  updated_at?: string;
  created_at?: string;
}

/** A search index entry generated at build time. */
export interface SearchEntry {
  course: string;
  courseSlug: string;
  semester: number;
  subject: string;
  subjectCode: string | null;
  year: number;
  session: ExamSession;
  url: string;
  pdf: string;
}

/** A paper joined with its subject + course context for display. */
export interface RecentPaper {
  paper: Paper;
  subject: Subject;
  course: Course;
  url: string;
}
