import db from '../db';

function rows(sql: string, userId: string): Array<Record<string, unknown>> {
  return db.prepare(sql).all(userId) as Array<Record<string, unknown>>;
}

export function accountDataExport(userId: string, exportedAt = new Date().toISOString()) {
  const account = db.prepare(
    'SELECT id, email, name, createdAt FROM users WHERE id = ?',
  ).get(userId) as Record<string, unknown> | undefined;
  if (!account) return undefined;

  const reports = rows(`SELECT id, goalId, title, currency, schemaVersion,
    sourceFormulaId, snapshotJson, createdAt FROM decision_reports
    WHERE userId = ? ORDER BY createdAt, id`, userId).map(({ snapshotJson, ...report }) => ({
      ...report,
      report: JSON.parse(snapshotJson as string),
    }));
  const health = rows(`SELECT id, currency, score, rating, resultJson, recordedAt
    FROM financial_health_snapshots WHERE userId = ? ORDER BY recordedAt, id`, userId)
    .map(({ resultJson, ...snapshot }) => ({
      ...snapshot,
      result: JSON.parse(resultJson as string),
    }));

  return {
    exportVersion: 1,
    exportedAt,
    account,
    goals: rows(`SELECT id, title, targetAmount, currentAmount, targetDate, notes,
      createdAt, updatedAt FROM goals WHERE userId = ? ORDER BY createdAt, id`, userId),
    decisionReports: reports,
    portfolio: {
      entries: rows(`SELECT id, name, kind, category, currency, value, createdAt,
        updatedAt FROM portfolio_entries WHERE userId = ? ORDER BY createdAt, id`, userId),
      snapshots: rows(`SELECT id, currency, assets, liabilities, netWorth, recordedAt
        FROM portfolio_snapshots WHERE userId = ? ORDER BY recordedAt, id`, userId),
    },
    financialHealthSnapshots: health,
  };
}

export const accountDataExportFilename = 'wealthmax-account-data.json';
