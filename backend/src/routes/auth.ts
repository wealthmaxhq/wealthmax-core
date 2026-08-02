import { Router } from 'express';
import bcrypt from 'bcrypt';
import { createUser, findUserByEmail } from '../lib/users';
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

const router = Router();

router.post('/register', async (req, res) => {
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
  const token = signToken({ id: user.id });
  return res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
});

router.post('/login', async (req, res) => {
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
  const token = signToken({ id: user.id });
  return res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
});

router.get('/me', authMiddleware, (req, res) => {
  return res.json({ user: (req as AuthenticatedRequest).user });
});

export default router;
