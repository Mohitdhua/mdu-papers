import { useState } from 'react';

interface Props {
  onSignIn: (email: string, password: string) => Promise<{ error: { message: string } | null }>;
}

export default function LoginForm({ onSignIn }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e: any) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    const { error } = await onSignIn(email, password);
    setBusy(false);
    if (error) setError(error.message);
  };

  return (
    <div className="admin-login">
      <div className="card">
        <h2 style={{ marginBottom: '0.5rem', fontWeight: 800 }}>🎓 mduypq admin</h2>
        <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: '1.5rem' }}>
          Sign in with your administrator credentials to manage papers, subjects, courses, and blogs.
        </p>
        {error && <div className="admin-alert error">{error}</div>}
        <form onSubmit={submit}>
          <div className="form-group">
            <label htmlFor="admin-email">Email Address</label>
            <input
              id="admin-email"
              type="email"
              className="form-control"
              value={email}
              onInput={(e) => setEmail((e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <div className="form-group">
            <label htmlFor="admin-password">Password</label>
            <input
              id="admin-password"
              type="password"
              className="form-control"
              value={password}
              onInput={(e) => setPassword((e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <button type="submit" className="btn btn-primary btn-block" style={{ padding: '0.65rem' }} disabled={busy}>
            {busy ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
