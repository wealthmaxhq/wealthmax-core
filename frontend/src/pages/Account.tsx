import { FormEvent, useState } from 'react';
import axios from 'axios';
import { changePassword, updateCurrentUser } from '../api';
import { useAuth } from '../auth';

function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error) && typeof error.response?.data?.error === 'string') {
    return error.response.data.error;
  }
  return 'Something went wrong. Please try again.';
}

export default function Account() {
  const { user, updateUser } = useAuth();
  const [name, setName] = useState(user?.name ?? '');
  const [profileStatus, setProfileStatus] = useState('');
  const [profileError, setProfileError] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordStatus, setPasswordStatus] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [savingPassword, setSavingPassword] = useState(false);

  async function saveProfile(event: FormEvent) {
    event.preventDefault();
    setProfileError('');
    setProfileStatus('');
    setSavingProfile(true);
    try {
      const response = await updateCurrentUser(name.trim() || null);
      updateUser(response.data.user);
      setName(response.data.user.name ?? '');
      setProfileStatus('Profile updated.');
    } catch (error) {
      setProfileError(errorMessage(error));
    } finally {
      setSavingProfile(false);
    }
  }

  async function savePassword(event: FormEvent) {
    event.preventDefault();
    setPasswordError('');
    setPasswordStatus('');
    if (newPassword !== confirmPassword) {
      setPasswordError('New passwords do not match.');
      return;
    }
    setSavingPassword(true);
    try {
      await changePassword({ currentPassword, newPassword });
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setPasswordStatus('Password changed successfully.');
    } catch (error) {
      setPasswordError(errorMessage(error));
    } finally {
      setSavingPassword(false);
    }
  }

  return (
    <main>
      <header className="page-header">
        <div><p className="eyebrow">Your account</p><h1>Account settings</h1></div>
      </header>
      <div className="account-grid">
        <section className="panel account-card">
          <h2>Profile</h2>
          <p className="muted">Choose the name shown throughout WealthMax.</p>
          {profileError && <div className="alert">{profileError}</div>}
          {profileStatus && <div className="success-alert">{profileStatus}</div>}
          <form className="auth-form" onSubmit={saveProfile}>
            <label>Display name<input maxLength={100} value={name} onChange={(event) => setName(event.target.value)} /></label>
            <label>Email<input disabled value={user?.email ?? ''} /></label>
            <button className="primary-button" disabled={savingProfile} type="submit">{savingProfile ? 'Saving…' : 'Save profile'}</button>
          </form>
        </section>
        <section className="panel account-card">
          <h2>Change password</h2>
          <p className="muted">Use at least 8 characters. Your existing sessions expire automatically within one hour.</p>
          {passwordError && <div className="alert">{passwordError}</div>}
          {passwordStatus && <div className="success-alert">{passwordStatus}</div>}
          <form className="auth-form" onSubmit={savePassword}>
            <label>Current password<input autoComplete="current-password" maxLength={128} required type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} /></label>
            <label>New password<input autoComplete="new-password" minLength={8} maxLength={128} required type="password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} /></label>
            <label>Confirm new password<input autoComplete="new-password" minLength={8} maxLength={128} required type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} /></label>
            <button className="primary-button" disabled={savingPassword} type="submit">{savingPassword ? 'Changing…' : 'Change password'}</button>
          </form>
        </section>
      </div>
    </main>
  );
}
