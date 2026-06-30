import { getCollection } from 'astro:content';
import { getDbBlogPosts, type UnifiedBlogPost } from './data';

/**
 * Returns all blog posts merged from two sources:
 *  - Supabase `blog_posts` table (admin-managed)
 *  - Markdown files in src/content/blog (committed in the repo)
 *
 * DB posts take precedence if a slug exists in both. Sorted newest first.
 */
export async function getAllBlogPosts(): Promise<UnifiedBlogPost[]> {
  const dbPosts = await getDbBlogPosts();

  const mdEntries = await getCollection('blog');
  const mdPosts: UnifiedBlogPost[] = mdEntries.map((entry) => ({
    slug: entry.slug,
    title: entry.data.title,
    description: entry.data.description,
    author: entry.data.author,
    tags: entry.data.tags ?? [],
    pubDate: entry.data.pubDate,
    body: entry.body,
    source: 'markdown' as const,
  }));

  // DB wins on slug collisions.
  const dbSlugs = new Set(dbPosts.map((p) => p.slug));
  const merged = [...dbPosts, ...mdPosts.filter((p) => !dbSlugs.has(p.slug))];

  return merged.sort((a, b) => b.pubDate.valueOf() - a.pubDate.valueOf());
}

export async function getBlogPostBySlug(slug: string): Promise<UnifiedBlogPost | null> {
  const all = await getAllBlogPosts();
  return all.find((p) => p.slug === slug) ?? null;
}
