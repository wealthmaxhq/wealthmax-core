import request from 'supertest';
import app from '../src/app';
import db from '../src/db';

const report = {
  title: 'API decision report',
  cases: [
    {
      id: 'base',
      label: 'Base case',
      currency: 'INR',
      loan: {
        principal: '10000',
        annualInterestRatePercent: '10',
        tenureMonths: 12,
      },
      extraCash: '1000',
      decisionInstallment: 1,
      grossAnnualInvestmentReturnPercent: '20',
      annualExpenseRatioPercent: '1',
      allocationStepPercent: 50,
      objective: 'maximumFutureValue',
      grossAnnualReturnScenariosPercent: ['0', '20', '30'],
      investmentGainTaxRatePercent: '20',
      annualInflationRatePercent: '6',
    },
  ],
};

beforeEach(() => {
  db.prepare('DELETE FROM decision_reports').run();
  db.prepare('DELETE FROM goals').run();
  db.prepare('DELETE FROM users').run();
});

async function token() {
  const registration = await request(app).post('/api/auth/register').send({
    email: 'reports@example.com',
    password: 'password123',
    name: 'Report User',
  });
  return registration.body.token as string;
}

describe('Decision reports E2E', () => {
  test('requires authentication', async () => {
    const response = await request(app)
      .post('/api/v1/decision-reports')
      .send(report);

    expect(response.status).toBe(401);
  });

  test('returns a versioned REP-002 portable snapshot', async () => {
    const ownerToken = await token();
    const response = await request(app)
      .post('/api/v1/decision-reports')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send(report);

    expect(response.status).toBe(201);
    expect(response.body.apiVersion).toBe('v1');
    expect(response.body.id).toEqual(expect.any(String));
    expect(response.body.createdAt).toEqual(expect.any(String));
    expect(response.body.report.schemaVersion).toBe(1);
    expect(response.body.report.snapshotFormula.id).toBe('REP-002');
    expect(response.body.report.sourceReport.formulaId).toBe('REP-001');
    expect(response.body.report.sourceReport.title).toBe('API decision report');
    expect(response.body.report.cases).toHaveLength(1);
    expect(response.body.report.cases[0].realAfterTaxFutureValue).toEqual(
      expect.any(String),
    );

    const list = await request(app)
      .get('/api/v1/decision-reports')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(list.status).toBe(200);
    expect(list.body.reports).toHaveLength(1);
    expect(list.body.reports[0]).not.toHaveProperty('report');
    expect(list.body.reports[0].id).toBe(response.body.id);

    const get = await request(app)
      .get(`/api/v1/decision-reports/${response.body.id}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(get.status).toBe(200);
    expect(get.body.report).toEqual(response.body.report);

    const otherRegistration = await request(app)
      .post('/api/auth/register')
      .send({ email: 'other@example.com', password: 'password123' });
    const otherToken = otherRegistration.body.token as string;
    const hidden = await request(app)
      .get(`/api/v1/decision-reports/${response.body.id}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(hidden.status).toBe(404);

    const hiddenDelete = await request(app)
      .delete(`/api/v1/decision-reports/${response.body.id}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(hiddenDelete.status).toBe(404);

    const deletion = await request(app)
      .delete(`/api/v1/decision-reports/${response.body.id}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(deletion.status).toBe(204);

    const missing = await request(app)
      .get(`/api/v1/decision-reports/${response.body.id}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(missing.status).toBe(404);
  }, 120_000);

  test('rejects non-string financial decimals', async () => {
    const invalid = structuredClone(report);
    invalid.cases[0].loan.principal = 10000 as unknown as string;
    const response = await request(app)
      .post('/api/v1/decision-reports')
      .set('Authorization', `Bearer ${await token()}`)
      .send(invalid);

    expect(response.status).toBe(400);
    expect(response.body.error).toContain('principal');
  }, 120_000);
});
