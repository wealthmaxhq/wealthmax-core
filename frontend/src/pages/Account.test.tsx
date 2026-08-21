import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import Account from './Account';

const api = vi.hoisted(() => ({
  changePassword: vi.fn(),
  deleteCurrentUser: vi.fn(),
  updateCurrentUser: vi.fn(),
}));
const auth = vi.hoisted(() => ({
  establishSession: vi.fn(), logout: vi.fn(), updateUser: vi.fn(),
}));
vi.mock('../api', () => api);
vi.mock('../auth', () => ({
  useAuth: () => ({
    user: { id: 'user-1', email: 'owner@example.com', name: 'Rahul' },
    ...auth,
  }),
}));
vi.mock('axios', () => ({
  default: { isAxiosError: (error: { response?: unknown }) => Boolean(error?.response) },
}));

describe('Account', () => {
  afterEach(() => vi.restoreAllMocks());

  beforeEach(() => {
    Object.values(api).forEach((mock) => mock.mockReset());
    Object.values(auth).forEach((mock) => mock.mockReset());
  });

  test('normalizes a profile update and refreshes the authenticated identity', async () => {
    const user = userEvent.setup();
    const updatedUser = { id: 'user-1', email: 'owner@example.com', name: 'Rahul Baghel' };
    api.updateCurrentUser.mockResolvedValue({ data: { user: updatedUser } });
    render(<Account />);

    expect(screen.getByLabelText('Email')).toBeDisabled();
    const name = screen.getByLabelText('Display name');
    await user.clear(name); await user.type(name, '  Rahul Baghel  ');
    await user.click(screen.getByRole('button', { name: 'Save profile' }));

    await waitFor(() => expect(api.updateCurrentUser).toHaveBeenCalledWith('Rahul Baghel'));
    expect(auth.updateUser).toHaveBeenCalledWith(updatedUser);
    expect(await screen.findByText('Profile updated.')).toBeInTheDocument();
    expect(name).toHaveValue('Rahul Baghel');
  });

  test('rejects mismatched new passwords without contacting the API', async () => {
    const user = userEvent.setup();
    render(<Account />);

    await user.type(screen.getAllByLabelText('Current password')[0], 'current-password');
    await user.type(screen.getByLabelText('New password'), 'replacement-password');
    await user.type(screen.getByLabelText('Confirm new password'), 'different-password');
    await user.click(screen.getByRole('button', { name: 'Change password' }));

    expect(await screen.findByText('New passwords do not match.')).toBeInTheDocument();
    expect(api.changePassword).not.toHaveBeenCalled();
  });

  test('replaces the current session after a successful password change', async () => {
    const user = userEvent.setup();
    const updatedUser = { id: 'user-1', email: 'owner@example.com', name: 'Rahul' };
    api.changePassword.mockResolvedValue({ data: { token: 'replacement-token', user: updatedUser } });
    render(<Account />);

    const currentPassword = screen.getAllByLabelText('Current password')[0];
    const newPassword = screen.getByLabelText('New password');
    const confirmation = screen.getByLabelText('Confirm new password');
    await user.type(currentPassword, 'current-password');
    await user.type(newPassword, 'replacement-password');
    await user.type(confirmation, 'replacement-password');
    await user.click(screen.getByRole('button', { name: 'Change password' }));

    await waitFor(() => expect(api.changePassword).toHaveBeenCalledWith({
      currentPassword: 'current-password', newPassword: 'replacement-password',
    }));
    expect(auth.establishSession).toHaveBeenCalledWith('replacement-token', updatedUser);
    expect(await screen.findByText('Password changed successfully.')).toBeInTheDocument();
    expect(currentPassword).toHaveValue('');
    expect(newPassword).toHaveValue('');
    expect(confirmation).toHaveValue('');
  });

  test('gates deletion, recovers from an API error, and logs out after success', async () => {
    const user = userEvent.setup();
    api.deleteCurrentUser
      .mockRejectedValueOnce({ response: { data: { error: 'Current password is incorrect.' } } })
      .mockResolvedValueOnce({});
    render(<Account />);

    const deletionPassword = screen.getAllByLabelText('Current password')[1];
    const deletionConfirmation = screen.getByLabelText('Type DELETE to confirm');
    const deleteButton = screen.getByRole('button', { name: 'Permanently delete account' });
    expect(deleteButton).toBeDisabled();
    await user.type(deletionPassword, 'delete-password');
    await user.type(deletionConfirmation, 'delete');
    expect(deleteButton).toBeDisabled();
    await user.clear(deletionConfirmation); await user.type(deletionConfirmation, 'DELETE');
    expect(deleteButton).toBeEnabled();

    await user.click(deleteButton);
    expect(await screen.findByRole('alert')).toHaveTextContent('Current password is incorrect.');
    expect(deleteButton).toBeEnabled();
    expect(auth.logout).not.toHaveBeenCalled();

    await user.click(deleteButton);
    await waitFor(() => expect(api.deleteCurrentUser).toHaveBeenLastCalledWith('delete-password', 'DELETE'));
    expect(auth.logout).toHaveBeenCalledOnce();
  });
});
