import type { Course, Subject, Paper, ExamSession } from './types';
import { slugify } from './utils';

/**
 * Local mock dataset used when Supabase is not configured. This mirrors the
 * seed data described in the schema and generates a realistic spread of
 * subjects and papers so every page renders with meaningful content.
 */

export const mockCourses: Course[] = [
  // UG
  { id: 1, name: 'BCA', full_name: 'Bachelor of Computer Applications', degree_type: 'UG', slug: 'bca', total_semesters: 6, icon_emoji: '💻', is_popular: true },
  { id: 2, name: 'BBA', full_name: 'Bachelor of Business Administration', degree_type: 'UG', slug: 'bba', total_semesters: 6, icon_emoji: '💼', is_popular: true },
  { id: 3, name: 'BCom', full_name: 'Bachelor of Commerce', degree_type: 'UG', slug: 'bcom', total_semesters: 6, icon_emoji: '📊', is_popular: true },
  { id: 4, name: 'BCom (Hons)', full_name: 'Bachelor of Commerce (Honours)', degree_type: 'UG', slug: 'bcom-hons', total_semesters: 6, icon_emoji: '📈', is_popular: false },
  { id: 5, name: 'BA', full_name: 'Bachelor of Arts', degree_type: 'UG', slug: 'ba', total_semesters: 6, icon_emoji: '📖', is_popular: true },
  { id: 6, name: 'BA (English)', full_name: 'Bachelor of Arts - English', degree_type: 'UG', slug: 'ba-english', total_semesters: 6, icon_emoji: '📕', is_popular: false },
  { id: 7, name: 'BA (Hindi)', full_name: 'Bachelor of Arts - Hindi', degree_type: 'UG', slug: 'ba-hindi', total_semesters: 6, icon_emoji: '📝', is_popular: false },
  { id: 8, name: 'BA (History)', full_name: 'Bachelor of Arts - History', degree_type: 'UG', slug: 'ba-history', total_semesters: 6, icon_emoji: '📜', is_popular: false },
  { id: 9, name: 'BA (Political Science)', full_name: 'Bachelor of Arts - Political Science', degree_type: 'UG', slug: 'ba-political-science', total_semesters: 6, icon_emoji: '🏛️', is_popular: false },
  { id: 10, name: 'BA (Economics)', full_name: 'Bachelor of Arts - Economics', degree_type: 'UG', slug: 'ba-economics', total_semesters: 6, icon_emoji: '💹', is_popular: false },
  { id: 11, name: 'BSc (CS)', full_name: 'Bachelor of Science - Computer Science', degree_type: 'UG', slug: 'bsc-cs', total_semesters: 6, icon_emoji: '🔬', is_popular: true },
  { id: 12, name: 'BSc (Physics)', full_name: 'Bachelor of Science - Physics', degree_type: 'UG', slug: 'bsc-physics', total_semesters: 6, icon_emoji: '⚛️', is_popular: false },
  { id: 13, name: 'BSc (Chemistry)', full_name: 'Bachelor of Science - Chemistry', degree_type: 'UG', slug: 'bsc-chemistry', total_semesters: 6, icon_emoji: '🧪', is_popular: false },
  { id: 14, name: 'BSc (Maths)', full_name: 'Bachelor of Science - Mathematics', degree_type: 'UG', slug: 'bsc-maths', total_semesters: 6, icon_emoji: '🔢', is_popular: false },
  { id: 15, name: 'BSc (Biotech)', full_name: 'Bachelor of Science - Biotechnology', degree_type: 'UG', slug: 'bsc-biotech', total_semesters: 6, icon_emoji: '🧬', is_popular: false },
  { id: 16, name: 'BSc (Botany)', full_name: 'Bachelor of Science - Botany', degree_type: 'UG', slug: 'bsc-botany', total_semesters: 6, icon_emoji: '🌿', is_popular: false },
  { id: 17, name: 'BSc (Zoology)', full_name: 'Bachelor of Science - Zoology', degree_type: 'UG', slug: 'bsc-zoology', total_semesters: 6, icon_emoji: '🦋', is_popular: false },
  { id: 18, name: 'B.Tech CSE', full_name: 'Bachelor of Technology - Computer Science & Engineering', degree_type: 'UG', slug: 'btech-cse', total_semesters: 8, icon_emoji: '⚙️', is_popular: true },
  { id: 19, name: 'B.Tech IT', full_name: 'Bachelor of Technology - Information Technology', degree_type: 'UG', slug: 'btech-it', total_semesters: 8, icon_emoji: '🖧', is_popular: false },
  { id: 20, name: 'B.Tech AI & ML', full_name: 'Bachelor of Technology - Artificial Intelligence & Machine Learning', degree_type: 'UG', slug: 'btech-ai-ml', total_semesters: 8, icon_emoji: '🤖', is_popular: true },
  { id: 21, name: 'B.Tech ECE', full_name: 'Bachelor of Technology - Electronics & Communication', degree_type: 'UG', slug: 'btech-ece', total_semesters: 8, icon_emoji: '📡', is_popular: false },
  { id: 22, name: 'B.Tech EE', full_name: 'Bachelor of Technology - Electrical Engineering', degree_type: 'UG', slug: 'btech-ee', total_semesters: 8, icon_emoji: '🔌', is_popular: false },
  { id: 23, name: 'B.Tech ME', full_name: 'Bachelor of Technology - Mechanical Engineering', degree_type: 'UG', slug: 'btech-me', total_semesters: 8, icon_emoji: '🔧', is_popular: false },
  { id: 24, name: 'B.Tech Civil', full_name: 'Bachelor of Technology - Civil Engineering', degree_type: 'UG', slug: 'btech-civil', total_semesters: 8, icon_emoji: '🏗️', is_popular: false },
  { id: 25, name: 'B.Pharm', full_name: 'Bachelor of Pharmacy', degree_type: 'UG', slug: 'bpharm', total_semesters: 8, icon_emoji: '💊', is_popular: false },
  { id: 26, name: 'BHMCT', full_name: 'Bachelor of Hotel Management & Catering Technology', degree_type: 'UG', slug: 'bhmct', total_semesters: 8, icon_emoji: '🍽️', is_popular: false },
  { id: 27, name: 'BTTM', full_name: 'Bachelor of Tourism & Travel Management', degree_type: 'UG', slug: 'bttm', total_semesters: 6, icon_emoji: '✈️', is_popular: false },
  { id: 28, name: 'BFA', full_name: 'Bachelor of Fine Arts', degree_type: 'UG', slug: 'bfa', total_semesters: 8, icon_emoji: '🎨', is_popular: false },
  { id: 29, name: 'BA LLB', full_name: 'Bachelor of Arts & Bachelor of Laws (Integrated)', degree_type: 'UG', slug: 'ba-llb', total_semesters: 10, icon_emoji: '⚖️', is_popular: false },
  { id: 30, name: 'BBA LLB', full_name: 'Bachelor of Business Administration & Bachelor of Laws (Integrated)', degree_type: 'UG', slug: 'bba-llb', total_semesters: 10, icon_emoji: '⚖️', is_popular: false },
  { id: 31, name: 'LLB', full_name: 'Bachelor of Laws', degree_type: 'UG', slug: 'llb', total_semesters: 6, icon_emoji: '📋', is_popular: false },
  { id: 32, name: 'B.Ed', full_name: 'Bachelor of Education', degree_type: 'UG', slug: 'bed', total_semesters: 4, icon_emoji: '🎓', is_popular: false },
  { id: 33, name: 'B.P.Ed', full_name: 'Bachelor of Physical Education', degree_type: 'UG', slug: 'bped', total_semesters: 4, icon_emoji: '🏅', is_popular: false },
  // PG
  { id: 34, name: 'MBA', full_name: 'Master of Business Administration', degree_type: 'PG', slug: 'mba', total_semesters: 4, icon_emoji: '🎯', is_popular: true },
  { id: 35, name: 'MCA', full_name: 'Master of Computer Applications', degree_type: 'PG', slug: 'mca', total_semesters: 4, icon_emoji: '🖥️', is_popular: true },
  { id: 36, name: 'MCom', full_name: 'Master of Commerce', degree_type: 'PG', slug: 'mcom', total_semesters: 4, icon_emoji: '📈', is_popular: false },
  { id: 37, name: 'MA (English)', full_name: 'Master of Arts - English', degree_type: 'PG', slug: 'ma-english', total_semesters: 4, icon_emoji: '📚', is_popular: false },
  { id: 38, name: 'MA (Hindi)', full_name: 'Master of Arts - Hindi', degree_type: 'PG', slug: 'ma-hindi', total_semesters: 4, icon_emoji: '🖊️', is_popular: false },
  { id: 39, name: 'MA (History)', full_name: 'Master of Arts - History', degree_type: 'PG', slug: 'ma-history', total_semesters: 4, icon_emoji: '🏺', is_popular: false },
  { id: 40, name: 'MA (Political Science)', full_name: 'Master of Arts - Political Science', degree_type: 'PG', slug: 'ma-political-science', total_semesters: 4, icon_emoji: '🏛️', is_popular: false },
  { id: 41, name: 'MA (Economics)', full_name: 'Master of Arts - Economics', degree_type: 'PG', slug: 'ma-economics', total_semesters: 4, icon_emoji: '💱', is_popular: false },
  { id: 42, name: 'MSc (CS)', full_name: 'Master of Science - Computer Science', degree_type: 'PG', slug: 'msc-cs', total_semesters: 4, icon_emoji: '🧪', is_popular: false },
  { id: 43, name: 'MSc (Physics)', full_name: 'Master of Science - Physics', degree_type: 'PG', slug: 'msc-physics', total_semesters: 4, icon_emoji: '🔭', is_popular: false },
  { id: 44, name: 'MSc (Chemistry)', full_name: 'Master of Science - Chemistry', degree_type: 'PG', slug: 'msc-chemistry', total_semesters: 4, icon_emoji: '⚗️', is_popular: false },
  { id: 45, name: 'MSc (Maths)', full_name: 'Master of Science - Mathematics', degree_type: 'PG', slug: 'msc-maths', total_semesters: 4, icon_emoji: '➗', is_popular: false },
  { id: 46, name: 'MSc (Biotech)', full_name: 'Master of Science - Biotechnology', degree_type: 'PG', slug: 'msc-biotech', total_semesters: 4, icon_emoji: '🧬', is_popular: false },
  { id: 47, name: 'M.Tech CSE', full_name: 'Master of Technology - Computer Science & Engineering', degree_type: 'PG', slug: 'mtech-cse', total_semesters: 4, icon_emoji: '🛠️', is_popular: false },
  { id: 48, name: 'M.Pharm', full_name: 'Master of Pharmacy', degree_type: 'PG', slug: 'mpharm', total_semesters: 4, icon_emoji: '💉', is_popular: false },
  { id: 49, name: 'LLM', full_name: 'Master of Laws', degree_type: 'PG', slug: 'llm', total_semesters: 4, icon_emoji: '⚖️', is_popular: false },
  { id: 50, name: 'M.Ed', full_name: 'Master of Education', degree_type: 'PG', slug: 'med', total_semesters: 4, icon_emoji: '📔', is_popular: false },
  { id: 51, name: 'M.P.Ed', full_name: 'Master of Physical Education', degree_type: 'PG', slug: 'mped', total_semesters: 4, icon_emoji: '🏆', is_popular: false },
  { id: 52, name: 'MTTM', full_name: 'Master of Tourism & Travel Management', degree_type: 'PG', slug: 'mttm', total_semesters: 4, icon_emoji: '🧳', is_popular: false },
  { id: 53, name: 'MHMCT', full_name: 'Master of Hotel Management & Catering Technology', degree_type: 'PG', slug: 'mhmct', total_semesters: 4, icon_emoji: '🍴', is_popular: false },
];

