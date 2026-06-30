import { useEffect, useMemo, useRef, useState } from 'preact/hooks';
import Fuse from 'fuse.js';
import type { SearchEntry } from '@lib/types';

interface Props {
  /** Where to load the prebuilt index JSON from. */
  indexUrl?: string;
  placeholder?: string;
  /** If true, behaves as a full-page search (no dropdown, renders results). */
  fullPage?: boolean;
  /** Initial query (used by the search results page). */
  initialQuery?: string;
  /** Autofocus the input on mount. */
  autoFocus?: boolean;
}

interface Grouped {
  course: string;
  items: SearchEntry[];
}

export default function SearchBar({
  indexUrl = '/search-index.json',
  placeholder = 'Search papers... e.g. "BCA math 2024"',
  fullPage = false,
  initialQuery = '',
  autoFocus = false,
}: Props) {
  const [query, setQuery] = useState(initialQuery);
  const [index, setIndex] = useState<SearchEntry[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const wrapRef = useRef<HTMLDivElement>(null);

  // Lazy-load the index on first focus / mount for full page.
  const loadIndex = async () => {
    if (loaded) return;
    try {
      const res = await fetch(indexUrl);
      const data = (await res.json()) as SearchEntry[];
      setIndex(data);
    } catch (e) {
      console.error('Failed to load search index', e);
    } finally {
      setLoaded(true);
    }
  };

  useEffect(() => {
    if (fullPage) loadIndex();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fuse = useMemo(
    () =>
      new Fuse(index, {
        keys: [
          { name: 'subject', weight: 0.5 },
          { name: 'course', weight: 0.3 },
          { name: 'subjectCode', weight: 0.1 },
          { name: 'year', weight: 0.1 },
        ],
        threshold: 0.4,
        ignoreLocation: true,
        useExtendedSearch: true,
      }),
    [index]
  );

  const results = useMemo(() => {
    const q = query.trim();
    if (!q) return [];
    return fuse.search(q).map((r) => r.item);
  }, [query, fuse]);

  // De-duplicate by URL for the dropdown (group identical subjects).
  const dropdownItems = useMemo(() => {
    const seen = new Set<string>();
    const out: SearchEntry[] = [];
    for (const r of results) {
      if (!seen.has(r.url)) {
        seen.add(r.url);
        out.push(r);
      }
      if (out.length >= 8) break;
    }
    return out;
  }, [results]);

  // Group full-page results by course.
  const grouped = useMemo<Grouped[]>(() => {
    const map = new Map<string, SearchEntry[]>();
    for (const r of results) {
      if (!map.has(r.course)) map.set(r.course, []);
      map.get(r.course)!.push(r);
    }
    return [...map.entries()].map(([course, items]) => ({ course, items }));
  }, [results]);

  // Close dropdown on outside click.
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const onInput = (e: Event) => {
    const value = (e.target as HTMLInputElement).value;
    setQuery(value);
    setOpen(true);
    setActiveIndex(-1);
  };

  const goToSearch = () => {
    const q = query.trim();
    if (q) window.location.href = `/search?q=${encodeURIComponent(q)}`;
  };

  const onKeyDown = (e: KeyboardEvent) => {
    if (fullPage) {
      if (e.key === 'Enter') goToSearch();
      return;
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, dropdownItems.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, -1));
    } else if (e.key === 'Enter') {
      if (activeIndex >= 0 && dropdownItems[activeIndex]) {
        window.location.href = dropdownItems[activeIndex].url;
      } else {
        goToSearch();
      }
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  };

  const SearchIcon = (
    <svg class="search-icon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );

  return (
    <div class="search-wrap" ref={wrapRef}>
      <div class="search-input-row">
        {SearchIcon}
        <input
          type="search"
          class="search-input"
          value={query}
          placeholder={placeholder}
          aria-label="Search exam papers"
          // eslint-disable-next-line jsx-a11y/no-autofocus
          autoFocus={autoFocus}
          onInput={onInput}
          onFocus={() => {
            loadIndex();
            if (!fullPage) setOpen(true);
          }}
          onKeyDown={onKeyDown}
          role="combobox"
          aria-expanded={open && dropdownItems.length > 0}
          aria-controls="search-listbox"
          autocomplete="off"
        />
      </div>

      {/* Dropdown (homepage / header mode) */}
      {!fullPage && open && query.trim().length > 0 && (
        <div class="search-results-dropdown" id="search-listbox" role="listbox">
          {dropdownItems.length === 0 ? (
            <div class="search-empty">
              {loaded ? `No matches for "${query}"` : 'Loading…'}
            </div>
          ) : (
            dropdownItems.map((item, i) => (
              <a
                key={item.url + i}
                href={item.url}
                class={`search-result-item ${i === activeIndex ? 'active' : ''}`}
                role="option"
                aria-selected={i === activeIndex}
              >
                <span>
                  <span class="search-result-title">
                    {item.subject}
                  </span>
                  <br />
                  <span class="search-result-meta">
                    {item.course} · Sem {item.semester}
                    {item.subjectCode ? ` · ${item.subjectCode}` : ''}
                  </span>
                </span>
                <span class="badge badge-secondary">View</span>
              </a>
            ))
          )}
        </div>
      )}

      {/* Full-page results */}
      {fullPage && (
        <div class="mt-8">
          {query.trim().length === 0 ? (
            <div class="empty-state">
              <div class="empty-icon">🔍</div>
              <p>Start typing to search across all papers.</p>
            </div>
          ) : results.length === 0 ? (
            <div class="empty-state">
              <div class="empty-icon">📭</div>
              <h3>No results found for "{query}"</h3>
              <p class="text-muted">
                Try a different keyword, or browse all courses instead.
              </p>
              <a href="/courses" class="btn btn-primary mt-8">Browse Courses</a>
            </div>
          ) : (
            <div>
              <p class="text-muted mb-4">
                Found {results.length} result{results.length === 1 ? '' : 's'}
              </p>
              {grouped.map((group) => (
                <section key={group.course} style="margin-bottom: 2rem;">
                  <h2 class="section-title" style="font-size: 1.25rem;">
                    {group.course}
                  </h2>
                  <div class="grid grid-auto">
                    {group.items.map((item, i) => (
                      <a key={item.url + i} href={item.url} class="card">
                        <div class="search-result-title">{item.subject}</div>
                        <div class="search-result-meta" style="margin-top: 0.5rem;">
                          Sem {item.semester} · {item.year} · {item.session}
                          {item.subjectCode ? ` · ${item.subjectCode}` : ''}
                        </div>
                      </a>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
