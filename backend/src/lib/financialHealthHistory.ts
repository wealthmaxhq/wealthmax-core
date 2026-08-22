import { randomUUID } from 'node:crypto';
import db from '../db';

export interface FinancialHealthSnapshot {
  id: string;
  currency: 'INR' | 'USD' | 'EUR';
  score: number;
  rating: string;
  result: unknown;
  recordedAt: string;
}

interface SnapshotRow {
  id: string;
  currency: FinancialHealthSnapshot['currency'];
  score: number;
  rating: string;
  resultJson: string;
  recordedAt: string;
}

function snapshot(row: SnapshotRow): FinancialHealthSnapshot {
  return {
    id: row.id,
    currency: row.currency,
    score: row.score,
    rating: row.rating,
    result: JSON.parse(row.resultJson),
    recordedAt: row.recordedAt,
  };
}

export function saveFinancialHealthSnapshot(
  userId: string,
  currency: FinancialHealthSnapshot['currency'],
  result: { score: number; rating: string },
): FinancialHealthSnapshot {
  const id = randomUUID();
  const recordedAt = new Date().toISOString();
  db.prepare(`INSERT INTO financial_health_snapshots
    (id, userId, currency, score, rating, resultJson, recordedAt)
    VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(id, userId, currency, result.score, result.rating, JSON.stringify(result), recordedAt);
  return { id, currency, score: result.score, rating: result.rating, result, recordedAt };
}

export function listFinancialHealthSnapshots(userId: string, limit: number): FinancialHealthSnapshot[] {
  const rows = db.prepare(`SELECT id, currency, score, rating, resultJson, recordedAt
    FROM financial_health_snapshots WHERE userId = ?
    ORDER BY recordedAt DESC, rowid DESC LIMIT ?`).all(userId, limit) as SnapshotRow[];
  return rows.map(snapshot).reverse();
}
