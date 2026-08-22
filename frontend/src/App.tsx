import React, { ReactNode, useState } from 'react';
import { Routes, Route, Link, Navigate, useLocation } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import Goals from './pages/Goals';
import DecisionReports from './pages/DecisionReports';
import Dashboard from './pages/Dashboard';
import Account from './pages/Account';
import FinancialHealth from './pages/FinancialHealth';
import Portfolio from './pages/Portfolio';
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
  const [navigationOpen, setNavigationOpen] = useState(false);
  const closeNavigation = () => setNavigationOpen(false);
  const logOut = () => { closeNavigation(); logout(); };
  return (
    <div className="app-shell">
      <nav className="top-nav">
        <Link className="brand" to="/" onClick={closeNavigation}>
          <span className="brand-mark">W</span>
          <span>WealthMax</span>
        </Link>
        <button
          aria-controls="primary-navigation"
          aria-expanded={navigationOpen}
          aria-label={navigationOpen ? 'Close navigation' : 'Open navigation'}
          className="nav-toggle"
          onClick={() => setNavigationOpen((open) => !open)}
          type="button"
        ><span aria-hidden="true">{navigationOpen ? '×' : '☰'}</span></button>
        <div className={`nav-links${navigationOpen ? ' open' : ''}`} id="primary-navigation">
          <Link to="/reports" onClick={closeNavigation}>Decision reports</Link>
          <Link to="/goals" onClick={closeNavigation}>Goals</Link>
          <Link to="/financial-health" onClick={closeNavigation}>Financial health</Link>
          <Link to="/portfolio" onClick={closeNavigation}>Portfolio</Link>
          {!ready ? null : user ? (
            <>
              <Link className="account-name" to="/account" onClick={closeNavigation}>{user.name || user.email}</Link>
              <button className="nav-logout" type="button" onClick={logOut}>Log out</button>
            </>
          ) : (
            <>
              <Link to="/login" onClick={closeNavigation}>Login</Link>
              <Link className="nav-cta" to="/register" onClick={closeNavigation}>Get started</Link>
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
        <Route path="/financial-health" element={<RequireAuth><FinancialHealth /></RequireAuth>} />
        <Route path="/portfolio" element={<RequireAuth><Portfolio /></RequireAuth>} />
        <Route path="/reports" element={<RequireAuth><DecisionReports /></RequireAuth>} />
        <Route path="/reports/:reportId" element={<RequireAuth><DecisionReports /></RequireAuth>} />
      </Routes>
    </div>
  );
}
