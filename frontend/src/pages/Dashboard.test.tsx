import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import Dashboard from './Dashboard';

const api = vi.hoisted(() => ({
  getRecommendations: vi.fn(),
  getFinancialHealthHistory: vi.fn(),
  listDecisionReports: vi.fn(),
  listGoals: vi.fn(),
  listPortfolio: vi.fn(),
}));
vi.mock('../api', () => api);
vi.mock('../auth', () => ({
  useAuth: () => ({ user: { id: 'user-1', email: 'owner@example.com', name: 'Rahul' } }),
}));

const goals = [
  { id: 'goal-1', title: 'Home deposit', targetAmount: 100000, currentAmount: 25000, targetDate: '2027-12-31', createdAt: '2026-08-01T00:00:00.000Z' },
  { id: 'goal-2', title: 'Emergency reserve', targetAmount: 50000, currentAmount: 75000, targetDate: '2027-06-30', createdAt: '2026-08-02T00:00:00.000Z' },
];
const reports = [
  { id: 'report-1', title: 'Mortgage choice', currency: 'INR', schemaVersion: 1, sourceFormulaId: 'REP-002', createdAt: '2026-08-03T00:00:00.000Z', goalId: 'goal-1' },
  { id: 'report-2', title: 'Unlinked analysis', currency: 'USD', schemaVersion: 1, sourceFormulaId: 'REP-002', createdAt: '2026-08-04T00:00:00.000Z' },
];
const recommendations = {
  apiVersion: 'v1', generatedAt: '2026-08-05T00:00:00.000Z',
  savings: { totalMonthlyRequired: 12500, breakdown: [{ id: 'goal-1', title: 'Home deposit', remaining: 75000, months: 12, monthly: 6250 }] },
  allocation: { profile: 'Balanced', allocation: { stocks: 0.6, bonds: 0.3, cash: 0.1 }, reason: 'Your goals have a medium-term horizon.' },
};
const portfolioEntries = [
  { id: 'entry-1', name: 'Cash', kind: 'asset', category: 'Cash', currency: 'INR', value: 100000, createdAt: '', updatedAt: '' },
  { id: 'entry-2', name: 'Brokerage', kind: 'asset', category: 'Investments', currency: 'USD', value: 1000, createdAt: '', updatedAt: '' },
];

function renderDashboard() {
  return render(<MemoryRouter><Dashboard /></MemoryRouter>);
}

describe('Dashboard', () => {
  beforeEach(() => {
    Object.values(api).forEach((mock) => mock.mockReset());
    api.listGoals.mockResolvedValue({ data: { goals } });
    api.listDecisionReports.mockResolvedValue({ data: { reports } });
    api.getRecommendations.mockResolvedValue({ data: { recommendations } });
    api.listPortfolio.mockResolvedValue({ data: {
      entries: portfolioEntries,
      summaries: [
        { currency: 'INR', assets: 100000, liabilities: 0, netWorth: 100000 },
        { currency: 'USD', assets: 1000, liabilities: 0, netWorth: 1000 },
      ],
    } });
    api.getFinancialHealthHistory.mockResolvedValue({ data: { snapshots: [{
      id: 'health-1', currency: 'INR', score: 84, rating: 'good',
      result: {}, recordedAt: '2026-08-05T00:00:00.000Z',
    }] } });
  });

  test('consolidates goals, reports, portfolio, and recommendations accurately', async () => {
    renderDashboard();

    expect(await screen.findByRole('heading', { name: 'Welcome back, Rahul.' })).toBeInTheDocument();
    expect(screen.getByText('67%')).toBeInTheDocument();
    expect(screen.getByText(`${(100000).toLocaleString()} of ${(150000).toLocaleString()}`)).toBeInTheDocument();
    expect(screen.getByText('Next: Emergency reserve')).toBeInTheDocument();
    expect(screen.getByText('1 linked to goals')).toBeInTheDocument();
    expect(screen.getByText('2 currency summaries')).toBeInTheDocument();
    expect(screen.getByText('100%')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Mortgage choice/ })).toHaveAttribute('href', '/reports/report-1');
    expect(screen.getByText('INR · Home deposit')).toBeInTheDocument();
    expect(screen.getByText('USD · No linked goal')).toBeInTheDocument();
    expect(screen.getByText((12500).toLocaleString())).toBeInTheDocument();
    expect(screen.getByText('Balanced')).toBeInTheDocument();
    expect(screen.getByText('60% stocks')).toBeInTheDocument();
    expect(screen.getByText('84/100')).toBeInTheDocument();
    expect(screen.getByText(/good ·/i)).toBeInTheDocument();
  });

  test('renders deliberate empty states without showing irrelevant recommendations', async () => {
    api.listGoals.mockResolvedValue({ data: { goals: [] } });
    api.listDecisionReports.mockResolvedValue({ data: { reports: [] } });
    api.listPortfolio.mockResolvedValue({ data: { entries: [], summaries: [] } });
    api.getFinancialHealthHistory.mockResolvedValue({ data: { snapshots: [] } });
    renderDashboard();

    expect(await screen.findByText('No goals yet.')).toBeInTheDocument();
    expect(screen.getByText('No reports yet.')).toBeInTheDocument();
    expect(screen.getByText('Add assets and liabilities')).toBeInTheDocument();
    expect(screen.getByText('Add a target date to plan ahead')).toBeInTheDocument();
    expect(screen.getByText('Complete your first check-in')).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Fund your goals deliberately' })).not.toBeInTheDocument();
  });

  test('keeps successful planning data visible and retries a failed service', async () => {
    const user = userEvent.setup();
    api.listPortfolio.mockRejectedValueOnce({ response: { data: { error: 'Portfolio service is unavailable.' } } });
    renderDashboard();

    expect(await screen.findByRole('alert')).toHaveTextContent('Portfolio service is unavailable.');
    expect(screen.getByRole('alert')).toHaveTextContent('available planning data is shown below');
    expect(screen.queryByText('Loading your plan…')).not.toBeInTheDocument();
    expect(screen.getByText('Home deposit')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Mortgage choice/ })).toBeInTheDocument();
    expect(screen.getByText('Balanced')).toBeInTheDocument();
    expect(screen.getByText('84/100')).toBeInTheDocument();
    expect(screen.getByText('Add assets and liabilities')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Retry' }));

    expect(await screen.findByText('2 currency summaries')).toBeInTheDocument();
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(api.listPortfolio).toHaveBeenCalledTimes(2);
  });

  test('uses a stable summary when multiple dashboard services fail', async () => {
    api.listGoals.mockRejectedValue(new Error('goals failed'));
    api.listDecisionReports.mockRejectedValue(new Error('reports failed'));
    renderDashboard();

    expect(await screen.findByRole('alert')).toHaveTextContent('2 dashboard services could not be loaded.');
    expect(screen.getByText('2 currency summaries')).toBeInTheDocument();
    expect(screen.getByText('84/100')).toBeInTheDocument();
  });
});
