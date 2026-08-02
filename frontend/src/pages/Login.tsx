import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { login } from '../api';
import { useAuth } from '../auth';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const nav = useNavigate();
  const location = useLocation();
  const { establishSession } = useAuth();
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const res = await login({ email, password });
      establishSession(res.data.token, res.data.user);
      const destination = (location.state as { from?: string } | null)?.from;
      nav(destination || '/reports', { replace: true });
    } catch (err: unknown) {
      const response = err as { response?: { data?: { error?: string } } };
      setError(response.response?.data?.error || 'Login failed');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="auth-page">
      <section className="panel auth-card">
        <p className="eyebrow">Welcome back</p>
        <h1>Sign in</h1>
        <p className="muted">Continue to your private WealthMax workspace.</p>
        {error && <div className="alert">{error}</div>}
        <form className="auth-form" onSubmit={submit}>
          <label>Email<input required maxLength={254} type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} /></label>
          <label>Password<input required maxLength={128} type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} /></label>
          <button className="primary-button" type="submit" disabled={submitting}>{submitting ? 'Signing in…' : 'Sign in'}</button>
        </form>
        <p className="auth-switch">New to WealthMax? <Link to="/register">Create an account</Link></p>
      </section>
    </main>
  );
}
