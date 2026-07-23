import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { findUserById } from './users';

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

export function signToken(payload: object) {
  return jwt.sign(payload, SECRET, { expiresIn: '7d' });
}

export function verifyToken(token: string) {
  return jwt.verify(token, SECRET);
}

export function authMiddleware(req: Request & { user?: any }, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'Missing Authorization header' });
  const parts = header.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') return res.status(401).json({ error: 'Invalid Authorization header' });
  try {
    const payload: any = verifyToken(parts[1]);
    const user = findUserById(payload.id);
    if (!user) return res.status(401).json({ error: 'User not found' });
    req.user = { id: user.id, email: user.email, name: user.name };
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
