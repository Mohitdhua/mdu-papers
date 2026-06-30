import { useState } from 'preact/hooks';

interface Props {
  onSignIn: (email: string, password: string) => Promise<{ error: { message: string } | null }>;
}

export default function LoginForm({ onSignIn }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e: Event) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    const { error } = await onSignIn(email, password);
    setBusy(false);
    if (error) setError(error.message);
  };

  return (
    <div class="admin-login">
      <div class="card">
        <h2 style="margin-bottom: 0.5rem;">🔒 Admin Login</h2>
        <p class="text-muted" style="font-size: 0.875rem; margin-bottom: 1.5rem;">
          Sign in with your Supabase admin account to manage papers.
        </p>
        {error && <div class="admin-alert error">{error}</div>}
        <form onSubmit={submit}>
          <div class="form-group">
            <label for="admin-email">Email</label>
            <input
              id="admin-email"
              type="email"
              class="form-control"
              value={email}
              onInput={(e) => setEmail((e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <div class="form-group">
            <label for="admin-password">Password</label>
            <input
              id="admin-password"
              type="password"
              class="form-control"
              value={password}
              onInput={(e) => setPassword((e.target as HTMLInputElement).value)}
              required
            />
          </div>
          <button type="submit" class="btn btn-primary btn-block" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
