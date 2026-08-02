import { randomUUID } from 'node:crypto';
import db from '../db';

export interface DecisionReportSummary {
  id: string;
  title: string;
  currency: string;
  schemaVersion: number;
  sourceFormulaId: string;
  createdAt: string;
}

export interface StoredDecisionReport extends DecisionReportSummary {
  report: unknown;
}

interface SnapshotContract {
  schemaVersion: number;
  sourceReport: {
    formulaId: string;
    title: string;
    currency: string;
  };
}

function snapshotContract(report: unknown): SnapshotContract {
  if (!report || typeof report !== 'object' || Array.isArray(report)) {
    throw new Error('Decision report snapshot must be an object.');
  }
  const value = report as Record<string, unknown>;
  const source = value.sourceReport;
  if (!Number.isInteger(value.schemaVersion) || !source || typeof source !== 'object') {
    throw new Error('Decision report snapshot contract is invalid.');
  }
  const sourceValue = source as Record<string, unknown>;
  if (
    typeof sourceValue.formulaId !== 'string' ||
    typeof sourceValue.title !== 'string' ||
    typeof sourceValue.currency !== 'string'
  ) {
    throw new Error('Decision report snapshot provenance is invalid.');
  }
  return {
    schemaVersion: value.schemaVersion as number,
    sourceReport: {
      formulaId: sourceValue.formulaId,
      title: sourceValue.title,
      currency: sourceValue.currency,
    },
  };
}

function rowSummary(row: Record<string, unknown>): DecisionReportSummary {
  return {
    id: row.id as string,
    title: row.title as string,
    currency: row.currency as string,
    schemaVersion: row.schemaVersion as number,
    sourceFormulaId: row.sourceFormulaId as string,
    createdAt: row.createdAt as string,
  };
}

export function storeDecisionReport(
  userId: string,
  report: unknown,
): StoredDecisionReport {
  const contract = snapshotContract(report);
  const id = randomUUID();
  const createdAt = new Date().toISOString();
  db.prepare(
    `INSERT INTO decision_reports
      (id, userId, title, currency, schemaVersion, sourceFormulaId, snapshotJson, createdAt)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    userId,
    contract.sourceReport.title,
    contract.sourceReport.currency,
    contract.schemaVersion,
    contract.sourceReport.formulaId,
    JSON.stringify(report),
    createdAt,
  );
  return {
    id,
    title: contract.sourceReport.title,
    currency: contract.sourceReport.currency,
    schemaVersion: contract.schemaVersion,
    sourceFormulaId: contract.sourceReport.formulaId,
    createdAt,
    report,
  };
}

export function listDecisionReports(userId: string): DecisionReportSummary[] {
  const rows = db
    .prepare(
      `SELECT id, title, currency, schemaVersion, sourceFormulaId, createdAt
       FROM decision_reports WHERE userId = ? ORDER BY createdAt DESC, id DESC`,
    )
    .all(userId) as Record<string, unknown>[];
  return rows.map(rowSummary);
}

export function getDecisionReport(
  id: string,
  userId: string,
): StoredDecisionReport | undefined {
  const row = db
    .prepare(
      `SELECT id, title, currency, schemaVersion, sourceFormulaId,
              snapshotJson, createdAt
       FROM decision_reports WHERE id = ? AND userId = ?`,
    )
    .get(id, userId) as Record<string, unknown> | undefined;
  if (!row) return undefined;
  return {
    ...rowSummary(row),
    report: JSON.parse(row.snapshotJson as string),
  };
}

export function deleteDecisionReport(id: string, userId: string): boolean {
  const result = db
    .prepare('DELETE FROM decision_reports WHERE id = ? AND userId = ?')
    .run(id, userId);
  return result.changes > 0;
}
