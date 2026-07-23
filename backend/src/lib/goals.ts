import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

const DATA_FILE = path.join(__dirname, '..', '..', 'data', 'goals.json');

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

function readGoals(): Goal[] {
  try {
    const raw = fs.readFileSync(DATA_FILE, 'utf-8');
    return JSON.parse(raw) as Goal[];
  } catch (e) {
    return [];
  }
}

function writeGoals(goals: Goal[]) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(goals, null, 2));
}

export function listGoalsByUser(userId: string): Goal[] {
  const goals = readGoals();
  return goals.filter(g => g.userId === userId);
}

export function getGoalById(id: string): Goal | undefined {
  const goals = readGoals();
  return goals.find(g => g.id === id);
}

export function createGoal(userId: string, data: Partial<Goal>): Goal {
  const goals = readGoals();
  const now = new Date().toISOString();
  const goal: Goal = {
    id: uuidv4(),
    userId,
    title: data.title || 'New Goal',
    targetAmount: data.targetAmount || 0,
    currentAmount: data.currentAmount || 0,
    targetDate: data.targetDate,
    notes: data.notes,
    createdAt: now,
    updatedAt: now,
  };
  goals.push(goal);
  writeGoals(goals);
  return goal;
}

export function updateGoal(id: string, userId: string, patch: Partial<Goal>): Goal | undefined {
  const goals = readGoals();
  const idx = goals.findIndex(g => g.id === id && g.userId === userId);
  if (idx === -1) return undefined;
  const now = new Date().toISOString();
  const updated = { ...goals[idx], ...patch, updatedAt: now };
  goals[idx] = updated;
  writeGoals(goals);
  return updated;
}

export function deleteGoal(id: string, userId: string): boolean {
  const goals = readGoals();
  const remaining = goals.filter(g => !(g.id === id && g.userId === userId));
  if (remaining.length === goals.length) return false;
  writeGoals(remaining);
  return true;
}
