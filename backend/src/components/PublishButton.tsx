import { useState } from 'react';

const DEPLOY_HOOK = import.meta.env.PUBLIC_DEPLOY_HOOK_URL as string | undefined;

/**
 * Triggers a Cloudflare Pages rebuild via a Deploy Hook so newly added papers
 * and solutions go live. Only renders when PUBLIC_DEPLOY_HOOK_URL is set.
 */
export default function PublishButton() {
  const [state, setState] = useState<'idle' | 'busy' | 'done' | 'error'>('idle');

  if (!DEPLOY_HOOK) return null;

  const publish = async () => {
    if (!confirm('Trigger a site rebuild to publish your latest changes?')) return;
    setState('busy');
    try {
      await fetch(DEPLOY_HOOK, { method: 'POST', mode: 'no-cors' });
      setState('done');
      setTimeout(() => setState('idle'), 4000);
    } catch {
      setState('error');
      setTimeout(() => setState('idle'), 4000);
    }
  };

  const label =
    state === 'busy'
      ? 'Publishing…'
      : state === 'done'
        ? '✓ Build triggered'
        : state === 'error'
          ? 'Failed — retry'
          : '🚀 Publish changes';

  return (
    <button
      className={`btn btn-sm ${state === 'done' ? 'btn-success' : 'btn-primary'}`}
      onClick={publish}
      disabled={state === 'busy'}
      title="Rebuild the site to publish new papers and solutions"
    >
      {label}
    </button>
  );
}