/** A small curated set of subjects keyed by course slug + semester. */
const subjectsBlueprint: Record<string, Record<number, Array<{ name: string; code: string }>>> = {
  bca: {
    1: [
      { name: 'Fundamentals of Computers', code: 'BCA-101' },
      { name: 'Mathematics-I', code: 'BCA-102' },
      { name: 'Programming in C', code: 'BCA-103' },
      { name: 'Communication Skills', code: 'BCA-104' },
    ],
    2: [
      { name: 'Data Structures', code: 'BCA-201' },
      { name: 'Mathematics-II', code: 'BCA-202' },
      { name: 'Digital Electronics', code: 'BCA-203' },
      { name: 'Object Oriented Programming', code: 'BCA-204' },
    ],
    3: [
      { name: 'Mathematics-III', code: 'BCA-301' },
      { name: 'Database Management System', code: 'BCA-302' },
      { name: 'Computer Networks', code: 'BCA-303' },
      { name: 'Operating Systems', code: 'BCA-304' },
    ],
    4: [
      { name: 'Java Programming', code: 'BCA-401' },
      { name: 'Software Engineering', code: 'BCA-402' },
      { name: 'Web Technologies', code: 'BCA-403' },
    ],
    5: [
      { name: 'Python Programming', code: 'BCA-501' },
      { name: 'Computer Graphics', code: 'BCA-502' },
      { name: 'E-Commerce', code: 'BCA-503' },
    ],
    6: [
      { name: 'Cloud Computing', code: 'BCA-601' },
      { name: 'Mobile Application Development', code: 'BCA-602' },
    ],
  },
  'btech-cse': {
    1: [
      { name: 'Engineering Mathematics-I', code: 'CSE-101' },
      { name: 'Engineering Physics', code: 'CSE-102' },
      { name: 'Programming Fundamentals', code: 'CSE-103' },
    ],
    3: [
      { name: 'Data Structures & Algorithms', code: 'CSE-301' },
      { name: 'Discrete Mathematics', code: 'CSE-302' },
      { name: 'Digital Logic Design', code: 'CSE-303' },
    ],
    4: [
      { name: 'Database Management System', code: 'CSE-401' },
      { name: 'Operating Systems', code: 'CSE-402' },
      { name: 'Computer Organization', code: 'CSE-403' },
    ],
    5: [
      { name: 'Design & Analysis of Algorithms', code: 'CSE-501' },
      { name: 'Computer Networks', code: 'CSE-502' },
      { name: 'Theory of Computation', code: 'CSE-503' },
    ],
  },
  'bsc-cs': {
    1: [
      { name: 'Programming in C', code: 'BSCCS-101' },
      { name: 'Mathematics-I', code: 'BSCCS-102' },
    ],
    3: [
      { name: 'Data Structures', code: 'BSCCS-301' },
      { name: 'DBMS', code: 'BSCCS-302' },
    ],
  },
  bcom: {
    1: [
      { name: 'Financial Accounting', code: 'BCOM-101' },
      { name: 'Business Economics', code: 'BCOM-102' },
      { name: 'Business Law', code: 'BCOM-103' },
    ],
    3: [
      { name: 'Cost Accounting', code: 'BCOM-301' },
      { name: 'Income Tax Law', code: 'BCOM-302' },
      { name: 'Corporate Accounting', code: 'BCOM-303' },
    ],
  },
  bba: {
    1: [
      { name: 'Principles of Management', code: 'BBA-101' },
      { name: 'Business Economics', code: 'BBA-102' },
    ],
    3: [
      { name: 'Marketing Management', code: 'BBA-301' },
      { name: 'Financial Management', code: 'BBA-302' },
    ],
  },
  mba: {
    1: [
      { name: 'Management Principles', code: 'MBA-101' },
      { name: 'Managerial Economics', code: 'MBA-102' },
      { name: 'Accounting for Managers', code: 'MBA-103' },
    ],
    2: [
      { name: 'Marketing Management', code: 'MBA-201' },
      { name: 'Human Resource Management', code: 'MBA-202' },
    ],
  },
  mca: {
    1: [
      { name: 'Advanced Data Structures', code: 'MCA-101' },
      { name: 'Computer Architecture', code: 'MCA-102' },
    ],
    2: [
      { name: 'Advanced Java', code: 'MCA-201' },
      { name: 'Machine Learning', code: 'MCA-202' },
    ],
  },
};

