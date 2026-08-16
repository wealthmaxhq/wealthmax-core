import { StoredDecisionReport } from './storedDecisionReports';

const columns = [
  'Report title',
  'Goal ID',
  'Currency',
  'Created at',
  'Case ID',
  'Case label',
  'Objective',
  'Selected prepayment allocation (%)',
  'After-tax future value',
  'Real after-tax future value',
  'Estimated tax',
  'Selection changed by tax',
];

function cell(value: unknown): string {
  const text = value === undefined || value === null ? '' : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function textCell(value: unknown): string {
  const text = value === undefined || value === null ? '' : String(value);
  return cell(/^[=+\-@]/.test(text) ? `'${text}` : text);
}

export function decisionReportCsv(stored: StoredDecisionReport): string {
  const snapshot = stored.report as { cases?: unknown };
  const cases = Array.isArray(snapshot?.cases) ? snapshot.cases : [];
  const rows = cases.map((item) => {
    const reportCase = item && typeof item === 'object'
      ? item as Record<string, unknown>
      : {};
    return [
      textCell(stored.title),
      textCell(stored.goalId),
      textCell(stored.currency),
      cell(stored.createdAt),
      textCell(reportCase.id),
      textCell(reportCase.label),
      textCell(reportCase.objective),
      cell(reportCase.selectedPrepaymentAllocationPercent),
      cell(reportCase.afterTaxFutureValue),
      cell(reportCase.realAfterTaxFutureValue),
      cell(reportCase.estimatedTax),
      cell(reportCase.selectionChangedByTax),
    ].join(',');
  });

  return `\uFEFF${[columns.map(cell).join(','), ...rows].join('\r\n')}\r\n`;
}

export function decisionReportCsvFilename(title: string): string {
  const safe = title
    .normalize('NFKD')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase()
    .slice(0, 60);
  return `${safe || 'decision-report'}.csv`;
}
