import { useEffect, useMemo, useRef, useState } from 'preact/hooks';

interface SeoEntry {
  path: string;
  title: string;
  description: string;
  type: string;
  noindex?: boolean;
}

interface Props {
  siteUrl: string;
  siteName: string;
  indexUrl?: string;
}

// Approximate Google pixel limits (desktop). Titles ~600px, descriptions ~960px.
// We use character counts as a practical proxy.
const TITLE_MAX = 60;
const DESC_MAX = 160;

const TYPES = [
  { key: 'all', label: 'All' },
  { key: 'core', label: 'Core' },
  { key: 'course', label: 'Courses' },
  { key: 'semester', label: 'Semesters' },
  { key: 'subject', label: 'Subjects' },
  { key: 'paper', label: 'Papers' },
  { key: 'blog', label: 'Blog' },
  { key: 'legal', label: 'Legal' },
];

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return text.slice(0, max).trimEnd() + '…';
}

function lenClass(len: number, min: number, max: number): string {
  return len >= min && len <= max ? 'serp-len-ok' : 'serp-len-warn';
}

/** Format a path into Google's breadcrumb-style URL display. */
function displayUrl(siteUrl: string, path: string): string {
  const host = siteUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
  if (path === '/') return host;
  const segments = path.split('/').filter(Boolean);
  return `${host} › ${segments.join(' › ')}`;
}

export default function SerpPreview({ siteUrl, siteName, indexUrl = '/seo-index.json' }: Props) {
  const [entries, setEntries] = useState<SeoEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');
  const [type, setType] = useState('all');
  const [device, setDevice] = useState<'desktop' | 'mobile'>('desktop');
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(indexUrl)
      .then((r) => r.json())
      .then((data: SeoEntry[]) => setEntries(data))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, [indexUrl]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return entries.filter((e) => {
      if (type !== 'all' && e.type !== type) return false;
      if (!q) return true;
      return (
        e.path.toLowerCase().includes(q) ||
        e.title.toLowerCase().includes(q) ||
        e.description.toLowerCase().includes(q)
      );
    });
  }, [entries, query, type]);

  // Show a capped list for performance; papers can be in the hundreds.
  const visible = filtered.slice(0, 100);

  const counts = useMemo(() => {
    const titleIssues = entries.filter((e) => e.title.length > TITLE_MAX || e.title.length < 20).length;
    const descIssues = entries.filter(
      (e) => e.description.length > DESC_MAX || e.description.length < 70
    ).length;
    return { titleIssues, descIssues };
  }, [entries]);

  if (loading) return <div class="skeleton" style="height: 300px;" />;
  if (error)
    return <div class="admin-alert error">Failed to load SEO data: {error}</div>;

  const inputRef = useRef<HTMLInputElement>(null);

  const clearSearch = () => {
    setQuery('');
    inputRef.current?.focus();
  };

  return (
    <div>
      <div class="serp-stats">
        <span>📄 <strong>{entries.length}</strong> total pages</span>
        <span>⚠️ <strong>{counts.titleIssues}</strong> title length issues</span>
        <span>⚠️ <strong>{counts.descIssues}</strong> description length issues</span>
      </div>

      <div class="serp-toolbar">
        <div class="search-wrap">
          <div class="search-input-row">
            <svg class="search-icon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <circle cx="11" cy="11" r="8" />
              <path d="m21 21-4.3-4.3" />
            </svg>
            <input
              ref={inputRef}
              type="search"
              class="search-input"
              style={{ paddingRight: '3rem' }}
              aria-label="Filter SEO entries by path, title or description"
              placeholder="Filter by path, title or description…"
              value={query}
              onInput={(e) => setQuery((e.target as HTMLInputElement).value)}
            />
            {query.length > 0 && (
              <button
                type="button"
                class="icon-btn"
                style={{ position: 'absolute', right: '0.25rem' }}
                aria-label="Clear search"
                onClick={clearSearch}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M18 6 6 18M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>
        </div>
        <div class="serp-device-toggle" role="group" aria-label="Device">
          <button
            class={device === 'desktop' ? 'active' : ''}
            onClick={() => setDevice('desktop')}
            aria-pressed={device === 'desktop'}
          >
            🖥️ Desktop
          </button>
          <button
            class={device === 'mobile' ? 'active' : ''}
            onClick={() => setDevice('mobile')}
            aria-pressed={device === 'mobile'}
          >
            📱 Mobile
          </button>
        </div>
      </div>

      <div class="serp-filters" role="group" aria-label="Page types">
        {TYPES.map((t) => (
          <button
            key={t.key}
            class={`serp-filter-btn ${type === t.key ? 'active' : ''}`}
            onClick={() => setType(t.key)}
            aria-pressed={type === t.key}
          >
            {t.label}
          </button>
        ))}
      </div>

      <p class="text-muted" style="font-size: 0.875rem; margin-bottom: 1rem;">
        Showing {visible.length} of {filtered.length} matching pages
        {filtered.length > 100 && ' (first 100 — refine your filter to see more)'}
      </p>

      {visible.map((e) => {
        const titleLen = e.title.length;
        const descLen = e.description.length;
        const shownTitle = truncate(e.title, device === 'mobile' ? 55 : TITLE_MAX);
        const shownDesc = truncate(e.description, device === 'mobile' ? 130 : DESC_MAX);
        return (
          <div key={e.path} class={`serp-result ${device}`}>
            <a class="serp-link" href={e.path}>
              <div class="serp-fav-row">
                <img class="serp-fav" src="/favicon.svg" alt="" width="26" height="26" />
                <div class="serp-site">
                  <div class="serp-site-name">{siteName}</div>
                  <div class="serp-url">{displayUrl(siteUrl, e.path)}</div>
                </div>
              </div>
              <div class="serp-title">
                {shownTitle}
                {e.noindex && <span class="serp-badge">NOINDEX</span>}
              </div>
            </a>
            <div class="serp-desc">{shownDesc}</div>
            <div class="serp-meta-line">
              <span>
                Title: <span class={lenClass(titleLen, 20, TITLE_MAX)}>{titleLen} chars</span>
              </span>
              <span>
                Description:{' '}
                <span class={lenClass(descLen, 70, DESC_MAX)}>{descLen} chars</span>
              </span>
              <a href={e.path} target="_blank" rel="noopener noreferrer" style="color: var(--accent-primary);">
                Open in new tab ↗
              </a>
            </div>
          </div>
        );
      })}
    </div>
  );
}
