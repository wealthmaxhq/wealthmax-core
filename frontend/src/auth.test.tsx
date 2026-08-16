import { render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import { AuthProvider, useAuth } from './auth';

const getCurrentUser = vi.hoisted(() => vi.fn());
const setAuthToken = vi.hoisted(() => vi.fn());
vi.mock('./api', () => ({
  AUTH_EXPIRED_EVENT: 'wealthmax:auth-expired',
  getCurrentUser,
  setAuthToken,
}));

function SessionState() {
  const { ready, user } = useAuth();
  return <div>{ready ? user?.email || 'signed out' : 'restoring'}</div>;
}

describe('AuthProvider', () => {
  beforeEach(() => {
    getCurrentUser.mockReset();
    setAuthToken.mockReset();
  });

  test('restores a saved session and clears it when the API expires authentication', async () => {
    localStorage.setItem('token', 'saved-token');
    getCurrentUser.mockResolvedValue({ data: { user: { id: 'user-1', email: 'owner@example.com' } } });
    render(<AuthProvider><SessionState /></AuthProvider>);

    expect(await screen.findByText('owner@example.com')).toBeInTheDocument();
    window.dispatchEvent(new Event('wealthmax:auth-expired'));
    await waitFor(() => expect(screen.getByText('signed out')).toBeInTheDocument());
    expect(localStorage.getItem('token')).toBeNull();
    expect(setAuthToken).toHaveBeenCalledWith(null);
  });

  test('becomes ready without calling the API when no token exists', async () => {
    render(<AuthProvider><SessionState /></AuthProvider>);
    expect(await screen.findByText('signed out')).toBeInTheDocument();
    expect(getCurrentUser).not.toHaveBeenCalled();
  });
});
