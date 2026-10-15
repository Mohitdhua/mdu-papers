import { useEffect, useState, useRef } from 'preact/hooks';

interface Props {
  pdfUrl: string;
  title: string;
  paperId: number;
  /** Pre-rendered label for the trigger button. */
  buttonLabel?: string;
}

/**
 * Renders a "Preview" button that opens a modal with the PDF in an iframe.
 * Also exposes a download action that pings the increment endpoint.
 */
export default function PdfViewer({ pdfUrl, title, paperId, buttonLabel = 'Preview Paper' }: Props) {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const handleClose = () => {
    setOpen(false);
    setTimeout(() => {
      triggerRef.current?.focus();
    }, 0);
  };

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open]);

  const trackDownload = () => {
    // Fire-and-forget download counter increment.
    try {
      // Stored globally by an inline init script in the page if Supabase is set.
      const fn = (window as unknown as { __incrementDownload?: (id: number) => void })
        .__incrementDownload;
      if (fn) fn(paperId);
    } catch {
      /* ignore */
    }
  };

  const onDownload = () => {
    trackDownload();
    window.open(pdfUrl, '_blank', 'noopener,noreferrer');
  };

  return (
    <>
      <button ref={triggerRef} type="button" class="btn btn-secondary" onClick={() => setOpen(true)}>
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" />
          <circle cx="12" cy="12" r="3" />
        </svg>
        {buttonLabel}
      </button>

      {open && (
        <div
          class="pdf-modal-overlay"
          role="dialog"
          aria-modal="true"
          aria-label={`Preview: ${title}`}
          onClick={(e) => {
            if (e.target === e.currentTarget) handleClose();
          }}
        >
          <div class="pdf-modal">
            <div class="pdf-modal-header">
              <h3>{title}</h3>
              <div class="pdf-modal-actions">
                <button type="button" class="btn btn-success btn-download" onClick={onDownload}>
                  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" x2="12" y1="15" y2="3" />
                  </svg>
                  Download
                </button>
                <button
                  type="button"
                  class="icon-btn"
                  onClick={handleClose}
                  aria-label="Close preview"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M18 6 6 18M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            <div class="pdf-modal-body">
              <iframe src={pdfUrl} title={`PDF preview: ${title}`} loading="lazy" />
            </div>
          </div>
        </div>
      )}
    </>
  );
}
