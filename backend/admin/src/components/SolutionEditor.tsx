import { useEffect, useState } from 'react';
import type { Paper } from '../lib/types';
import { getSolution, upsertSolution, deleteSolution } from '../lib/admin';

interface Props {
  paper: Paper;
  label: string;
  onClose: () => void;
}

export default function SolutionEditor({ paper, label, onClose }: Props) {
  const [content, setContent] = useState('');
  const [pdfUrl, setPdfUrl] = useState('');
  const [author, setAuthor] = useState('mdupyq Team');
  const [published, setPublished] = useState(true);
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [exists, setExists] = useState(false);

  useEffect(() => {
    getSolution(paper.id)
      .then((s) => {
        if (s) {
          setExists(true);
          setContent(s.content ?? '');
          setPdfUrl(s.solution_pdf_url ?? '');
          setAuthor(s.author ?? 'mdupyq Team');
          setPublished(s.is_published);
        }
      })
      .catch((e) => setMsg({ type: 'error', text: e.message }));
  }, [paper.id]);

  const save = async (e: any) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const { error } = await upsertSolution({
      paper_id: paper.id,
      content: content.trim() || null,
      solution_pdf_url: pdfUrl.trim() || null,
      author: author.trim() || 'mdupyq Team',
      is_published: published,
    });
    setBusy(false);
    if (error) setMsg({ type: 'error', text: error.message });
    else {
      setExists(true);
      setMsg({ type: 'success', text: 'Solution saved. Rebuild the site to publish it.' });
    }
  };

  const remove = async () => {
    if (!confirm('Delete this solution?')) return;
    const { error } = await deleteSolution(paper.id);
    if (error) setMsg({ type: 'error', text: error.message });
    else {
      setExists(false);
      setContent('');
      setPdfUrl('');
      setMsg({ type: 'success', text: 'Solution deleted.' });
    }
  };

  return (
    <div className="pdf-modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="pdf-modal" style={{ maxWidth: '720px', height: 'auto', maxHeight: '90vh' }}>
        <div className="pdf-modal-header">
          <h3>Solution — {label}</h3>
          <button className="icon-btn" onClick={onClose} aria-label="Close">✕</button>
        </div>
        <div style={{ padding: '1.5rem', overflowY: 'auto' }}>
          {msg && <div className={`admin-alert ${msg.type}`}>{msg.text}</div>}
          <form onSubmit={save}>
            <div className="form-group">
              <label>Solution Content (Markdown)</label>
              <textarea
                className="form-control"
                style={{ minHeight: '240px', fontFamily: 'monospace', fontSize: '0.85rem' }}
                placeholder={'## Section A\n\n1. Answer...\n\n## Section B\n\n- Point one\n- Point two'}
                value={content}
                onInput={(e) => setContent((e.target as HTMLTextAreaElement).value)}
              />
              <p className="text-muted" style={{ fontSize: '0.75rem', marginTop: '0.25rem' }}>
                Supports Markdown: ## headings, **bold**, lists, &gt; quotes, etc.
              </p>
            </div>
            <div className="form-group">
              <label>Solution PDF URL (optional)</label>
              <input
                className="form-control"
                placeholder="https://…/solution.pdf"
                value={pdfUrl}
                onInput={(e) => setPdfUrl((e.target as HTMLInputElement).value)}
              />
            </div>
            <div className="form-row cols-2">
              <div className="form-group">
                <label>Author</label>
                <input
                  className="form-control"
                  value={author}
                  onInput={(e) => setAuthor((e.target as HTMLInputElement).value)}
                />
              </div>
              <div className="form-group" style={{ display: 'flex', alignItems: 'flex-end' }}>
                <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', fontWeight: 500 }}>
                  <input
                    type="checkbox"
                    checked={published}
                    onChange={(e) => setPublished((e.target as HTMLInputElement).checked)}
                  />
                  Published
                </label>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <button type="submit" className="btn btn-primary" disabled={busy}>
                {busy ? 'Saving…' : 'Save Solution'}
              </button>
              {exists && (
                <button type="button" className="btn btn-danger" onClick={remove}>
                  Delete
                </button>
              )}
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
