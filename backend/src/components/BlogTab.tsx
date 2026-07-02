import { useEffect, useState } from 'react';
import type { BlogPost } from '../lib/types';
import { listBlogPosts, upsertBlogPost, deleteBlogPost } from '../lib/admin';
import { slugify } from '../lib/utils';

const empty = {
  id: undefined as number | undefined,
  slug: '',
  title: '',
  description: '',
  content: '',
  author: 'MDU Papers Team',
  tags: '',
  is_published: true,
};

export default function BlogTab() {
  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [form, setForm] = useState({ ...empty });
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const load = async () => {
    try {
      setPosts(await listBlogPosts());
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };

  useEffect(() => {
    load();
  }, []);

  const set = (k: string, v: unknown) => setForm((f) => ({ ...f, [k]: v }));

  const edit = (p: BlogPost) => {
    setForm({
      id: p.id,
      slug: p.slug,
      title: p.title,
      description: p.description,
      content: p.content,
      author: p.author,
      tags: (p.tags ?? []).join(', '),
      is_published: p.is_published,
    });
    setMsg(null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const reset = () => {
    setForm({ ...empty });
    setMsg(null);
  };

  const submit = async (e: any) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const slug = form.slug || slugify(form.title);
    const tags = form.tags
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);

    const { error } = await upsertBlogPost({
      id: form.id,
      slug,
      title: form.title,
      description: form.description,
      content: form.content,
      author: form.author || 'MDU Papers Team',
      tags,
      is_published: form.is_published,
    });
    setBusy(false);
    if (error) {
      setMsg({ type: 'error', text: error.message });
    } else {
      setMsg({ type: 'success', text: `Saved "${form.title}". Publish to make it live.` });
      reset();
      load();
    }
  };

  const remove = async (p: BlogPost) => {
    if (!confirm(`Delete blog post "${p.title}"?`)) return;
    const { error } = await deleteBlogPost(p.id);
    if (error) setMsg({ type: 'error', text: error.message });
    else load();
  };

  return (
    <div>
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '1rem' }}>{form.id ? 'Edit Blog Post' : 'New Blog Post'}</h3>
        {msg && <div className={`admin-alert ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={submit}>
          <div className="form-group">
            <label>Title</label>
            <input
              className="form-control"
              placeholder="How to prepare for MDU exams"
              value={form.title}
              onInput={(e) => set('title', (e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <div className="form-row cols-2">
            <div className="form-group">
              <label>Slug (auto if blank)</label>
              <input
                className="form-control"
                placeholder={slugify(form.title) || 'how-to-prepare'}
                value={form.slug}
                onInput={(e) => set('slug', (e.target as HTMLInputElement).value)}
                disabled={Boolean(form.id)}
              />
            </div>
            <div className="form-group">
              <label>Tags (comma separated)</label>
              <input
                className="form-control"
                placeholder="Exam Tips, BCA"
                value={form.tags}
                onInput={(e) => set('tags', (e.target as HTMLInputElement).value)}
              />
            </div>
          </div>
          <div className="form-group">
            <label>Short Description (for cards & SEO)</label>
            <input
              className="form-control"
              placeholder="A one-line summary shown on the blog list and Google."
              value={form.description}
              onInput={(e) => set('description', (e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <div className="form-group">
            <label>Content (Markdown)</label>
            <textarea
              className="form-control"
              style={{ minHeight: '300px', fontFamily: 'monospace', fontSize: '0.85rem' }}
              placeholder={'## Heading\n\nYour content here.\n\n- bullet one\n- bullet two\n\n**bold** and [link](https://example.com)'}
              value={form.content}
              onInput={(e) => set('content', (e.target as HTMLTextAreaElement).value)}
              required
            />
            <p className="text-muted" style={{ fontSize: '0.75rem', marginTop: '0.25rem' }}>
              Markdown: ## heading, ### sub-heading, **bold**, - lists, &gt; quotes, [text](url)
            </p>
          </div>
          <div className="form-row cols-2">
            <div className="form-group">
              <label>Author</label>
              <input
                className="form-control"
                value={form.author}
                onInput={(e) => set('author', (e.target as HTMLInputElement).value)}
              />
            </div>
            <div className="form-group" style={{ display: 'flex', alignItems: 'flex-end' }}>
              <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', fontWeight: 500 }}>
                <input
                  type="checkbox"
                  checked={form.is_published}
                  onChange={(e) => set('is_published', (e.target as HTMLInputElement).checked)}
                />
                Published
              </label>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '0.75rem' }}>
            <button type="submit" className="btn btn-primary" disabled={busy}>
              {busy ? 'Saving…' : form.id ? 'Update Post' : 'Create Post'}
            </button>
            {form.id && (
              <button type="button" className="btn btn-secondary" onClick={reset}>
                Cancel / New
              </button>
            )}
          </div>
        </form>
      </div>

      <div className="card">
        <h3 style={{ marginBottom: '1rem' }}>Blog Posts ({posts.length})</h3>
        <div style={{ overflowX: 'auto' }}>
          <table className="admin-table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Tags</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {posts.map((p) => (
                <tr>
                  <td>{p.title}</td>
                  <td>{(p.tags ?? []).join(', ') || '—'}</td>
                  <td>
                    {p.is_published ? (
                      <span className="badge badge-success">Live</span>
                    ) : (
                      <span className="badge badge-secondary">Draft</span>
                    )}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-secondary btn-sm" onClick={() => edit(p)}>
                        Edit
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => remove(p)}>
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {posts.length === 0 && (
            <p className="text-muted" style={{ padding: '1rem 0' }}>
              No blog posts in the database yet. Markdown posts in the repo still show on the
              site; create one here to manage posts without code.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
