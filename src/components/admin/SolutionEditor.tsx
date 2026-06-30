import { useEffect, useState } from 'preact/hooks';
import type { Paper } from '@lib/types';
import { getSolution, upsertSolution, deleteSolution } from '@lib/admin';

interface Props {
  paper: Paper;
  label: string;
  onClose: () => void;
}

export default function SolutionEditor({ paper, label, onClose }: Props) {
  const [content, setContent] = useState('');
  const [pdfUrl, setPdfUrl] = useState('');
  const [author, setAuthor] = useState('MDU Papers Team');
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
          setAuthor(s.author ?? 'MDU Papers Team');
          setPublished(s.is_published);
        }
      })
      .catch((e) => setMsg({ type: 'error', text: e.message }));
  }, [paper.id]);

  const save = async (e: Event) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const { error } = await upsertSolution({
      paper_id: paper.id,
      content: content.trim() || null,
      solution_pdf_url: pdfUrl.trim() || null,
      author: author.trim() || 'MDU Papers Team',
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
    <div class="pdf-modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div class="pdf-modal" style="max-width: 720px; height: auto; max-height: 90vh;">
        <div class="pdf-modal-header">
          <h3>Solution — {label}</h3>
          <button class="icon-btn" onClick={onClose} aria-label="Close">✕</button>
        </div>
        <div style="padding: 1.5rem; overflow-y: auto;">
          {msg && <div class={`admin-alert ${msg.type}`}>{msg.text}</div>}
          <form onSubmit={save}>
            <div class="form-group">
              <label>Solution Content (Markdown)</label>
              <textarea
                class="form-control"
                style="min-height: 240px; font-family: monospace; font-size: 0.85rem;"
                placeholder={'## Section A\n\n1. Answer...\n\n## Section B\n\n- Point one\n- Point two'}
                value={content}
                onInput={(e) => setContent((e.target as HTMLTextAreaElement).value)}
              />
              <p class="text-muted" style="font-size: 0.75rem; margin-top: 0.25rem;">
                Supports Markdown: ## headings, **bold**, lists, &gt; quotes, etc.
              </p>
            </div>
            <div class="form-group">
              <label>Solution PDF URL (optional)</label>
              <input
                class="form-control"
                placeholder="https://…/solution.pdf"
                value={pdfUrl}
                onInput={(e) => setPdfUrl((e.target as HTMLInputElement).value)}
              />
            </div>
            <div class="form-row cols-2">
              <div class="form-group">
                <label>Author</label>
                <input
                  class="form-control"
                  value={author}
                  onInput={(e) => setAuthor((e.target as HTMLInputElement).value)}
                />
              </div>
              <div class="form-group" style="display: flex; align-items: flex-end;">
                <label style="display: flex; gap: 0.5rem; align-items: center; font-weight: 500;">
                  <input
                    type="checkbox"
                    checked={published}
                    onChange={(e) => setPublished((e.target as HTMLInputElement).checked)}
                  />
                  Published
                </label>
              </div>
            </div>
            <div style="display: flex; gap: 0.75rem;">
              <button type="submit" class="btn btn-primary" disabled={busy}>
                {busy ? 'Saving…' : 'Save Solution'}
              </button>
              {exists && (
                <button type="button" class="btn btn-danger" onClick={remove}>
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
