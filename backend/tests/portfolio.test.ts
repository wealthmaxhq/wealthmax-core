import request from 'supertest';
import app from '../src/app';
import db from '../src/db';

beforeEach(() => {
  db.prepare('DELETE FROM portfolio_entries').run();
  db.prepare('DELETE FROM users').run();
});

async function register(email: string) {
  const response = await request(app).post('/api/auth/register')
    .send({ email, password: 'password123' });
  return response.body as { token: string; user: { id: string } };
}

describe('Portfolio E2E', () => {
  test('creates, summarizes, updates, and deletes entries by currency', async () => {
    const owner = await register('portfolio@example.com');
    const authorization = `Bearer ${owner.token}`;
    const asset = await request(app).post('/api/v1/portfolio').set('Authorization', authorization)
      .send({ name: 'Brokerage', kind: 'asset', category: 'Investments', currency: 'USD', value: 25000 });
    const debt = await request(app).post('/api/v1/portfolio').set('Authorization', authorization)
      .send({ name: 'Home loan', kind: 'liability', category: 'Mortgage', currency: 'USD', value: 9000 });
    await request(app).post('/api/v1/portfolio').set('Authorization', authorization)
      .send({ name: 'Cash', kind: 'asset', category: 'Cash', currency: 'INR', value: 100000 });
    expect(asset.status).toBe(201);
    expect(debt.status).toBe(201);

    const list = await request(app).get('/api/v1/portfolio').set('Authorization', authorization);
    expect(list.status).toBe(200);
    expect(list.body.entries).toHaveLength(3);
    expect(list.body.summaries).toEqual([
      { currency: 'INR', assets: 100000, liabilities: 0, netWorth: 100000 },
      { currency: 'USD', assets: 25000, liabilities: 9000, netWorth: 16000 },
    ]);

    const updated = await request(app).put(`/api/v1/portfolio/${debt.body.entry.id}`)
      .set('Authorization', authorization)
      .send({ name: 'Home loan', kind: 'liability', category: 'Mortgage', currency: 'USD', value: 8000 });
    expect(updated.status).toBe(200);
    expect(updated.body.entry.value).toBe(8000);

    const deleted = await request(app).delete(`/api/v1/portfolio/${asset.body.entry.id}`)
      .set('Authorization', authorization);
    expect(deleted.status).toBe(204);

    const history = await request(app).get('/api/v1/portfolio/history?currency=USD&limit=10')
      .set('Authorization', authorization);
    expect(history.status).toBe(200);
    expect(history.body.snapshots).toHaveLength(4);
    expect(history.body.snapshots.at(-1)).toEqual(expect.objectContaining({
      currency: 'USD', assets: 0, liabilities: 8000, netWorth: -8000,
    }));
  });

  test('validates input and isolates every mutation by user', async () => {
    const owner = await register('portfolio-owner@example.com');
    const other = await register('portfolio-other@example.com');
    const created = await request(app).post('/api/v1/portfolio')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ name: 'Savings', kind: 'asset', category: 'Cash', currency: 'EUR', value: 500 });

    const invalid = await request(app).post('/api/v1/portfolio')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ name: 'Invalid', kind: 'asset', category: 'Cash', currency: 'GBP', value: -1 });
    expect(invalid.status).toBe(400);

    const hiddenUpdate = await request(app).put(`/api/v1/portfolio/${created.body.entry.id}`)
      .set('Authorization', `Bearer ${other.token}`)
      .send({ name: 'Stolen', kind: 'asset', category: 'Cash', currency: 'EUR', value: 999 });
    const hiddenDelete = await request(app).delete(`/api/v1/portfolio/${created.body.entry.id}`)
      .set('Authorization', `Bearer ${other.token}`);
    expect(hiddenUpdate.status).toBe(404);
    expect(hiddenDelete.status).toBe(404);
    const otherList = await request(app).get('/api/v1/portfolio')
      .set('Authorization', `Bearer ${other.token}`);
    expect(otherList.body.entries).toHaveLength(0);
    const otherHistory = await request(app).get('/api/v1/portfolio/history?currency=EUR')
      .set('Authorization', `Bearer ${other.token}`);
    expect(otherHistory.body.snapshots).toHaveLength(0);

    const badCurrency = await request(app).get('/api/v1/portfolio/history?currency=GBP')
      .set('Authorization', `Bearer ${owner.token}`);
    const badLimit = await request(app).get('/api/v1/portfolio/history?currency=EUR&limit=1000')
      .set('Authorization', `Bearer ${owner.token}`);
    expect(badCurrency.status).toBe(400);
    expect(badLimit.status).toBe(400);
  });

  test('requires authentication', async () => {
    expect((await request(app).get('/api/v1/portfolio')).status).toBe(401);
    expect((await request(app).get('/api/v1/portfolio/export.csv')).status).toBe(401);
  });

  test('exports only the authenticated user portfolio as an Excel-compatible CSV', async () => {
    const owner = await register('portfolio-export-owner@example.com');
    const other = await register('portfolio-export-other@example.com');
    await request(app).post('/api/v1/portfolio').set('Authorization', `Bearer ${owner.token}`)
      .send({ name: '=Brokerage, "Primary"', kind: 'asset', category: 'Investments', currency: 'USD', value: 25000.5 });
    await request(app).post('/api/v1/portfolio').set('Authorization', `Bearer ${other.token}`)
      .send({ name: 'Private account', kind: 'asset', category: 'Cash', currency: 'EUR', value: 999 });

    const exported = await request(app).get('/api/v1/portfolio/export.csv')
      .set('Authorization', `Bearer ${owner.token}`);
    expect(exported.status).toBe(200);
    expect(exported.headers['content-type']).toContain('text/csv');
    expect(exported.headers['content-disposition']).toBe('attachment; filename="wealthmax-portfolio.csv"');
    expect(exported.text.startsWith('\uFEFFName,Type,Category,Currency,Value,Created at,Updated at\r\n')).toBe(true);
    expect(exported.text).toContain('"\'=Brokerage, ""Primary""",asset,Investments,USD,25000.5');
    expect(exported.text).not.toContain('Private account');
  });
});
