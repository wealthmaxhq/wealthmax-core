import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import FinancialHealth from './FinancialHealth';

const api = vi.hoisted(() => ({ calculateFinancialHealth: vi.fn(), getFinancialHealthHistory: vi.fn() }));
vi.mock('../api', () => api);

async function completeForm() {
  fireEvent.change(screen.getByLabelText('Liquid savings'), { target: { value: '600000' } });
  fireEvent.change(screen.getByLabelText('Monthly net income'), { target: { value: '100000' } });
  fireEvent.change(screen.getByLabelText('Monthly essential expenses'), { target: { value: '50000' } });
  fireEvent.change(screen.getByLabelText('Monthly debt payments'), { target: { value: '10000' } });
  fireEvent.change(screen.getByLabelText('Monthly savings'), { target: { value: '20000' } });
  fireEvent.click(screen.getByRole('button', { name: 'Calculate my score' }));
}

describe('FinancialHealth', () => {
  beforeEach(() => {
    api.calculateFinancialHealth.mockReset();
    api.getFinancialHealthHistory.mockReset();
    api.getFinancialHealthHistory.mockResolvedValue({ data: { snapshots: [] } });
  });

  test('submits exact string inputs and renders a transparent score', async () => {
    api.calculateFinancialHealth.mockResolvedValue({ data: {
      apiVersion: 'v1', score: 92, rating: 'excellent',
      componentScores: { emergencyFund: 100, debtBurden: 90, savingsRate: 85 },
      metrics: { emergencyFundMonths: '12', debtToIncomePercent: '10', savingsRatePercent: '20' },
      findings: [],
    } });
    render(<FinancialHealth />);
    await completeForm();

    expect(api.calculateFinancialHealth).toHaveBeenCalledWith({
      currency: 'INR', liquidSavings: '600000', monthlyNetIncome: '100000',
      monthlyEssentialExpenses: '50000', monthlyDebtPayments: '10000', monthlySavings: '20000',
    });
    expect(await screen.findByText('92')).toBeInTheDocument();
    expect(screen.getByText('Strong foundations')).toBeInTheDocument();
    await waitFor(() => expect(api.getFinancialHealthHistory).toHaveBeenCalledTimes(2));
  });

  test('prevents duplicate submissions while calculation is in progress', async () => {
    let complete!: (value: unknown) => void;
    api.calculateFinancialHealth.mockReturnValue(new Promise((resolve) => { complete = resolve; }));
    render(<FinancialHealth />);
    await completeForm();

    expect(screen.getByRole('button', { name: 'Calculating…' })).toBeDisabled();
    complete({ data: {
      apiVersion: 'v1', score: 80, rating: 'good',
      componentScores: { emergencyFund: 80, debtBurden: 80, savingsRate: 80 },
      metrics: { emergencyFundMonths: '6', debtToIncomePercent: '20', savingsRatePercent: '20' },
      findings: [],
    } });
    expect(await screen.findByText('Your financial health score')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Calculate my score' })).toBeEnabled();
  });

  test('restores the latest result and charts chronological score history', async () => {
    const result = {
      apiVersion: 'v1', score: 88, rating: 'good',
      componentScores: { emergencyFund: 90, debtBurden: 85, savingsRate: 89 },
      metrics: { emergencyFundMonths: '5', debtToIncomePercent: '22', savingsRatePercent: '18' },
      findings: ['buildEmergencyFund'],
    };
    api.getFinancialHealthHistory.mockResolvedValue({ data: { snapshots: [
      { id: 'one', currency: 'INR', score: 72, rating: 'fair', result: { ...result, score: 72, rating: 'fair' }, recordedAt: '2026-07-01T00:00:00.000Z' },
      { id: 'two', currency: 'INR', score: 88, rating: 'good', result, recordedAt: '2026-08-01T00:00:00.000Z' },
    ] } });

    render(<FinancialHealth />);

    expect(await screen.findByText('88', { selector: '.health-score strong' })).toBeInTheDocument();
    expect(screen.getByLabelText('Financial health score history')).toBeInTheDocument();
    expect(screen.getByText('2 check-ins')).toBeInTheDocument();
    expect(screen.getByText(/improved by/)).toHaveTextContent('16 points');
  });
});
