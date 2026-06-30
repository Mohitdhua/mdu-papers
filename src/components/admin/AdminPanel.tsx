import { useEffect, useState } from 'preact/hooks';
import type { Session } from '@supabase/supabase-js';
import {
  adminConfigured,
  getSession,
  signIn,
  signOut,
  onAuthChange,
} from '@lib/admin';
import LoginForm from './LoginForm';
import CoursesTab from './CoursesTab';
import SubjectsTab from './SubjectsTab';
import PapersTab from './PapersTab';
import BlogTab from './BlogTab';
import PublishButton from './PublishButton';

type Tab = 'papers' | 'subjects' | 'courses' | 'blog';

export default function AdminPanel() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>('papers');

  useEffect(() => {
    if (!adminConfigured) {
      setLoading(false);
      return;
    }
    getSession().then((s) => {
      setSession(s);
      setLoading(false);
    });
    const { data } = onAuthChange((s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  if (!adminConfigured) {
    return (
      <div class="admin-login">
        <div class="admin-alert info">
          <strong>Supabase not configured.</strong> Add your <code>PUBLIC_SUPABASE_URL</code> and{' '}
          <code>PUBLIC_SUPABASE_ANON_KEY</code> to <code>.env</code>, run the SQL in{' '}
          <code>supabase/schema.sql</code>, then reload this page to manage papers. PDF uploads
          use Cloudflare R2 — see <code>CLOUDFLARE_R2_SETUP.md</code>.
        </div>
      </div>
    );
  }

  if (loading) {
    return <div class="skeleton" style="height: 200px;" />;
  }

  if (!session) {
    return <LoginForm onSignIn={signIn} />;
  }

  return (
    <div class="admin-shell">
      <div class="admin-bar">
        <span class="admin-user">
          Signed in as <strong>{session.user.email}</strong>
        </span>
        <div style="display: flex; gap: 0.5rem;">
          <PublishButton />
          <button class="btn btn-secondary btn-sm" onClick={() => signOut()}>
            Sign out
          </button>
        </div>
      </div>

      <div class="admin-tabs" role="tablist">
        <button
          class={`tab-btn ${tab === 'papers' ? 'active' : ''}`}
          onClick={() => setTab('papers')}
        >
          📄 Papers
        </button>
        <button
          class={`tab-btn ${tab === 'subjects' ? 'active' : ''}`}
          onClick={() => setTab('subjects')}
        >
          📚 Subjects
        </button>
        <button
          class={`tab-btn ${tab === 'courses' ? 'active' : ''}`}
          onClick={() => setTab('courses')}
        >
          🎓 Courses
        </button>
        <button
          class={`tab-btn ${tab === 'blog' ? 'active' : ''}`}
          onClick={() => setTab('blog')}
        >
          📝 Blog
        </button>
      </div>

      {tab === 'papers' && <PapersTab />}
      {tab === 'subjects' && <SubjectsTab />}
      {tab === 'courses' && <CoursesTab />}
      {tab === 'blog' && <BlogTab />}
    </div>
  );
}
