import { portfolioCsv, portfolioCsvFilename } from '../src/lib/portfolioCsv';
import { PortfolioEntry } from '../src/lib/portfolio';

describe('portfolio CSV', () => {
  test('creates a stable Excel-compatible export and neutralizes spreadsheet formulas', () => {
    const entry: PortfolioEntry = {
      id: 'entry-1',
      userId: 'user-1',
      name: '=SUM(1,1)',
      kind: 'asset',
      category: 'Quoted "category"\nwith a new line',
      currency: 'USD',
      value: 1234.56,
      createdAt: '2026-08-16T01:02:03.000Z',
      updatedAt: '2026-08-16T04:05:06.000Z',
    };

    expect(portfolioCsv([entry])).toBe(
      '\uFEFFName,Type,Category,Currency,Value,Created at,Updated at\r\n'
      + '"\'=SUM(1,1)",asset,"Quoted ""category""\nwith a new line",USD,1234.56,2026-08-16T01:02:03.000Z,2026-08-16T04:05:06.000Z\r\n',
    );
    expect(portfolioCsv([])).toBe('\uFEFFName,Type,Category,Currency,Value,Created at,Updated at\r\n');
    expect(portfolioCsvFilename).toBe('wealthmax-portfolio.csv');
  });
});
