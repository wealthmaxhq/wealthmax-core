import { Router } from 'express';
import bcrypt from 'bcrypt';
import { createUser, findUserByEmail } from '../lib/users';
import {
  signToken,
  authMiddleware,
  AuthenticatedRequest,
} from '../lib/jwt';

const router = Router();

router.post('/register', async (req, res) => {
  const { email, password, name } = req.body as any;
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  const existing = findUserByEmail(email);
  if (existing) return res.status(400).json({ error: 'User already exists' });
  const hash = await bcrypt.hash(password, 10);
  const user = createUser(email, hash, name);
  const token = signToken({ id: user.id });
  return res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body as any;
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
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
