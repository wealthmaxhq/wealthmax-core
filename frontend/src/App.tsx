import React, { ReactNode } from 'react';
import { Routes, Route, Link, Navigate, useLocation } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import Goals from './pages/Goals';
import DecisionReports from './pages/DecisionReports';
import Dashboard from './pages/Dashboard';
import Account from './pages/Account';
import { useAuth } from './auth';

function RequireAuth({ children }: { children: ReactNode }) {
  const { user, ready } = useAuth();
  const location = useLocation();
  if (!ready) return <main><p className="muted">Restoring your account…</p></main>;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return children;
}

const restoringSession = (
  <main><p className="muted">Restoring your account…</p></main>
);

const landingPage = (
  <main className="home-hero">
    <p className="eyebrow">Clear decisions. Exact mathematics.</p>
    <h1>Make your extra money work harder.</h1>
    <p>Compare loan prepayment and investing on the same timeline, after fees, tax, and inflation.</p>
    <Link className="primary-button inline-button" to="/reports">Build a decision report</Link>
  </main>
);

export default function App() {
  const { user, ready, logout } = useAuth();
  return (
    <div className="app-shell">
      <nav className="top-nav">
        <Link className="brand" to="/">
          <span className="brand-mark">W</span>
          <span>WealthMax</span>
        </Link>
        <div className="nav-links">
          <Link to="/reports">Decision reports</Link>
          <Link to="/goals">Goals</Link>
          {!ready ? null : user ? (
            <>
              <Link className="account-name" to="/account">{user.name || user.email}</Link>
              <button className="nav-logout" type="button" onClick={logout}>Log out</button>
            </>
          ) : (
            <>
              <Link to="/login">Login</Link>
              <Link className="nav-cta" to="/register">Get started</Link>
            </>
          )}
        </div>
      </nav>
      <Routes>
        <Route
          path="/"
          element={!ready ? restoringSession : user ? <Dashboard /> : landingPage}
        />
        <Route path="/login" element={!ready ? restoringSession : user ? <Navigate to="/reports" replace /> : <Login />} />
        <Route path="/register" element={!ready ? restoringSession : user ? <Navigate to="/reports" replace /> : <Register />} />
        <Route path="/goals" element={<RequireAuth><Goals /></RequireAuth>} />
        <Route path="/account" element={<RequireAuth><Account /></RequireAuth>} />
        <Route path="/reports" element={<RequireAuth><DecisionReports /></RequireAuth>} />
        <Route path="/reports/:reportId" element={<RequireAuth><DecisionReports /></RequireAuth>} />
      </Routes>
    </div>
  );
}
