import { randomUUID } from 'node:crypto';
import db from '../db';

export type PortfolioKind = 'asset' | 'liability';
export type PortfolioCurrency = 'INR' | 'USD' | 'EUR';

export interface PortfolioEntry {
  id: string;
  userId: string;
  name: string;
  kind: PortfolioKind;
  category: string;
  currency: PortfolioCurrency;
  value: number;
  createdAt: string;
  updatedAt: string;
}

export interface PortfolioInput {
  name: string;
  kind: PortfolioKind;
  category: string;
  currency: PortfolioCurrency;
  value: number;
}

export function listPortfolioEntries(userId: string): PortfolioEntry[] {
  return db.prepare(`SELECT id, userId, name, kind, category, currency, value,
    createdAt, updatedAt FROM portfolio_entries WHERE userId = ?
    ORDER BY updatedAt DESC, id DESC`).all(userId) as PortfolioEntry[];
}

export function portfolioSummary(entries: PortfolioEntry[]) {
  const totals = new Map<PortfolioCurrency, { assets: number; liabilities: number }>();
  for (const entry of entries) {
    const total = totals.get(entry.currency) ?? { assets: 0, liabilities: 0 };
    total[entry.kind === 'asset' ? 'assets' : 'liabilities'] += entry.value;
    totals.set(entry.currency, total);
  }
  return [...totals.entries()].sort(([first], [second]) => first.localeCompare(second))
    .map(([currency, total]) => ({
      currency,
      assets: Number(total.assets.toFixed(2)),
      liabilities: Number(total.liabilities.toFixed(2)),
      netWorth: Number((total.assets - total.liabilities).toFixed(2)),
    }));
}

export function createPortfolioEntry(userId: string, input: PortfolioInput): PortfolioEntry {
  const id = randomUUID();
  const now = new Date().toISOString();
  db.prepare(`INSERT INTO portfolio_entries
    (id, userId, name, kind, category, currency, value, createdAt, updatedAt)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(id, userId, input.name, input.kind, input.category, input.currency, input.value, now, now);
  return { id, userId, ...input, createdAt: now, updatedAt: now };
}

export function updatePortfolioEntry(
  id: string,
  userId: string,
  input: PortfolioInput,
): PortfolioEntry | undefined {
  const updatedAt = new Date().toISOString();
  const result = db.prepare(`UPDATE portfolio_entries SET name = ?, kind = ?, category = ?,
    currency = ?, value = ?, updatedAt = ? WHERE id = ? AND userId = ?`)
    .run(input.name, input.kind, input.category, input.currency, input.value, updatedAt, id, userId);
  if (!result.changes) return undefined;
  return db.prepare(`SELECT id, userId, name, kind, category, currency, value,
    createdAt, updatedAt FROM portfolio_entries WHERE id = ? AND userId = ?`)
    .get(id, userId) as PortfolioEntry;
}

export function deletePortfolioEntry(id: string, userId: string): boolean {
  return db.prepare('DELETE FROM portfolio_entries WHERE id = ? AND userId = ?')
    .run(id, userId).changes > 0;
}
