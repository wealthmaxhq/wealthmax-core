import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { findUserById } from './users';

const minimumSecretLength = 32;

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    name?: string;
  };
}

function jwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < minimumSecretLength) {
    throw new Error(
      `JWT_SECRET must be configured with at least ${minimumSecretLength} characters.`,
    );
  }
  return secret;
}

export function signToken(payload: object): string {
  return jwt.sign(payload, jwtSecret(), {
    expiresIn: '1h',
    issuer: 'wealthmax-core',
    audience: 'wealthmax-web',
  });
}

export function verifyToken(token: string): jwt.JwtPayload {
  const payload = jwt.verify(token, jwtSecret(), {
    issuer: 'wealthmax-core',
    audience: 'wealthmax-web',
  });
  if (typeof payload === 'string') {
    throw new Error('Token payload must be an object.');
  }
  return payload;
}

export function authMiddleware(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
) {
  const header = req.headers.authorization;
  if (!header) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }
  const parts = header.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Invalid Authorization header' });
  }
  try {
    const payload = verifyToken(parts[1]);
    if (typeof payload.id !== 'string' || payload.id.length === 0) {
      return res.status(401).json({ error: 'Invalid token payload' });
    }
    const user = findUserById(payload.id);
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }
    req.user = { id: user.id, email: user.email, name: user.name };
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
