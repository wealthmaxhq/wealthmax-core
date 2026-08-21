import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import Login from './Login';
import Register from './Register';

const api = vi.hoisted(() => ({ login: vi.fn(), register: vi.fn() }));
const establishSession = vi.hoisted(() => vi.fn());
vi.mock('../api', () => api);
vi.mock('../auth', () => ({ useAuth: () => ({ establishSession }) }));

function renderLogin(from?: string) {
  return render(
    <MemoryRouter initialEntries={[{ pathname: '/login', state: from ? { from } : null }]}>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/portfolio" element={<p>Portfolio destination</p>} />
        <Route path="/reports" element={<p>Reports destination</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

function renderRegister() {
  return render(
    <MemoryRouter initialEntries={['/register']}>
      <Routes>
        <Route path="/register" element={<Register />} />
        <Route path="/reports" element={<p>Reports destination</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('Authentication forms', () => {
  beforeEach(() => {
    api.login.mockReset();
    api.register.mockReset();
    establishSession.mockReset();
  });

  test('normalizes login identity, establishes the session, and returns to the protected route', async () => {
    const user = userEvent.setup();
    const authenticatedUser = { id: 'user-1', email: 'owner@example.com', name: 'Rahul' };
    api.login.mockResolvedValue({ data: { token: 'login-token', user: authenticatedUser } });
    renderLogin('/portfolio');

    await user.type(screen.getByLabelText('Email'), '  Owner@Example.com  ');
    await user.type(screen.getByLabelText('Password'), 'secure-password');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => expect(api.login).toHaveBeenCalledWith({
      email: 'Owner@Example.com', password: 'secure-password',
    }));
    expect(establishSession).toHaveBeenCalledWith('login-token', authenticatedUser);
    expect(await screen.findByText('Portfolio destination')).toBeInTheDocument();
  });

  test('shows a login API error, preserves input, and re-enables submission', async () => {
    const user = userEvent.setup();
    api.login.mockRejectedValue({ response: { data: { error: 'Invalid credentials' } } });
    renderLogin();

    await user.type(screen.getByLabelText('Email'), 'owner@example.com');
    await user.type(screen.getByLabelText('Password'), 'wrong-password');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));

    expect(await screen.findByText('Invalid credentials')).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toHaveValue('owner@example.com');
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeEnabled();
    expect(establishSession).not.toHaveBeenCalled();
  });

  test('normalizes registration details, prevents duplicate submission, and opens reports', async () => {
    const user = userEvent.setup();
    const authenticatedUser = { id: 'user-2', email: 'new@example.com', name: 'New User' };
    let complete!: (value: unknown) => void;
    api.register.mockReturnValue(new Promise((resolve) => { complete = resolve; }));
    renderRegister();

    await user.type(screen.getByLabelText('Name'), '  New User  ');
    await user.type(screen.getByLabelText('Email'), '  new@example.com  ');
    await user.type(screen.getByLabelText('Password'), 'secure-password');
    await user.click(screen.getByRole('button', { name: 'Create account' }));

    expect(api.register).toHaveBeenCalledWith({
      name: 'New User', email: 'new@example.com', password: 'secure-password',
    });
    expect(screen.getByRole('button', { name: 'Creating account…' })).toBeDisabled();
    complete({ data: { token: 'registration-token', user: authenticatedUser } });
    expect(await screen.findByText('Reports destination')).toBeInTheDocument();
    expect(establishSession).toHaveBeenCalledWith('registration-token', authenticatedUser);
  });

  test('omits a blank optional name and recovers from registration errors', async () => {
    const user = userEvent.setup();
    api.register.mockRejectedValue({ response: { data: { error: 'An account already exists.' } } });
    renderRegister();

    await user.type(screen.getByLabelText('Name'), '   ');
    await user.type(screen.getByLabelText('Email'), 'existing@example.com');
    await user.type(screen.getByLabelText('Password'), 'secure-password');
    await user.click(screen.getByRole('button', { name: 'Create account' }));

    expect(await screen.findByText('An account already exists.')).toBeInTheDocument();
    expect(api.register).toHaveBeenCalledWith({
      email: 'existing@example.com', password: 'secure-password',
    });
    expect(screen.getByRole('button', { name: 'Create account' })).toBeEnabled();
    expect(establishSession).not.toHaveBeenCalled();
  });
});
