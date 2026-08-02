import {
  decisionReportCsv,
  decisionReportCsvFilename,
} from '../src/lib/decisionReportCsv';

describe('decision report CSV', () => {
  test('emits UTF-8 Excel-compatible rows and escapes spreadsheet cells', () => {
    const csv = decisionReportCsv({
      id: 'report-1',
      title: 'Loan, "invest"',
      currency: 'INR',
      schemaVersion: 1,
      sourceFormulaId: 'REP-001',
      createdAt: '2026-08-02T00:00:00.000Z',
      report: {
        cases: [
          {
            id: 'base',
            label: 'Base\ncase',
            selectedPrepaymentAllocationPercent: '50',
            afterTaxFutureValue: '1200.50',
            realAfterTaxFutureValue: '1100.25',
            estimatedTax: '25',
            selectionChangedByTax: false,
          },
        ],
      },
    });

    expect(csv.startsWith('\uFEFF')).toBe(true);
    expect(csv).toContain('"Loan, ""invest"""');
    expect(csv).toContain('"Base\ncase"');
    expect(csv).toContain(',50,1200.50,1100.25,25,false\r\n');
  });

  test('creates a safe deterministic download filename', () => {
    expect(decisionReportCsvFilename('  Loan vs. Investment / 2026  ')).toBe(
      'loan-vs-investment-2026.csv',
    );
    expect(decisionReportCsvFilename('***')).toBe('decision-report.csv');
  });

  test('neutralizes formulas in user-controlled text without changing numbers', () => {
    const csv = decisionReportCsv({
      id: 'report-1',
      title: '=HYPERLINK("unsafe")',
      currency: 'USD',
      schemaVersion: 1,
      sourceFormulaId: 'REP-001',
      createdAt: '2026-08-02T00:00:00.000Z',
      report: {
        cases: [{ id: '@case', label: '+label', afterTaxFutureValue: '-25' }],
      },
    });

    expect(csv).toContain('"\'=HYPERLINK(""unsafe"")"');
    expect(csv).toContain("'@case,'+label");
    expect(csv).toContain(',-25,');
  });
});
