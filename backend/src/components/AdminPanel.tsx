import { useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import {
  adminConfigured,
  getSession,
  signIn,
  signOut,
  onAuthChange,
  verifyPaper,
  listUnverifiedPapers,
  deletePaper,
  deletePaperPdf,
} from '../lib/admin';
import LoginForm from './LoginForm';
import PapersTab from './PapersTab';
import ManageTab from './ManageTab';
import ContributionsTab from './ContributionsTab';
import BlogTab from './BlogTab';
import PublishButton from './PublishButton';

type Tab = 'add' | 'manage' | 'contributions' | 'blog';

export default function AdminPanel() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>('add');
  const [unverifiedPapers, setUnverifiedPapers] = useState<any[]>([]);

  const loadUnverified = () => {
    if (!adminConfigured) return;
    listUnverifiedPapers()
      .then(setUnverifiedPapers)
      .catch((e) => console.error('[admin] Failed to load unverified papers:', e));
  };

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
    loadUnverified();
    return () => data.subscription.unsubscribe();
  }, []);

  const handleApprove = async (pId: number) => {
    try {
      await verifyPaper(pId);
      loadUnverified();
    } catch (err) {
      alert((err as Error).message);
    }
  };

  const handleReject = async (p: any) => {
    if (!confirm(`Reject and delete the ${p.exam_session} ${p.year} paper?`)) return;
    try {
      const { error } = await deletePaper(p.id);
      if (error) throw error;
      if (p.r2_key) {
        try {
          await deletePaperPdf(p.r2_key);
        } catch {
          /* ignore */
        }
      }
      loadUnverified();
    } catch (err) {
      alert((err as Error).message);
    }
  };

  if (!adminConfigured) {
    return (
      <div className="admin-login">
        <div className="admin-alert info">
          <strong>Supabase not configured.</strong> Add your <code>PUBLIC_SUPABASE_URL</code> and{' '}
          <code>PUBLIC_SUPABASE_ANON_KEY</code> to <code>.env</code>, run the SQL in{' '}
          <code>supabase/schema.sql</code>, then reload this page to manage papers. PDF uploads
          use Cloudflare R2 — see <code>CLOUDFLARE_R2_SETUP.md</code>.
        </div>
      </div>
    );
  }

  if (loading) {
    return <div className="skeleton" style={{ height: '200px' }} />;
  }

  if (!session) {
    return <LoginForm onSignIn={signIn} />;
  }

  const tabLabel = () => {
    switch (tab) {
      case 'add': return '📄 Add Paper';
      case 'manage': return '⚙️ Manage Site';
      case 'contributions': return '📥 Student Contributions';
      case 'blog': return '📝 Blog Posts';
    }
  };

  return (
    <div className="admin-shell">
      {/* Left Sidebar */}
      <aside className="admin-sidebar">
        <div className="sidebar-logo">
          🎓 <span>mdu</span>papers
        </div>

        <nav className="sidebar-nav">
          <button
            className={`sidebar-btn ${tab === 'add' ? 'active' : ''}`}
            onClick={() => setTab('add')}
          >
            <span className="icon">📄</span> Add Paper
          </button>
          <button
            className={`sidebar-btn ${tab === 'manage' ? 'active' : ''}`}
            onClick={() => setTab('manage')}
          >
            <span className="icon">⚙️</span> Manage
          </button>
          <button
            className={`sidebar-btn ${tab === 'contributions' ? 'active' : ''}`}
            onClick={() => setTab('contributions')}
            style={{ display: 'flex', alignItems: 'center', width: '100%' }}
          >
            <span className="icon">📥</span> Contributions
            {unverifiedPapers.length > 0 && (
              <span className="badge badge-warning" style={{ marginLeft: 'auto' }}>
                {unverifiedPapers.length}
              </span>
            )}
          </button>
          <button
            className={`sidebar-btn ${tab === 'blog' ? 'active' : ''}`}
            onClick={() => setTab('blog')}
          >
            <span className="icon">📝</span> Blog
          </button>
        </nav>

        <div className="sidebar-footer">
          <div className="user-profile">
            <span className="profile-role">Administrator</span>
            <span className="profile-email">{session.user.email}</span>
          </div>
          <button className="btn btn-secondary btn-block btn-sm" onClick={() => signOut()}>
            Sign out
          </button>
        </div>
      </aside>

      {/* Right Content Area */}
      <main className="main-content">
        <header className="top-bar">
          <h2>{tabLabel()}</h2>
          <div className="top-bar-actions">
            <PublishButton />
            <button className="btn btn-secondary btn-sm" onClick={() => signOut()}>
              Sign out
            </button>
          </div>
        </header>

        <div className="tab-content-wrapper">
          {tab === 'add' && <PapersTab />}
          {tab === 'manage' && <ManageTab />}
          {tab === 'contributions' && (
            <ContributionsTab
              unverifiedPapers={unverifiedPapers}
              loadUnverified={loadUnverified}
              onApprove={handleApprove}
              onRemove={handleReject}
            />
          )}
          {tab === 'blog' && <BlogTab />}
        </div>
      </main>
    </div>
  );
}
