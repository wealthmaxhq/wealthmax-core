import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, test, vi } from 'vitest';
import FinancialHealth from './FinancialHealth';

const calculateFinancialHealth = vi.hoisted(() => vi.fn());
vi.mock('../api', () => ({ calculateFinancialHealth }));

async function completeForm() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('Liquid savings'), '600000');
  await user.type(screen.getByLabelText('Monthly net income'), '100000');
  await user.type(screen.getByLabelText('Monthly essential expenses'), '50000');
  await user.type(screen.getByLabelText('Monthly debt payments'), '10000');
  await user.type(screen.getByLabelText('Monthly savings'), '20000');
  fireEvent.click(screen.getByRole('button', { name: 'Calculate my score' }));
}

describe('FinancialHealth', () => {
  beforeEach(() => calculateFinancialHealth.mockReset());

  test('submits exact string inputs and renders a transparent score', async () => {
    calculateFinancialHealth.mockResolvedValue({ data: {
      apiVersion: 'v1', score: 92, rating: 'excellent',
      componentScores: { emergencyFund: 100, debtBurden: 90, savingsRate: 85 },
      metrics: { emergencyFundMonths: '12', debtToIncomePercent: '10', savingsRatePercent: '20' },
      findings: [],
    } });
    render(<FinancialHealth />);
    await completeForm();

    expect(calculateFinancialHealth).toHaveBeenCalledWith({
      currency: 'INR', liquidSavings: '600000', monthlyNetIncome: '100000',
      monthlyEssentialExpenses: '50000', monthlyDebtPayments: '10000', monthlySavings: '20000',
    });
    expect(await screen.findByText('92')).toBeInTheDocument();
    expect(screen.getByText('Strong foundations')).toBeInTheDocument();
  });

  test('prevents duplicate submissions while calculation is in progress', async () => {
    let complete!: (value: unknown) => void;
    calculateFinancialHealth.mockReturnValue(new Promise((resolve) => { complete = resolve; }));
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
});
