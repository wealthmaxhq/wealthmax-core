import db from '../db';
import { randomUUID } from 'node:crypto';

export interface Goal {
  id: string;
  userId: string;
  title: string;
  targetAmount: number;
  currentAmount: number;
  targetDate?: string; // ISO date
  notes?: string;
  createdAt: string;
  updatedAt?: string;
}

export function listGoalsByUser(userId: string): Goal[] {
  const rows = db.prepare('SELECT id, userId, title, targetAmount, currentAmount, targetDate, notes, createdAt, updatedAt FROM goals WHERE userId = ? ORDER BY createdAt DESC, id DESC').all(userId);
  return rows.map((r: any) => ({
    id: r.id,
    userId: r.userId,
    title: r.title,
    targetAmount: r.targetAmount,
    currentAmount: r.currentAmount,
    targetDate: r.targetDate,
    notes: r.notes,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  }));
}

export function getGoalById(id: string): Goal | undefined {
  const r = db.prepare('SELECT id, userId, title, targetAmount, currentAmount, targetDate, notes, createdAt, updatedAt FROM goals WHERE id = ?').get(id);
  if (!r) return undefined;
  return {
    id: r.id,
    userId: r.userId,
    title: r.title,
    targetAmount: r.targetAmount,
    currentAmount: r.currentAmount,
    targetDate: r.targetDate,
    notes: r.notes,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  } as Goal;
}

export function createGoal(userId: string, data: Partial<Goal>): Goal {
  const id = randomUUID();
  const now = new Date().toISOString();
  const stmt = db.prepare('INSERT INTO goals (id, userId, title, targetAmount, currentAmount, targetDate, notes, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
  stmt.run(id, userId, data.title || 'New Goal', data.targetAmount || 0, data.currentAmount || 0, data.targetDate || null, data.notes || null, now, now);
  return {
    id,
    userId,
    title: data.title || 'New Goal',
    targetAmount: data.targetAmount || 0,
    currentAmount: data.currentAmount || 0,
    targetDate: data.targetDate,
    notes: data.notes,
    createdAt: now,
    updatedAt: now,
  } as Goal;
}

export function updateGoal(id: string, userId: string, patch: Partial<Goal>): Goal | undefined {
  const existing = getGoalById(id);
  if (!existing || existing.userId !== userId) return undefined;
  const updated: Goal = {
    ...existing,
    title: patch.title ?? existing.title,
    targetAmount: patch.targetAmount ?? existing.targetAmount,
    currentAmount: patch.currentAmount ?? existing.currentAmount,
    targetDate: patch.targetDate ?? existing.targetDate,
    notes: patch.notes ?? existing.notes,
    updatedAt: new Date().toISOString(),
  };
  const stmt = db.prepare('UPDATE goals SET title = ?, targetAmount = ?, currentAmount = ?, targetDate = ?, notes = ?, updatedAt = ? WHERE id = ? AND userId = ?');
  stmt.run(updated.title, updated.targetAmount, updated.currentAmount, updated.targetDate || null, updated.notes || null, updated.updatedAt, id, userId);
  return updated;
}

export function deleteGoal(id: string, userId: string): boolean {
  const stmt = db.prepare('DELETE FROM goals WHERE id = ? AND userId = ?');
  const info = stmt.run(id, userId);
  return info.changes > 0;
}
