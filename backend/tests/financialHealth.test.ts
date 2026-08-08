import request from 'supertest';
import app from '../src/app';
import db from '../src/db';

const input = {
  currency: 'INR',
  liquidSavings: '600000',
  monthlyNetIncome: '100000',
  monthlyEssentialExpenses: '100000',
  monthlyDebtPayments: '20000',
  monthlySavings: '20000',
};

beforeEach(() => {
  db.prepare('DELETE FROM users').run();
});
async function token() {
  const response = await request(app).post('/api/auth/register').send({
    email: 'health@example.com',
    password: 'password123',
  });
  return response.body.token as string;
}

describe('Financial health score E2E', () => {
  test('requires authentication', async () => {
    const response = await request(app)
      .post('/api/v1/financial-health-score')
      .send(input);
    expect(response.status).toBe(401);
  });

  test('returns transparent score components and metrics', async () => {
    const response = await request(app)
      .post('/api/v1/financial-health-score')
      .set('Authorization', `Bearer ${await token()}`)
      .send(input);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      apiVersion: 'v1',
      score: 100,
      rating: 'excellent',
      componentScores: {
        emergencyFund: 100,
        debtBurden: 100,
        savingsRate: 100,
      },
      metrics: {
        emergencyFundMonths: '6',
        debtToIncomePercent: '20',
        savingsRatePercent: '20',
      },
      findings: [],
    });
  }, 30_000);

  test('rejects non-string financial values', async () => {
    const response = await request(app)
      .post('/api/v1/financial-health-score')
      .set('Authorization', `Bearer ${await token()}`)
      .send({ ...input, monthlySavings: 20000 });
    expect(response.status).toBe(400);
    expect(response.body.error).toContain('monthlySavings');
  }, 30_000);
});
