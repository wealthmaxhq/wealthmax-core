import { FormEvent, useState } from 'react';
import axios from 'axios';
import { changePassword, deleteCurrentUser, exportCurrentUserData, updateCurrentUser } from '../api';
import { useAuth } from '../auth';

function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error) && typeof error.response?.data?.error === 'string') {
    return error.response.data.error;
  }
  return 'Something went wrong. Please try again.';
}

export default function Account() {
  const { user, establishSession, updateUser, logout } = useAuth();
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
  const [deletionPassword, setDeletionPassword] = useState('');
  const [deletionConfirmation, setDeletionConfirmation] = useState('');
  const [deletionError, setDeletionError] = useState('');
  const [deleting, setDeleting] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState('');

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
      const response = await changePassword({ currentPassword, newPassword });
      establishSession(response.data.token, response.data.user);
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

  async function deleteAccount(event: FormEvent) {
    event.preventDefault();
    setDeletionError('');
    setDeleting(true);
    try {
      await deleteCurrentUser(deletionPassword, deletionConfirmation);
      logout();
    } catch (error) {
      setDeletionError(errorMessage(error));
      setDeleting(false);
    }
  }

  async function downloadData() {
    setExportError('');
    setExporting(true);
    try {
      const response = await exportCurrentUserData();
      const disposition = response.headers['content-disposition'] as string | undefined;
      const filename = disposition?.match(/filename="([^"]+)"/)?.[1]
        ?? 'wealthmax-account-data.json';
      const url = URL.createObjectURL(response.data);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = filename;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      setExportError(errorMessage(error));
    } finally {
      setExporting(false);
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
          <p className="muted">Use at least 8 characters. Changing your password signs out every other session.</p>
          {passwordError && <div className="alert">{passwordError}</div>}
          {passwordStatus && <div className="success-alert">{passwordStatus}</div>}
          <form className="auth-form" onSubmit={savePassword}>
            <label>Current password<input autoComplete="current-password" maxLength={128} required type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} /></label>
            <label>New password<input autoComplete="new-password" minLength={8} maxLength={128} required type="password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} /></label>
            <label>Confirm new password<input autoComplete="new-password" minLength={8} maxLength={128} required type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} /></label>
            <button className="primary-button" disabled={savingPassword} type="submit">{savingPassword ? 'Changing…' : 'Change password'}</button>
          </form>
        </section>
        <section className="panel account-card data-zone">
          <h2>Your data</h2>
          <p className="muted">Download a private JSON copy of your profile and all WealthMax planning records.</p>
          {exportError && <div className="alert" role="alert">{exportError}</div>}
          <button className="primary-button" disabled={exporting} type="button" onClick={() => void downloadData()}>{exporting ? 'Preparing export…' : 'Download my data'}</button>
        </section>
        <section className="panel account-card danger-zone">
          <h2>Delete account</h2>
          <p className="muted">Permanently delete your account and all WealthMax planning data. This cannot be undone.</p>
          {deletionError && <div className="alert" role="alert">{deletionError}</div>}
          <form className="auth-form" onSubmit={deleteAccount}>
            <label>Current password<input autoComplete="current-password" maxLength={128} required type="password" value={deletionPassword} onChange={(event) => setDeletionPassword(event.target.value)} /></label>
            <label>Type DELETE to confirm<input autoComplete="off" required value={deletionConfirmation} onChange={(event) => setDeletionConfirmation(event.target.value)} /></label>
            <button className="destructive-button" disabled={deleting || deletionConfirmation !== 'DELETE'} type="submit">{deleting ? 'Deleting…' : 'Permanently delete account'}</button>
          </form>
        </section>
      </div>
    </main>
  );
}
