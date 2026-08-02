import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { register } from '../api';
import { useAuth } from '../auth';

export default function Register() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const nav = useNavigate();
  const { establishSession } = useAuth();
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const res = await register({ email, password, name });
      establishSession(res.data.token, res.data.user);
      nav('/reports', { replace: true });
    } catch (err: unknown) {
      const response = err as { response?: { data?: { error?: string } } };
      setError(response.response?.data?.error || 'Registration failed');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="auth-page">
      <section className="panel auth-card">
        <p className="eyebrow">Start making clearer decisions</p>
        <h1>Create account</h1>
        <p className="muted">Your reports and goals stay private to your account.</p>
        {error && <div className="alert">{error}</div>}
        <form className="auth-form" onSubmit={submit}>
          <label>Name<input maxLength={100} autoComplete="name" value={name} onChange={e => setName(e.target.value)} /></label>
          <label>Email<input required maxLength={254} type="email" autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} /></label>
          <label>Password<input required minLength={8} maxLength={128} type="password" autoComplete="new-password" value={password} onChange={e => setPassword(e.target.value)} /></label>
          <button className="primary-button" type="submit" disabled={submitting}>{submitting ? 'Creating account…' : 'Create account'}</button>
        </form>
        <p className="auth-switch">Already have an account? <Link to="/login">Sign in</Link></p>
      </section>
    </main>
  );
}
