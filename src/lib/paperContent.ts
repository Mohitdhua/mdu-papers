import type { Paper, Subject, Course } from './types';
import { semesterLabel } from './utils';

/**
 * Generates unique, content-rich text + FAQs for each paper page.
 * This fights "thin content" by deriving page-specific copy from the paper's
 * own attributes (course, subject, code, year, session) rather than a single
 * shared template string.
 */

export interface PaperFaq {
  question: string;
  answer: string;
}

export interface PaperContent {
  /** A longer, unique intro paragraph for the page body. */
  intro: string;
  /** A second paragraph with study guidance. */
  howToUse: string;
  /** FAQs rendered on-page and as FAQPage JSON-LD. */
  faqs: PaperFaq[];
}

export function buildPaperContent(
  paper: Paper,
  subject: Subject,
  course: Course
): PaperContent {
  const semLabel = semesterLabel(subject.semester);
  const examLabel = `${paper.exam_session} ${paper.year}`;
  const code = subject.subject_code ? ` (subject code ${subject.subject_code})` : '';
  const pages = paper.page_count ? `${paper.page_count}-page` : '';

  // Parse admin-entered topics (comma or newline separated).
  const topics = (paper.topics ?? '')
    .split(/[,\n]/)
    .map((t) => t.trim())
    .filter(Boolean);
  const hasTopics = topics.length > 0;
  const topicsSentence = hasTopics
    ? topics.slice(0, -1).join(', ') + (topics.length > 1 ? ' and ' : '') + topics[topics.length - 1]
    : '';

  const intro =
    `This page provides the ${course.name} ${semLabel} ${subject.name}${code} ` +
    `previous year question paper from the ${examLabel} examination conducted by ` +
    `Maharshi Dayanand University (MDU), Rohtak. This ${pages} ${course.full_name} ` +
    `question paper is part of the official ${course.name} ${semLabel} syllabus and is ` +
    `provided free of cost for students preparing for their upcoming MDU semester exams. ` +
    `You can preview the full paper above and download the PDF for offline practice.`;

  const howToUse =
    `Practising with the ${subject.name} ${paper.year} paper helps you understand the ` +
    `${course.name} exam pattern, identify frequently asked topics, and improve your ` +
    `time management. For best results, attempt this ${examLabel} paper under timed exam ` +
    `conditions, then review your answers against your study material. Browsing multiple ` +
    `years of ${subject.name} papers reveals which questions and topics repeat most often ` +
    `in MDU ${course.name} ${semLabel} examinations.`;

  // --- Dynamic FAQs: questions are templated per course/subject/year,
  //     answers use the admin-entered topics when available (unique content). ---
  const faqs: PaperFaq[] = [];

  // Q1 — main topics (answer is unique when topics are provided).
  faqs.push({
    question: `What were the main topics asked in the ${course.name} ${semLabel} ${subject.name} ${examLabel} paper?`,
    answer: hasTopics
      ? `The ${subject.name} ${examLabel} paper covered topics such as ${topicsSentence}. ` +
        `Reviewing these areas will help you focus your preparation for the ${course.name} ` +
        `${semLabel} ${subject.name} examination.`
      : `This ${subject.name} ${examLabel} paper covers the core topics from the ${course.name} ` +
        `${semLabel} syllabus. Preview or download the paper above to see the exact questions ` +
        `and topics that were asked.`,
  });

  // Q2 — download.
  faqs.push({
    question: `How can I download the ${subject.name} ${examLabel} question paper?`,
    answer:
      `Click the "Download PDF" button on this page to download the ${course.name} ` +
      `${semLabel} ${subject.name} ${examLabel} previous year question paper for free. ` +
      `You can also preview the full paper directly on this page before downloading.`,
  });

  // Q3 — usefulness.
  faqs.push({
    question: `Is the ${subject.name} previous year paper useful for exam preparation?`,
    answer:
      `Yes. Previous year papers like this ${subject.name} ${paper.year} paper are one of ` +
      `the most effective ways to prepare for MDU ${course.name} ${semLabel} exams, as they ` +
      `reveal the exam pattern, marking scheme and commonly repeated questions.`,
  });

  // Q4 — university / session.
  faqs.push({
    question: `Which university conducted this ${subject.name} examination?`,
    answer:
      `This ${subject.name}${code} paper was set by Maharshi Dayanand University (MDU), ` +
      `Rohtak for the ${course.name} ${semLabel} course in the ${examLabel} session.`,
  });

  // Q5 — subject code (only if available).
  if (subject.subject_code) {
    faqs.push({
      question: `What is the subject code for ${subject.name} in ${course.name}?`,
      answer: `The subject code for ${subject.name} in ${course.name} ${semLabel} is ${subject.subject_code}.`,
    });
  }

  return { intro, howToUse, faqs };
}
