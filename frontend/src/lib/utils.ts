/**
 * Shared helper functions used across the site.
 */

/** Convert any string into a URL-friendly slug. */
export function slugify(text: string): string {
  return text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '') // remove invalid chars
    .replace(/\s+/g, '-') // collapse whitespace to single dash
    .replace(/-+/g, '-'); // collapse multiple dashes
}

/** Map a semester number to its slug, e.g. 3 -> "3rd-sem". */
export function semesterToSlug(semester: number): string {
  return `${ordinal(semester)}-sem`;
}

/** Parse a semester slug back to its number, e.g. "3rd-sem" -> 3. */
export function slugToSemester(slug: string): number | null {
  const match = slug.match(/^(\d+)(?:st|nd|rd|th)?-sem$/);
  if (!match) return null;
  const n = parseInt(match[1], 10);
  return Number.isNaN(n) ? null : n;
}

/** Return the ordinal string for a number, e.g. 1 -> "1st", 3 -> "3rd". */
export function ordinal(n: number): string {
  const s = ['th', 'st', 'nd', 'rd'];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

/** Human-friendly ordinal label, e.g. 3 -> "3rd Semester". */
export function semesterLabel(n: number): string {
  return `${ordinal(n)} Semester`;
}

/** Format a file size given in KB into a readable string. */
export function formatFileSize(kb: number | null | undefined): string {
  if (!kb || kb <= 0) return 'Unknown';
  if (kb < 1024) return `${Math.round(kb)} KB`;
  return `${(kb / 1024).toFixed(1)} MB`;
}

/** Format a number with thousands separators, e.g. 50000 -> "50,000". */
export function formatNumber(n: number): string {
  return new Intl.NumberFormat('en-IN').format(n);
}

/** Format a number compactly with a trailing plus, e.g. 2500 -> "2,500+". */
export function formatCount(n: number): string {
  return `${formatNumber(n)}+`;
}

/** Format an ISO date string into a readable date, e.g. "Jun 26, 2026". */
export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

/** Estimate reading time in minutes from raw text/markdown. */
export function readingTime(text: string): number {
  const words = text.trim().split(/\s+/).length;
  return Math.max(1, Math.round(words / 200));
}

/** Truncate text to a maximum length, appending an ellipsis. */
export function truncate(text: string, max = 150): string {
  if (text.length <= max) return text;
  return text.slice(0, max).trimEnd() + '…';
}

/** Build the canonical URL path for a paper's subject page. */
export function subjectUrl(courseSlug: string, semester: number, subjectSlug: string): string {
  return `/${courseSlug}/${semesterToSlug(semester)}#${subjectSlug}`;
}

/** Slugify an exam session, e.g. "Nov/Dec" -> "nov-dec", "May/June" -> "may-june". */
export function examSessionSlug(session: string): string {
  return slugify(session);
}

/**
 * Build a unique, SEO-friendly slug for a single paper, e.g.
 * "dec-2024" or "dec-2024-bca301". Mirrors the keyword-rich style used by
 * popular MDU paper sites so search engines match real student queries.
 */
export function paperSlug(opts: {
  year: number;
  session: string;
  code?: string | null;
}): string {
  const parts = [examSessionSlug(opts.session), String(opts.year)];
  if (opts.code) parts.push(slugify(opts.code));
  return parts.join('-');
}

/** Build the canonical URL path for an individual paper page. */
export function paperUrl(
  courseSlug: string,
  semester: number,
  subjectSlug: string,
  slug: string
): string {
  return `/${courseSlug}/${semesterToSlug(semester)}#${subjectSlug}`;
}
