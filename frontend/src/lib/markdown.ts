import { marked } from 'marked';
import { slugify } from './utils';

export interface Heading {
  depth: number;
  text: string;
  slug: string;
}

/**
 * Render markdown to HTML, adding `id` anchors to h2/h3 headings, and return
 * the extracted headings for building a table of contents.
 */
export async function renderMarkdown(
  md: string
): Promise<{ html: string; headings: Heading[] }> {
  const headings: Heading[] = [];
  const used = new Set<string>();

  const renderer = new marked.Renderer();
  // marked v18 passes a token object to heading()
  renderer.heading = ({ tokens, depth }: { tokens: { raw: string }[]; depth: number }) => {
    const text = tokens.map((t) => t.raw).join('');
    let slug = slugify(text);
    while (used.has(slug)) slug = `${slug}-x`;
    used.add(slug);
    if (depth === 2 || depth === 3) {
      headings.push({ depth, text, slug });
    }
    // Inline-parse the heading text so bold/links inside still render.
    const inner = marked.parseInline(text) as string;
    return `<h${depth} id="${slug}">${inner}</h${depth}>`;
  };

  const html = await marked.parse(md, { renderer });
  return { html, headings };
}