const SESSIONS: ExamSession[] = ['May/June', 'Nov/Dec'];

// Deterministic pseudo-random so builds are reproducible.
function seeded(seed: number): () => number {
  let s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

// Build subjects + papers from the blueprint.
const _subjects: Subject[] = [];
const _papers: Paper[] = [];
let subjectId = 1;
let paperId = 1;

for (const course of mockCourses) {
  const blueprint = subjectsBlueprint[course.slug];
  // Generate a generic fallback subject set for courses without a blueprint
  const semestersMap = blueprint ?? {
    1: [
      { name: 'Core Paper-I', code: `${course.name.replace(/[^A-Z]/g, '') || 'GEN'}-101` },
      { name: 'Core Paper-II', code: `${course.name.replace(/[^A-Z]/g, '') || 'GEN'}-102` },
    ],
    2: [{ name: 'Core Paper-III', code: `${course.name.replace(/[^A-Z]/g, '') || 'GEN'}-201` }],
  };

  for (const [semStr, subs] of Object.entries(semestersMap)) {
    const semester = Number(semStr);
    for (const sub of subs) {
      const sId = subjectId++;
      const rng = seeded(sId * 97 + 13);
      // Generate papers across a few years.
      const yearStart = 2019;
      const yearEnd = 2024;
      const papersForSubject: Paper[] = [];
      for (let year = yearStart; year <= yearEnd; year++) {
        // not every year/session exists
        for (const session of SESSIONS) {
          if (rng() < 0.55) {
            papersForSubject.push({
              id: paperId++,
              subject_id: sId,
              year,
              exam_session: session,
              pdf_url: `https://pub-xxxxx.r2.dev/${course.slug}-${slugify(sub.name)}-${year}-${slugify(session)}.pdf`,
              pdf_size_kb: Math.round(800 + rng() * 2800),
              page_count: 2 + Math.floor(rng() * 6),
              download_count: Math.floor(rng() * 1200),
              is_verified: true,
              uploaded_by: 'admin',
            });
          }
        }
      }
      // Ensure each subject has at least 2 papers.
      if (papersForSubject.length < 2) {
        papersForSubject.push({
          id: paperId++,
          subject_id: sId,
          year: 2024,
          exam_session: 'Nov/Dec',
          pdf_url: `https://pub-xxxxx.r2.dev/${course.slug}-${slugify(sub.name)}-2024.pdf`,
          pdf_size_kb: 1800,
          page_count: 4,
          download_count: Math.floor(rng() * 500),
          is_verified: true,
          uploaded_by: 'admin',
        });
      }
      _papers.push(...papersForSubject);
      _subjects.push({
        id: sId,
        course_id: course.id,
        semester,
        name: sub.name,
        slug: slugify(sub.name),
        paper_count: papersForSubject.length,
      });
    }
  }
}

export const mockSubjects: Subject[] = _subjects;
export const mockPapers: Paper[] = _papers;

// A couple of demo solutions attached to the first papers of two subjects so
// the solutions feature renders out-of-the-box in mock mode.
export const mockSolutions: import('./types').Solution[] = (() => {
  const out: import('./types').Solution[] = [];
  const firstTwo = _papers.slice(0, 2);
  let id = 1;
  for (const p of firstTwo) {
    out.push({
      id: id++,
      paper_id: p.id,
      solution_pdf_url: null,
      author: 'MDU Papers Team',
      is_published: true,
      content: `## Solution Overview

This is a **sample worked solution** for this paper. Real solutions are added by the team through the admin panel.

### Section A — Short Answers

1. **Definition questions** — keep answers concise (2-3 lines) and to the point.
2. Always state the *key term* first, then a one-line explanation.

### Section B — Long Answers

> Tip: Structure long answers with a short intro, the main explanation, and a small example or diagram.

- Break the answer into clear points.
- Add an example wherever the question says "with example".
- Draw a labelled diagram for technical questions.

### Important Topics from this Paper

- Topic 1 — frequently repeated, revise thoroughly.
- Topic 2 — numerical/derivation based, practice step by step.

*Solutions are for guidance and self-study. Always verify with your textbook and teacher.*`,
    });
  }
  return out;
})();
