import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import DecisionReports from './DecisionReports';

const api = vi.hoisted(() => ({
  createDecisionReport: vi.fn(),
  deleteDecisionReport: vi.fn(),
  exportDecisionReportCsv: vi.fn(),
  getDecisionReport: vi.fn(),
  listDecisionReports: vi.fn(),
  listGoals: vi.fn(),
  updateDecisionReportGoal: vi.fn(),
}));
vi.mock('../api', () => api);

const goal = {
  id: 'goal-1', title: 'Home deposit', targetAmount: 100000,
  currentAmount: 25000, createdAt: '2026-08-01T00:00:00.000Z',
};
const summary = {
  id: 'report-1', title: 'Mortgage choice', currency: 'INR', schemaVersion: 1,
  sourceFormulaId: 'REP-002', createdAt: '2026-08-03T00:00:00.000Z', goalId: 'goal-1',
};
const unlinkedSummary = {
  id: 'report-2', title: 'Unlinked analysis', currency: 'USD', schemaVersion: 1,
  sourceFormulaId: 'REP-002', createdAt: '2026-08-04T00:00:00.000Z',
};
const stored = {
  ...summary,
  report: {
    schemaVersion: 1,
    sourceReport: { formulaId: 'REP-002', title: 'Mortgage choice', currency: 'INR' },
    summary: {
      minimumSelectedValueCaseId: 'base', maximumSelectedValueCaseId: 'base',
      selectedRealValueRange: '1200000', taxChangedSelectionCount: 0,
      criticalWarningCaseCount: 0,
    },
    cases: [{
      id: 'base', label: 'Base case', objective: 'maximumFutureValue',
      selectedPrepaymentAllocationPercent: '40', afterTaxFutureValue: '1500000',
      realAfterTaxFutureValue: '1200000', estimatedTax: '50000',
      selectionChangedByTax: false,
    }],
    warnings: [{ code: 'ASSUMPTION', message: 'Returns are illustrative.', severity: 'info' }],
  },
};

function renderReports(path = '/reports/report-1') {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/reports" element={<DecisionReports />} />
        <Route path="/reports/:reportId" element={<DecisionReports />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('DecisionReports', () => {
  afterEach(() => vi.restoreAllMocks());

  beforeEach(() => {
    localStorage.setItem('token', 'authenticated-token');
    Object.values(api).forEach((mock) => mock.mockReset());
    api.listDecisionReports.mockResolvedValue({ data: { reports: [summary, unlinkedSummary] } });
    api.listGoals.mockResolvedValue({ data: { goals: [goal] } });
    api.getDecisionReport.mockResolvedValue({ data: stored });
    api.updateDecisionReportGoal.mockResolvedValue({ data: stored });
    api.deleteDecisionReport.mockResolvedValue({});
  });

  test('loads a private deep link, renders transparent results, and filters the library', async () => {
    const user = userEvent.setup();
    renderReports();

    expect(await screen.findByText('INR 1200000')).toBeInTheDocument();
    expect(api.getDecisionReport).toHaveBeenCalledWith('report-1');
    expect(screen.getByText('Objective: Build the most future wealth')).toBeInTheDocument();
    expect(screen.getByText('1500000')).toBeInTheDocument();
    expect(screen.getAllByText('50000')).toHaveLength(2);
    expect(screen.getAllByText('40%')).toHaveLength(2);
    expect(screen.getByText('1 calculation notes')).toBeInTheDocument();
    expect(screen.getByText(/INR .* Home deposit/)).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Filter by goal'), 'goal-1');
    expect(screen.getAllByText('Mortgage choice')).toHaveLength(2);
    expect(screen.queryByText('Unlinked analysis')).not.toBeInTheDocument();
  });

  test('reassigns a goal and downloads CSV using the server filename', async () => {
    const user = userEvent.setup();
    const reassigned = { ...stored, goalId: undefined };
    api.updateDecisionReportGoal.mockResolvedValue({ data: reassigned });
    const blob = new Blob(['report']);
    api.exportDecisionReportCsv.mockResolvedValue({
      data: blob, headers: { 'content-disposition': 'attachment; filename="mortgage-choice.csv"' },
    });
    const createObjectURL = vi.fn(() => 'blob:report');
    const revokeObjectURL = vi.fn();
    Object.defineProperty(URL, 'createObjectURL', { configurable: true, value: createObjectURL });
    Object.defineProperty(URL, 'revokeObjectURL', { configurable: true, value: revokeObjectURL });
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    renderReports();
    await screen.findByText('INR 1200000');

    await user.selectOptions(screen.getByLabelText('Goal'), '');
    await waitFor(() => expect(api.updateDecisionReportGoal).toHaveBeenCalledWith('report-1', null));
    await user.click(screen.getByRole('button', { name: 'Download CSV' }));

    await waitFor(() => expect(api.exportDecisionReportCsv).toHaveBeenCalledWith('report-1'));
    expect(createObjectURL).toHaveBeenCalledWith(blob);
    expect(click).toHaveBeenCalledOnce();
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:report');
  });

  test('confirms deletion and refreshes the saved-report library', async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true);
    renderReports();
    await screen.findByText('INR 1200000');

    await user.click(screen.getByRole('button', { name: 'Delete Mortgage choice' }));
    expect(confirm).toHaveBeenCalledWith('Delete this decision report permanently?');
    await waitFor(() => expect(api.deleteDecisionReport).toHaveBeenCalledWith('report-1'));
    expect(api.listDecisionReports.mock.calls.length).toBeGreaterThanOrEqual(2);
  });
});
