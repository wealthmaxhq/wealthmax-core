import db from '../db';
import { randomUUID } from 'node:crypto';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  name?: string;
  createdAt: string;
}

export function findUserByEmail(email: string): User | undefined {
  const row = db.prepare('SELECT id, email, passwordHash, name, createdAt FROM users WHERE lower(email)=lower(?)').get(email);
  if (!row) return undefined;
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, name: row.name, createdAt: row.createdAt } as User;
}

export function findUserById(id: string): User | undefined {
  const row = db.prepare('SELECT id, email, passwordHash, name, createdAt FROM users WHERE id = ?').get(id);
  if (!row) return undefined;
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, name: row.name, createdAt: row.createdAt } as User;
}

export function createUser(email: string, passwordHash: string, name?: string): User {
  const id = randomUUID();
  const now = new Date().toISOString();
  const stmt = db.prepare('INSERT INTO users (id, email, passwordHash, name, createdAt) VALUES (?, ?, ?, ?, ?)');
  stmt.run(id, email, passwordHash, name, now);
  return { id, email, passwordHash, name, createdAt: now } as User;
}
