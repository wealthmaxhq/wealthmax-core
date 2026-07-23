import React from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import Goals from './pages/Goals';

export default function App() {
  return (
    <div style={{ padding: 20 }}>
      <nav style={{ marginBottom: 20 }}>
        <Link to="/">Home</Link> | <Link to="/login">Login</Link> | <Link to="/register">Register</Link> | <Link to="/goals">Goals</Link>
      </nav>
      <Routes>
        <Route path="/" element={<div>Welcome to Wealth Planner</div>} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/goals" element={<Goals />} />
      </Routes>
    </div>
  );
}
