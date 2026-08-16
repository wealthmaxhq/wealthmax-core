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

export interface PortfolioSnapshot {
  id: string;
  currency: PortfolioCurrency;
  assets: number;
  liabilities: number;
  netWorth: number;
  recordedAt: string;
}

function recordSnapshot(userId: string, currency: PortfolioCurrency, recordedAt: string) {
  const totals = db.prepare(`SELECT
    COALESCE(SUM(CASE WHEN kind = 'asset' THEN value ELSE 0 END), 0) AS assets,
    COALESCE(SUM(CASE WHEN kind = 'liability' THEN value ELSE 0 END), 0) AS liabilities
    FROM portfolio_entries WHERE userId = ? AND currency = ?`).get(userId, currency) as {
      assets: number;
      liabilities: number;
    };
  db.prepare(`INSERT INTO portfolio_snapshots
    (id, userId, currency, assets, liabilities, netWorth, recordedAt)
    VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(randomUUID(), userId, currency, totals.assets, totals.liabilities,
      totals.assets - totals.liabilities, recordedAt);
}

export function listPortfolioHistory(
  userId: string,
  currency: PortfolioCurrency,
  limit: number,
): PortfolioSnapshot[] {
  return db.prepare(`SELECT id, currency, assets, liabilities, netWorth, recordedAt
    FROM portfolio_snapshots WHERE userId = ? AND currency = ?
    ORDER BY recordedAt DESC, rowid DESC LIMIT ?`).all(userId, currency, limit) as PortfolioSnapshot[];
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
  db.transaction(() => {
    db.prepare(`INSERT INTO portfolio_entries
      (id, userId, name, kind, category, currency, value, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(id, userId, input.name, input.kind, input.category, input.currency, input.value, now, now);
    recordSnapshot(userId, input.currency, now);
  })();
  return { id, userId, ...input, createdAt: now, updatedAt: now };
}

export function updatePortfolioEntry(
  id: string,
  userId: string,
  input: PortfolioInput,
): PortfolioEntry | undefined {
  const updatedAt = new Date().toISOString();
  const existing = db.prepare('SELECT currency FROM portfolio_entries WHERE id = ? AND userId = ?')
    .get(id, userId) as { currency: PortfolioCurrency } | undefined;
  if (!existing) return undefined;
  db.transaction(() => {
    db.prepare(`UPDATE portfolio_entries SET name = ?, kind = ?, category = ?,
      currency = ?, value = ?, updatedAt = ? WHERE id = ? AND userId = ?`)
      .run(input.name, input.kind, input.category, input.currency, input.value, updatedAt, id, userId);
    recordSnapshot(userId, input.currency, updatedAt);
    if (existing.currency !== input.currency) recordSnapshot(userId, existing.currency, updatedAt);
  })();
  return db.prepare(`SELECT id, userId, name, kind, category, currency, value,
    createdAt, updatedAt FROM portfolio_entries WHERE id = ? AND userId = ?`)
    .get(id, userId) as PortfolioEntry;
}

export function deletePortfolioEntry(id: string, userId: string): boolean {
  return db.transaction(() => {
    const existing = db.prepare('SELECT currency FROM portfolio_entries WHERE id = ? AND userId = ?')
      .get(id, userId) as { currency: PortfolioCurrency } | undefined;
    if (!existing) return false;
    db.prepare('DELETE FROM portfolio_entries WHERE id = ? AND userId = ?').run(id, userId);
    recordSnapshot(userId, existing.currency, new Date().toISOString());
    return true;
  })();
}
