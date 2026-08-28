import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import Portfolio from './Portfolio';

const api = vi.hoisted(() => ({
  createPortfolioEntry: vi.fn(),
  deletePortfolioEntry: vi.fn(),
  exportPortfolioCsv: vi.fn(),
  getPortfolioHistory: vi.fn(),
  listPortfolio: vi.fn(),
  updatePortfolioEntry: vi.fn(),
}));
vi.mock('../api', () => api);

const brokerage = {
  id: 'portfolio-1', name: 'Brokerage', kind: 'asset' as const,
  category: 'Investments', currency: 'USD' as const, value: 25000,
  createdAt: '2026-08-01T00:00:00.000Z', updatedAt: '2026-08-02T00:00:00.000Z',
};
const summaries = [
  { currency: 'USD' as const, assets: 25000, liabilities: 5000, netWorth: 20000 },
  { currency: 'EUR' as const, assets: 1000, liabilities: 0, netWorth: 1000 },
];
const usdHistory = [{
  id: 'snapshot-1', currency: 'USD' as const, assets: 25000,
  liabilities: 5000, netWorth: 20000, recordedAt: '2026-08-02T00:00:00.000Z',
}];

describe('Portfolio', () => {
  afterEach(() => vi.restoreAllMocks());

  beforeEach(() => {
    Object.values(api).forEach((mock) => mock.mockReset());
    api.listPortfolio.mockResolvedValue({ data: { apiVersion: 'v1', entries: [brokerage], summaries } });
    api.getPortfolioHistory.mockImplementation((currency: string) => Promise.resolve({
      data: { apiVersion: 'v1', currency, snapshots: currency === 'USD' ? usdHistory : [] },
    }));
    api.createPortfolioEntry.mockResolvedValue({ data: { entry: brokerage } });
    api.updatePortfolioEntry.mockResolvedValue({ data: { entry: brokerage } });
    api.deletePortfolioEntry.mockResolvedValue({});
  });

  test('loads currency-safe summaries and switches net-worth history', async () => {
    const user = userEvent.setup();
    render(<Portfolio />);

    expect(await screen.findByRole('heading', { name: 'Brokerage' })).toBeInTheDocument();
    expect(screen.getByText('USD net worth')).toBeInTheDocument();
    expect(screen.getByText('EUR net worth')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'USD net-worth history' })).toBeInTheDocument();
    expect(api.getPortfolioHistory).toHaveBeenCalledWith('USD');

    await user.selectOptions(screen.getByLabelText('History currency'), 'EUR');
    await waitFor(() => expect(api.getPortfolioHistory).toHaveBeenLastCalledWith('EUR'));
    expect(await screen.findByText('Changes will appear after you update your portfolio.')).toBeInTheDocument();
  });

  test('creates, edits, and deletes entries through the user workflow', async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true);
    render(<Portfolio />);
    await screen.findByRole('heading', { name: 'Brokerage' });

    await user.type(screen.getByLabelText('Name'), '  Emergency fund  ');
    await user.selectOptions(screen.getByLabelText('Type'), 'asset');
    await user.selectOptions(screen.getByLabelText('Currency'), 'INR');
    await user.type(screen.getByLabelText('Category'), 'Cash');
    await user.type(screen.getByLabelText('Current value'), '100000');
    await user.click(screen.getByRole('button', { name: 'Add entry' }));
    await waitFor(() => expect(api.createPortfolioEntry).toHaveBeenCalledWith({
      name: 'Emergency fund', kind: 'asset', category: 'Cash', currency: 'INR', value: 100000,
    }));

    await user.click(screen.getByRole('button', { name: 'Edit' }));
    const name = screen.getByLabelText('Name');
    await user.clear(name); await user.type(name, 'Long-term investments');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(api.updatePortfolioEntry).toHaveBeenCalledWith(
      'portfolio-1', expect.objectContaining({ name: 'Long-term investments', value: 25000 }),
    ));

    await user.click(screen.getByRole('button', { name: 'Delete' }));
    expect(confirm).toHaveBeenCalledWith('Delete “Brokerage” permanently?');
    await waitFor(() => expect(api.deletePortfolioEntry).toHaveBeenCalledWith('portfolio-1'));
  }, 15_000);

  test('downloads the authenticated portfolio using the server filename', async () => {
    const user = userEvent.setup();
    const blob = new Blob(['portfolio']);
    api.exportPortfolioCsv.mockResolvedValue({
      data: blob, headers: { 'content-disposition': 'attachment; filename="my-portfolio.csv"' },
    });
    const createObjectURL = vi.fn(() => 'blob:portfolio');
    const revokeObjectURL = vi.fn();
    Object.defineProperty(URL, 'createObjectURL', { configurable: true, value: createObjectURL });
    Object.defineProperty(URL, 'revokeObjectURL', { configurable: true, value: revokeObjectURL });
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    render(<Portfolio />);
    await screen.findByRole('heading', { name: 'Brokerage' });

    await user.click(screen.getByRole('button', { name: 'Export CSV' }));

    await waitFor(() => expect(api.exportPortfolioCsv).toHaveBeenCalledOnce());
    expect(createObjectURL).toHaveBeenCalledWith(blob);
    expect(click).toHaveBeenCalledOnce();
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:portfolio');
  });
});
