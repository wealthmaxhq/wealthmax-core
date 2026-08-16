import db from '../db';
import { randomUUID } from 'node:crypto';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  sessionVersion: number;
  name?: string;
  createdAt: string;
}

export function findUserByEmail(email: string): User | undefined {
  const row = db.prepare('SELECT id, email, passwordHash, sessionVersion, name, createdAt FROM users WHERE lower(email)=lower(?)').get(email);
  if (!row) return undefined;
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, sessionVersion: row.sessionVersion, name: row.name ?? undefined, createdAt: row.createdAt } as User;
}

export function findUserById(id: string): User | undefined {
  const row = db.prepare('SELECT id, email, passwordHash, sessionVersion, name, createdAt FROM users WHERE id = ?').get(id);
  if (!row) return undefined;
  return { id: row.id, email: row.email, passwordHash: row.passwordHash, sessionVersion: row.sessionVersion, name: row.name ?? undefined, createdAt: row.createdAt } as User;
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
    sessionVersion: 0,
    name: storedName,
    createdAt: now,
  } as User;
}

export function updateUserName(id: string, name?: string): User | undefined {
  const storedName = name?.trim() || null;
  const result = db.prepare('UPDATE users SET name = ? WHERE id = ?').run(storedName, id);
  return result.changes === 0 ? undefined : findUserById(id);
}

export function updateUserPasswordAndRevokeSessions(
  id: string,
  passwordHash: string,
): User | undefined {
  const result = db.prepare(`UPDATE users
    SET passwordHash = ?, sessionVersion = sessionVersion + 1
    WHERE id = ?`).run(passwordHash, id);
  return result.changes === 0 ? undefined : findUserById(id);
}

export function deleteUserAndOwnedData(id: string): boolean {
  return db.transaction(() => {
    const exists = db.prepare('SELECT 1 FROM users WHERE id = ?').get(id);
    if (!exists) return false;

    db.prepare('DELETE FROM decision_reports WHERE userId = ?').run(id);
    db.prepare('DELETE FROM goals WHERE userId = ?').run(id);
    return db.prepare('DELETE FROM users WHERE id = ?').run(id).changes === 1;
  })();
}
