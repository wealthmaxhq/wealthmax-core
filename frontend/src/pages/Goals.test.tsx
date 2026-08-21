import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import Goals from './Goals';

const api = vi.hoisted(() => ({
  createGoal: vi.fn(),
  deleteGoal: vi.fn(),
  listGoals: vi.fn(),
  updateGoal: vi.fn(),
}));
vi.mock('../api', () => api);

const homeGoal = {
  id: 'goal-1', title: 'Home deposit', targetAmount: 100000,
  currentAmount: 25000, targetDate: '2027-12-31', notes: 'First home',
  createdAt: '2026-08-01T00:00:00.000Z', updatedAt: '2026-08-02T00:00:00.000Z',
};

function renderGoals() {
  return render(<MemoryRouter><Goals /></MemoryRouter>);
}

describe('Goals', () => {
  afterEach(() => vi.restoreAllMocks());

  beforeEach(() => {
    Object.values(api).forEach((mock) => mock.mockReset());
    api.listGoals.mockResolvedValue({ data: { goals: [homeGoal] } });
    api.createGoal.mockResolvedValue({ data: { goal: homeGoal } });
    api.updateGoal.mockResolvedValue({ data: { goal: homeGoal } });
    api.deleteGoal.mockResolvedValue({});
  });

  test('renders totals, capped progress, notes, dates, and a linked report action', async () => {
    renderGoals();

    expect(await screen.findByRole('heading', { name: 'Home deposit' })).toBeInTheDocument();
    expect(screen.getAllByText('25%')).toHaveLength(2);
    expect(screen.getAllByText((25000).toLocaleString())).toHaveLength(2);
    expect(screen.getByText((100000).toLocaleString())).toBeInTheDocument();
    expect(screen.getByText('First home')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Reports' })).toHaveAttribute(
      'href', '/reports?goalId=goal-1',
    );
  });

  test('creates, edits, and deletes goals with normalized financial inputs', async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true);
    renderGoals();
    await screen.findByRole('heading', { name: 'Home deposit' });

    await user.type(screen.getByLabelText('Goal name'), '  Emergency reserve  ');
    await user.type(screen.getByLabelText('Target amount'), '600000');
    await user.clear(screen.getByLabelText('Amount saved'));
    await user.type(screen.getByLabelText('Amount saved'), '150000');
    await user.type(screen.getByLabelText('Target date (optional)'), '2027-06-30');
    await user.type(screen.getByLabelText('Notes (optional)'), '  Six months of expenses  ');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));
    await waitFor(() => expect(api.createGoal).toHaveBeenCalledWith({
      title: 'Emergency reserve', targetAmount: 600000, currentAmount: 150000,
      targetDate: '2027-06-30', notes: 'Six months of expenses',
    }));

    await user.click(screen.getByRole('button', { name: 'Edit' }));
    const name = screen.getByLabelText('Goal name');
    await user.clear(name); await user.type(name, 'Primary home deposit');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(api.updateGoal).toHaveBeenCalledWith('goal-1', {
      title: 'Primary home deposit', targetAmount: 100000, currentAmount: 25000,
      targetDate: '2027-12-31', notes: 'First home',
    }));

    await user.click(screen.getByRole('button', { name: 'Delete' }));
    expect(confirm).toHaveBeenCalledWith('Delete “Home deposit” permanently?');
    await waitFor(() => expect(api.deleteGoal).toHaveBeenCalledWith('goal-1'));
  });

  test('shows server errors, preserves form input, and re-enables saving', async () => {
    const user = userEvent.setup();
    api.createGoal.mockRejectedValue({ response: { data: { error: 'Target date must be in the future.' } } });
    renderGoals();
    await screen.findByRole('heading', { name: 'Home deposit' });

    await user.type(screen.getByLabelText('Goal name'), 'Retirement');
    await user.type(screen.getByLabelText('Target amount'), '5000000');
    await user.click(screen.getByRole('button', { name: 'Create goal' }));

    expect(await screen.findByText('Target date must be in the future.')).toBeInTheDocument();
    expect(screen.getByLabelText('Goal name')).toHaveValue('Retirement');
    expect(screen.getByRole('button', { name: 'Create goal' })).toBeEnabled();
    expect(api.listGoals).toHaveBeenCalledOnce();
  });
});
