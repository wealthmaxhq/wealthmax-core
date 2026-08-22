import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import App from './App';

const auth = vi.hoisted(() => ({
  user: { id: 'user-1', email: 'owner@example.com', name: 'Rahul' } as { id: string; email: string; name?: string } | null,
  ready: true,
  logout: vi.fn(),
}));
vi.mock('./auth', () => ({ useAuth: () => auth }));
vi.mock('./pages/Dashboard', () => ({ default: () => <h1>Dashboard page</h1> }));
vi.mock('./pages/Goals', () => ({ default: () => <h1>Goals page</h1> }));
vi.mock('./pages/DecisionReports', () => ({ default: () => <h1>Reports page</h1> }));
vi.mock('./pages/FinancialHealth', () => ({ default: () => <h1>Health page</h1> }));
vi.mock('./pages/Portfolio', () => ({ default: () => <h1>Portfolio page</h1> }));
vi.mock('./pages/Account', () => ({ default: () => <h1>Account page</h1> }));
vi.mock('./pages/Login', () => ({ default: () => <h1>Login page</h1> }));
vi.mock('./pages/Register', () => ({ default: () => <h1>Register page</h1> }));

function renderApp(path = '/') {
  return render(<MemoryRouter initialEntries={[path]}><App /></MemoryRouter>);
}

describe('Responsive application navigation', () => {
  beforeEach(() => {
    auth.user = { id: 'user-1', email: 'owner@example.com', name: 'Rahul' };
    auth.ready = true;
    auth.logout.mockReset();
  });

  test('opens the complete authenticated menu and closes it after navigation', async () => {
    const user = userEvent.setup();
    renderApp();
    const toggle = screen.getByRole('button', { name: 'Open navigation' });

    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await user.click(toggle);

    expect(screen.getByRole('button', { name: 'Close navigation' })).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('link', { name: 'Decision reports' })).toHaveAttribute('href', '/reports');
    expect(screen.getByRole('link', { name: 'Financial health' })).toHaveAttribute('href', '/financial-health');
    expect(screen.getByRole('link', { name: 'Portfolio' })).toHaveAttribute('href', '/portfolio');
    expect(screen.getByRole('link', { name: 'Rahul' })).toHaveAttribute('href', '/account');

    await user.click(screen.getByRole('link', { name: 'Goals' }));
    expect(await screen.findByRole('heading', { name: 'Goals page' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Open navigation' })).toHaveAttribute('aria-expanded', 'false');
  });

  test('shows public actions and closes the menu when logging out', async () => {
    const user = userEvent.setup();
    auth.user = null;
    const { rerender } = renderApp();
    await user.click(screen.getByRole('button', { name: 'Open navigation' }));
    expect(screen.getByRole('link', { name: 'Login' })).toHaveAttribute('href', '/login');
    expect(screen.getByRole('link', { name: 'Get started' })).toHaveAttribute('href', '/register');

    auth.user = { id: 'user-1', email: 'owner@example.com', name: 'Rahul' };
    rerender(<MemoryRouter><App /></MemoryRouter>);
    await user.click(screen.getByRole('button', { name: 'Close navigation' }));
    await user.click(screen.getByRole('button', { name: 'Log out' }));
    expect(auth.logout).toHaveBeenCalledOnce();
    expect(screen.getByRole('button', { name: 'Open navigation' })).toHaveAttribute('aria-expanded', 'false');
  });
});
