import React from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import Goals from './pages/Goals';
import DecisionReports from './pages/DecisionReports';

export default function App() {
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
          <Link to="/login">Login</Link>
          <Link className="nav-cta" to="/register">Get started</Link>
        </div>
      </nav>
      <Routes>
        <Route
          path="/"
          element={
            <main className="home-hero">
              <p className="eyebrow">Clear decisions. Exact mathematics.</p>
              <h1>Make your extra money work harder.</h1>
              <p>
                Compare loan prepayment and investing on the same timeline,
                after fees, tax, and inflation.
              </p>
              <Link className="primary-button inline-button" to="/reports">
                Build a decision report
              </Link>
            </main>
          }
        />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/goals" element={<Goals />} />
        <Route path="/reports" element={<DecisionReports />} />
      </Routes>
    </div>
  );
}
