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
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, name: row.name ?? undefined, createdAt: row.createdAt } as User;
}

export function findUserById(id: string): User | undefined {
  const row = db.prepare('SELECT id, email, passwordHash, name, createdAt FROM users WHERE id = ?').get(id);
  if (!row) return undefined;
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, name: row.name ?? undefined, createdAt: row.createdAt } as User;
}

export function createUser(email: string, passwordHash: string, name?: string): User {
  const storedEmail = email.trim().toLowerCase();
  const storedName = name?.trim() || undefined;
  const id = randomUUID();
  const now = new Date().toISOString();
  const stmt = db.prepare('INSERT INTO users (id, email, passwordHash, name, createdAt) VALUES (?, ?, ?, ?, ?)');
  stmt.run(id, storedEmail, passwordHash, storedName, now);
  return {
    id,
    email: storedEmail,
    passwordHash,
    name: storedName,
    createdAt: now,
  } as User;
}

export function updateUserName(id: string, name?: string): User | undefined {
  const storedName = name?.trim() || null;
  const result = db.prepare('UPDATE users SET name = ? WHERE id = ?').run(storedName, id);
  return result.changes === 0 ? undefined : findUserById(id);
}

export function updateUserPassword(id: string, passwordHash: string): boolean {
  const result = db.prepare('UPDATE users SET passwordHash = ? WHERE id = ?').run(passwordHash, id);
  return result.changes > 0;
}
