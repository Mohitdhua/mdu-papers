import { useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import {
  adminConfigured,
  getSession,
  signIn,
  signOut,
  onAuthChange,
} from '../lib/admin';
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
      case 'papers': return '📄 Papers & Submissions';
      case 'subjects': return '📚 Syllabus Subjects';
      case 'courses': return '🎓 Courses & Degrees';
      case 'blog': return '📝 Blog Posts';
    }
  };

  return (
    <div className="admin-shell">
      {/* Left Sidebar */}
      <aside className="admin-sidebar">
        <div className="sidebar-logo">
          🎓 <span>mdu</span>pyq
        </div>

        <nav className="sidebar-nav">
          <button
            className={`sidebar-btn ${tab === 'papers' ? 'active' : ''}`}
            onClick={() => setTab('papers')}
          >
            <span className="icon">📄</span> Papers
          </button>
          <button
            className={`sidebar-btn ${tab === 'subjects' ? 'active' : ''}`}
            onClick={() => setTab('subjects')}
          >
            <span className="icon">📚</span> Subjects
          </button>
          <button
            className={`sidebar-btn ${tab === 'courses' ? 'active' : ''}`}
            onClick={() => setTab('courses')}
          >
            <span className="icon">🎓</span> Courses
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
          {tab === 'papers' && <PapersTab />}
          {tab === 'subjects' && <SubjectsTab />}
          {tab === 'courses' && <CoursesTab />}
          {tab === 'blog' && <BlogTab />}
        </div>
      </main>
    </div>
  );
}
