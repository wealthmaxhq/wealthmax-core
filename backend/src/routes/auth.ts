import { Router } from 'express';
import bcrypt from 'bcrypt';
import {
  createUser,
  deleteUserAndOwnedData,
  findUserByEmail,
  findUserById,
  updateUserName,
  updateUserPasswordAndRevokeSessions,
} from '../lib/users';
import {
  signToken,
  authMiddleware,
  AuthenticatedRequest,
} from '../lib/jwt';
import {
  normalizedEmail,
  normalizedName,
  validPassword,
} from '../lib/authValidation';
import {
  loginAccountRateLimit,
  loginIpRateLimit,
  registrationRateLimit,
} from '../lib/authRateLimits';
import { accountDataExport, accountDataExportFilename } from '../lib/accountDataExport';

const router = Router();

router.post('/register', registrationRateLimit, async (req, res) => {
  let email: string;
  let password: string;
  let name: string | undefined;
  try {
    email = normalizedEmail(req.body?.email);
    password = validPassword(req.body?.password);
    name = normalizedName(req.body?.name);
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
  const existing = findUserByEmail(email);
  if (existing) return res.status(400).json({ error: 'User already exists' });
  const hash = await bcrypt.hash(password, 12);
  const user = createUser(email, hash, name);
  const token = signToken(user);
  return res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
});

router.post('/login', loginIpRateLimit, loginAccountRateLimit, async (req, res) => {
  let email: string;
  let password: string;
  try {
    email = normalizedEmail(req.body?.email);
    if (
      typeof req.body?.password !== 'string'
      || !req.body.password
      || req.body.password.length > 128
    ) throw new Error('Invalid password.');
    password = req.body.password;
  } catch {
    return res.status(400).json({ error: 'Invalid credentials' });
  }
  const user = findUserByEmail(email);
  if (!user) return res.status(400).json({ error: 'Invalid credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(400).json({ error: 'Invalid credentials' });
  const token = signToken(user);
  return res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
});

router.get('/me', authMiddleware, (req, res) => {
  return res.json({ user: (req as AuthenticatedRequest).user });
});

router.get('/me/export', authMiddleware, (req, res) => {
  const user = (req as AuthenticatedRequest).user!;
  const data = accountDataExport(user.id);
  if (!data) return res.status(404).json({ error: 'User not found' });
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${accountDataExportFilename}"`);
  return res.send(JSON.stringify(data, null, 2));
});

router.patch('/me', authMiddleware, (req, res) => {
  if (!Object.prototype.hasOwnProperty.call(req.body ?? {}, 'name')) {
    return res.status(400).json({ error: 'Name is required.' });
  }
  let name: string | undefined;
  try {
    name = normalizedName(req.body.name);
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
  const authenticatedUser = (req as AuthenticatedRequest).user!;
  const user = updateUserName(authenticatedUser.id, name);
  if (!user) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: { id: user.id, email: user.email, name: user.name } });
});

router.delete('/me', authMiddleware, async (req, res) => {
  const password = req.body?.password;
  if (req.body?.confirmation !== 'DELETE') {
    return res.status(400).json({ error: 'Type DELETE to confirm account deletion.' });
  }
  if (typeof password !== 'string' || !password || password.length > 128) {
    return res.status(400).json({ error: 'Current password is incorrect.' });
  }

  const authenticatedUser = (req as AuthenticatedRequest).user!;
  const user = findUserById(authenticatedUser.id);
  if (!user || !await bcrypt.compare(password, user.passwordHash)) {
    return res.status(400).json({ error: 'Current password is incorrect.' });
  }
  if (!deleteUserAndOwnedData(user.id)) {
    return res.status(404).json({ error: 'User not found' });
  }
  return res.status(204).send();
});

router.post('/change-password', authMiddleware, async (req, res) => {
  const currentPassword = req.body?.currentPassword;
  let newPassword: string;
  if (
    typeof currentPassword !== 'string'
    || !currentPassword
    || currentPassword.length > 128
  ) return res.status(400).json({ error: 'Current password is incorrect.' });
  try {
    newPassword = validPassword(req.body?.newPassword);
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
  if (currentPassword === newPassword) {
    return res.status(400).json({ error: 'New password must be different.' });
  }
  const authenticatedUser = (req as AuthenticatedRequest).user!;
  const user = findUserById(authenticatedUser.id);
  if (!user || !await bcrypt.compare(currentPassword, user.passwordHash)) {
    return res.status(400).json({ error: 'Current password is incorrect.' });
  }
  const hash = await bcrypt.hash(newPassword, 12);
  const updatedUser = updateUserPasswordAndRevokeSessions(user.id, hash);
  if (!updatedUser) {
    return res.status(404).json({ error: 'User not found' });
  }
  return res.json({
    token: signToken(updatedUser),
    user: { id: updatedUser.id, email: updatedUser.email, name: updatedUser.name },
  });
});

export default router;
