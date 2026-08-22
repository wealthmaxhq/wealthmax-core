import request from 'supertest';
import app from '../src/app';
import db from '../src/db';
import { resetAuthRateLimits } from '../src/lib/authRateLimits';

beforeEach(async () => {
  await resetAuthRateLimits();
  db.prepare('DELETE FROM goals').run();
  db.prepare('DELETE FROM users').run();
});

describe('Auth E2E', () => {
  test('register, login, and get /me', async () => {
    const email = 'test@example.com';
    const password = 'password123';

    // Register
    const reg = await request(app).post('/api/auth/register').send({ email, password, name: 'Tester' });
    expect(reg.status).toBe(200);
    expect(reg.body.token).toBeTruthy();
    const token = reg.body.token;

    // Login
    const login = await request(app).post('/api/auth/login').send({ email, password });
    expect(login.status).toBe(200);
    expect(login.body.token).toBeTruthy();

    // Me
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
    expect(me.body.user.email).toBe(email);
  });

  test('exports only the authenticated account data without credentials', async () => {
    const registration = await request(app).post('/api/auth/register').send({
      email: 'export-owner@example.com', password: 'password123', name: 'Export Owner',
    });
    const userId = registration.body.user.id as string;
    const other = await request(app).post('/api/auth/register').send({
      email: 'export-other@example.com', password: 'password123',
    });
    const now = '2026-08-22T08:00:00.000Z';
    db.prepare(`INSERT INTO goals
      (id, userId, title, targetAmount, currentAmount, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)`)
      .run('export-goal', userId, 'Export goal', 1000, 250, now);
    db.prepare(`INSERT INTO goals
      (id, userId, title, targetAmount, currentAmount, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)`)
      .run('other-goal', other.body.user.id, 'Private other goal', 9999, 0, now);
    db.prepare(`INSERT INTO decision_reports
      (id, userId, title, currency, schemaVersion, sourceFormulaId, snapshotJson, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run('export-report', userId, 'Export report', 'INR', 1, 'REP-002', '{"result":"saved"}', now);
    db.prepare(`INSERT INTO portfolio_entries
      (id, userId, name, kind, category, currency, value, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run('export-entry', userId, 'Savings', 'asset', 'Cash', 'INR', 500, now, now);
    db.prepare(`INSERT INTO portfolio_snapshots
      (id, userId, currency, assets, liabilities, netWorth, recordedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)`)
      .run('export-portfolio-snapshot', userId, 'INR', 500, 0, 500, now);
    db.prepare(`INSERT INTO financial_health_snapshots
      (id, userId, currency, score, rating, resultJson, recordedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)`)
      .run('export-health', userId, 'INR', 82, 'good', '{"score":82,"rating":"good"}', now);

    expect((await request(app).get('/api/auth/me/export')).status).toBe(401);
    const exported = await request(app).get('/api/auth/me/export')
      .set('Authorization', `Bearer ${registration.body.token}`);

    expect(exported.status).toBe(200);
    expect(exported.headers['content-type']).toContain('application/json');
    expect(exported.headers['content-disposition']).toBe(
      'attachment; filename="wealthmax-account-data.json"',
    );
    expect(exported.body).toEqual(expect.objectContaining({
      exportVersion: 1,
      exportedAt: expect.any(String),
      account: { id: userId, email: 'export-owner@example.com', name: 'Export Owner', createdAt: expect.any(String) },
      goals: [expect.objectContaining({ id: 'export-goal', title: 'Export goal' })],
      decisionReports: [expect.objectContaining({ id: 'export-report', report: { result: 'saved' } })],
      portfolio: {
        entries: [expect.objectContaining({ id: 'export-entry', name: 'Savings' })],
        snapshots: [expect.objectContaining({ id: 'export-portfolio-snapshot', netWorth: 500 })],
      },
      financialHealthSnapshots: [expect.objectContaining({ id: 'export-health', result: { score: 82, rating: 'good' } })],
    }));
    const serialized = JSON.stringify(exported.body);
    for (const excluded of ['passwordHash', 'sessionVersion', 'Private other goal', 'userId', 'snapshotJson', 'resultJson']) {
      expect(serialized).not.toContain(excluded);
    }
  }, 30_000);

  test('normalizes identity and enforces registration policy', async () => {
    const registration = await request(app).post('/api/auth/register').send({
      email: '  Mixed.Case@Example.COM ',
      password: 'password123',
      name: '  Wealth Builder  ',
    });
    expect(registration.status).toBe(200);
    expect(registration.body.user).toEqual(expect.objectContaining({
      email: 'mixed.case@example.com',
      name: 'Wealth Builder',
    }));

    const login = await request(app).post('/api/auth/login').send({
      email: 'MIXED.CASE@EXAMPLE.COM',
      password: 'password123',
    });
    expect(login.status).toBe(200);

    const duplicate = await request(app).post('/api/auth/register').send({
      email: 'mixed.case@example.com',
      password: 'another-password',
    });
    expect(duplicate.status).toBe(400);

    const weakPassword = await request(app).post('/api/auth/register').send({
      email: 'weak@example.com',
      password: 'short',
    });
    expect(weakPassword.status).toBe(400);
    expect(weakPassword.body.error).toContain('8 and 128');

    const invalidEmail = await request(app).post('/api/auth/register').send({
      email: 'not-an-email',
      password: 'password123',
    });
    expect(invalidEmail.status).toBe(400);
  }, 20_000);

  test('updates profile and changes password securely', async () => {
    const email = 'account@example.com';
    const password = 'original-password';
    const registration = await request(app).post('/api/auth/register').send({ email, password });
    const authorization = `Bearer ${registration.body.token}`;
    const secondSession = await request(app).post('/api/auth/login').send({ email, password });
    const secondAuthorization = `Bearer ${secondSession.body.token}`;

    const updated = await request(app).patch('/api/auth/me')
      .set('Authorization', authorization).send({ name: '  Account Owner  ' });
    expect(updated.status).toBe(200);
    expect(updated.body.user).toEqual(expect.objectContaining({ email, name: 'Account Owner' }));
    expect(updated.body.user.passwordHash).toBeUndefined();

    const cleared = await request(app).patch('/api/auth/me')
      .set('Authorization', authorization).send({ name: '' });
    expect(cleared.status).toBe(200);
    expect(cleared.body.user.name).toBeUndefined();

    const missingName = await request(app).patch('/api/auth/me')
      .set('Authorization', authorization).send({ email: 'changed@example.com' });
    expect(missingName.status).toBe(400);

    const wrongCurrent = await request(app).post('/api/auth/change-password')
      .set('Authorization', authorization)
      .send({ currentPassword: 'wrong-password', newPassword: 'replacement-password' });
    expect(wrongCurrent.status).toBe(400);

    const weakNew = await request(app).post('/api/auth/change-password')
      .set('Authorization', authorization)
      .send({ currentPassword: password, newPassword: 'short' });
    expect(weakNew.status).toBe(400);

    const changed = await request(app).post('/api/auth/change-password')
      .set('Authorization', authorization)
      .send({ currentPassword: password, newPassword: 'replacement-password' });
    expect(changed.status).toBe(200);
    expect(changed.body.token).toEqual(expect.any(String));

    const revokedFirst = await request(app).get('/api/auth/me')
      .set('Authorization', authorization);
    expect(revokedFirst.status).toBe(401);
    const revokedSecond = await request(app).get('/api/auth/me')
      .set('Authorization', secondAuthorization);
    expect(revokedSecond.status).toBe(401);
    const replacementSession = await request(app).get('/api/auth/me')
      .set('Authorization', `Bearer ${changed.body.token}`);
    expect(replacementSession.status).toBe(200);

    const oldLogin = await request(app).post('/api/auth/login').send({ email, password });
    expect(oldLogin.status).toBe(400);
    const newLogin = await request(app).post('/api/auth/login').send({
      email, password: 'replacement-password',
    });
    expect(newLogin.status).toBe(200);
  }, 30_000);

  test('requires reauthentication and deletes all owned data atomically', async () => {
    const email = 'delete-me@example.com';
    const password = 'delete-password';
    const registration = await request(app).post('/api/auth/register').send({
      email,
      password,
    });
    const userId = registration.body.user.id as string;
    const authorization = `Bearer ${registration.body.token}`;
    const retainedRegistration = await request(app).post('/api/auth/register').send({
      email: 'keep-me@example.com',
      password: 'keep-password',
    });
    const retainedUserId = retainedRegistration.body.user.id as string;

    db.prepare(`INSERT INTO goals
      (id, userId, title, targetAmount, currentAmount, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)`)
      .run('delete-goal', userId, 'Delete goal', 1000, 100, new Date().toISOString());
    db.prepare(`INSERT INTO goals
      (id, userId, title, targetAmount, currentAmount, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)`)
      .run('retained-goal', retainedUserId, 'Retained goal', 2000, 200, new Date().toISOString());
    db.prepare(`INSERT INTO decision_reports
      (id, userId, title, currency, schemaVersion, sourceFormulaId, snapshotJson, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(
        'delete-report', userId, 'Delete report', 'INR', 1, 'REP-002', '{}',
        new Date().toISOString(),
      );

    const missingConfirmation = await request(app).delete('/api/auth/me')
      .set('Authorization', authorization).send({ password, confirmation: 'delete' });
    expect(missingConfirmation.status).toBe(400);

    const wrongPassword = await request(app).delete('/api/auth/me')
      .set('Authorization', authorization)
      .send({ password: 'wrong-password', confirmation: 'DELETE' });
    expect(wrongPassword.status).toBe(400);
    expect(db.prepare('SELECT 1 FROM users WHERE id = ?').get(userId)).toBeDefined();

    const deleted = await request(app).delete('/api/auth/me')
      .set('Authorization', authorization).send({ password, confirmation: 'DELETE' });
    expect(deleted.status).toBe(204);
    expect(db.prepare('SELECT 1 FROM users WHERE id = ?').get(userId)).toBeUndefined();
    expect(db.prepare('SELECT 1 FROM goals WHERE userId = ?').get(userId)).toBeUndefined();
    expect(db.prepare('SELECT 1 FROM decision_reports WHERE userId = ?').get(userId))
      .toBeUndefined();
    expect(db.prepare('SELECT 1 FROM users WHERE id = ?').get(retainedUserId)).toBeDefined();
    expect(db.prepare('SELECT 1 FROM goals WHERE userId = ?').get(retainedUserId))
      .toBeDefined();

    const staleSession = await request(app).get('/api/auth/me')
      .set('Authorization', authorization);
    expect(staleSession.status).toBe(401);
    const login = await request(app).post('/api/auth/login').send({ email, password });
    expect(login.status).toBe(400);
  }, 30_000);
  test('limits repeated login failures per normalized account', async () => {
    await request(app).post('/api/auth/register').send({
      email: 'protected@example.com',
      password: 'correct-password',
    });

    const successful = await request(app).post('/api/auth/login').send({
      email: 'protected@example.com',
      password: 'correct-password',
    });
    expect(successful.status).toBe(200);

    for (let attempt = 0; attempt < 10; attempt += 1) {
      const failure = await request(app).post('/api/auth/login').send({
        email: attempt % 2 === 0
          ? ' PROTECTED@example.com '
          : 'protected@example.com',
        password: 'wrong-password',
      });
      expect(failure.status).toBe(400);
    }

    const limited = await request(app).post('/api/auth/login').send({
      email: 'protected@example.com',
      password: 'wrong-password',
    });
    expect(limited.status).toBe(429);
    expect(limited.body).toEqual({
      error: 'Too many authentication attempts. Please try again later.',
    });
    expect(limited.headers['retry-after']).toEqual(expect.any(String));
    expect(limited.headers['ratelimit']).toEqual(expect.any(String));
    expect(limited.headers['x-ratelimit-limit']).toBeUndefined();

    const unrelated = await request(app).post('/api/auth/login').send({
      email: 'someone-else@example.com',
      password: 'wrong-password',
    });
    expect(unrelated.status).toBe(400);
  }, 30_000);

  test('limits repeated registrations per client', async () => {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const registration = await request(app).post('/api/auth/register').send({
        email: `registration-${attempt}@example.com`,
        password: 'password123',
      });
      expect(registration.status).toBe(200);
    }

    const limited = await request(app).post('/api/auth/register').send({
      email: 'registration-limited@example.com',
      password: 'password123',
    });
    expect(limited.status).toBe(429);
    expect(limited.headers['retry-after']).toEqual(expect.any(String));
  }, 60_000);
});
