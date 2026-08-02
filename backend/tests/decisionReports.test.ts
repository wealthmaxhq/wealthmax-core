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
    const response = await request(app)
      .post('/api/v1/decision-reports')
      .set('Authorization', `Bearer ${await token()}`)
      .send(report);

    expect(response.status).toBe(201);
    expect(response.body.apiVersion).toBe('v1');
    expect(response.body.report.schemaVersion).toBe(1);
    expect(response.body.report.snapshotFormula.id).toBe('REP-002');
    expect(response.body.report.sourceReport.formulaId).toBe('REP-001');
    expect(response.body.report.sourceReport.title).toBe('API decision report');
    expect(response.body.report.cases).toHaveLength(1);
    expect(response.body.report.cases[0].realAfterTaxFutureValue).toEqual(
      expect.any(String),
    );
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
