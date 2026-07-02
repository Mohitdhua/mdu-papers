import { SITE } from './config';
import {
  getCourses,
  getSubjectsByCourse,
  getPapersBySubject,
  getPaperSlugMap,
  getAllPapersWithContext,
} from './data';
import { semesterLabel, semesterToSlug } from './utils';
import { getCollection } from 'astro:content';

/** One row describing how a page appears in Google search results. */
export interface SeoEntry {
  /** Page path, e.g. "/bca/3rd-sem". */
  path: string;
  /** Full <title> as rendered (includes "| MDU Papers"). */
  title: string;
  /** Meta description. */
  description: string;
  /** Page group for filtering in the UI. */
  type: 'core' | 'course' | 'semester' | 'subject' | 'paper' | 'blog' | 'legal';
  /** Whether the page is set to noindex. */
  noindex?: boolean;
}

/** Mirror SEO.astro's title composition. */
function composeTitle(title?: string): string {
  return title ? `${title} | ${SITE.name}` : SITE.title;
}

/**
 * Build SEO metadata for every page on the site, reusing the exact title and
 * description strings the real pages generate. Used by the SERP preview tool.
 */
export async function buildSeoIndex(): Promise<SeoEntry[]> {
  const entries: SeoEntry[] = [];

  // ---- Core / static pages ----
  entries.push({
    path: '/',
    title: composeTitle(),
    description: SITE.description,
    type: 'core',
  });
  entries.push({
    path: '/courses',
    title: composeTitle('All MDU Courses — Browse Question Papers by Course'),
    description:
      'Browse previous year question papers for all MDU undergraduate and postgraduate courses including BCA, B.Tech, BSc, BCom, MBA, MCA and more.',
    type: 'core',
  });
  entries.push({
    path: '/blog',
    title: composeTitle('Blog — Study Tips, Exam Guides & MDU Updates'),
    description:
      'Read study tips, exam preparation guides and MDU updates to help you score better in your semester exams.',
    type: 'core',
  });
  entries.push({
    path: '/search',
    title: composeTitle('Search Papers'),
    description:
      'Search across all MDU previous year question papers by course, subject, code or year.',
    type: 'core',
    noindex: true,
  });
  entries.push({
    path: '/admin',
    title: composeTitle('Admin'),
    description: SITE.description,
    type: 'core',
    noindex: true,
  });

  // ---- Legal / info pages ----
  const legal: Array<[string, string, string]> = [
    ['/about', 'About Us', 'Learn about MDU Papers — a free, student-built platform for accessing MDU previous year question papers & notes.'],
    ['/contact', 'Contact Us', 'Get in touch with the MDU Papers team. Contribute papers, report issues or send feedback.'],
    ['/privacy', 'Privacy Policy', 'Privacy policy for MDU Papers. Learn how we handle data, cookies and third-party advertising.'],
    ['/terms', 'Terms of Service', 'Terms of service for using MDU Papers. Educational purpose, no warranties, content removal requests.'],
    ['/disclaimer', 'Disclaimer', 'Important disclaimer about MDU Papers. This is not the official website of Maharshi Dayanand University.'],
  ];
  for (const [path, title, description] of legal) {
    entries.push({ path, title: composeTitle(title), description, type: 'legal' });
  }

  // ---- Blog posts ----
  const posts = await getCollection('blog');
  for (const post of posts) {
    entries.push({
      path: `/blog/${post.slug}`,
      title: composeTitle(post.data.title),
      description: post.data.description,
      type: 'blog',
    });
  }

  // ---- Courses, semesters, subjects ----
  const courses = await getCourses();
  for (const course of courses) {
    const subjects = await getSubjectsByCourse(course.id);
    const totalPapers = subjects.reduce((sum, s) => sum + s.paper_count, 0);

    entries.push({
      path: `/${course.slug}`,
      title: composeTitle(`${course.name} Previous Year Papers — All Semesters`),
      description: `Download free ${course.full_name} (${course.name}) previous year question papers for all ${course.total_semesters} semesters at MDU Rohtak.`,
      type: 'course',
    });

    const semesters = [...new Set(subjects.map((s) => s.semester))].sort((a, b) => a - b);
    for (const sem of semesters) {
      const semLabel = semesterLabel(sem);
      entries.push({
        path: `/${course.slug}/${semesterToSlug(sem)}`,
        title: composeTitle(`${course.name} ${semLabel} Papers — All Subjects`),
        description: `Browse all ${course.name} ${semLabel} subjects and download previous year question papers (PDF) for MDU Rohtak.`,
        type: 'semester',
      });
    }

    for (const subject of subjects) {
      const papers = await getPapersBySubject(subject.id);
      const semLabel = semesterLabel(subject.semester);
      entries.push({
        path: `/${course.slug}/${semesterToSlug(subject.semester)}/${subject.slug}`,
        title: composeTitle(`${course.name} ${semLabel} ${subject.name} Papers — Download PDF`),
        description: `Download free ${subject.name} previous year question papers for ${course.name} ${semLabel}, MDU Rohtak. ${papers.length} papers available.`,
        type: 'subject',
      });
    }
  }

  // ---- Individual papers ----
  const allPapers = await getAllPapersWithContext();
  for (const { paper, subject, course, url } of allPapers) {
    const semLabel = semesterLabel(subject.semester);
    const examLabel = `${paper.exam_session} ${paper.year}`;
    entries.push({
      path: url,
      title: composeTitle(
        `${course.name} ${subject.name} ${examLabel} Question Paper — Download PDF`
      ),
      description: `Download the ${course.name} ${semLabel} ${subject.name} previous year question paper for ${examLabel}, MDU Rohtak. Free PDF preview and download.`,
      type: 'paper',
    });
  }

  return entries;
}
