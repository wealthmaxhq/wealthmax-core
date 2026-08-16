import request from 'supertest';
import app from '../src/app';
import db from '../src/db';
import { createGoal } from '../src/lib/goals';
import { getRecommendations } from '../src/lib/recommendations';

beforeEach(() => {
  db.prepare('DELETE FROM goals').run();
  db.prepare('DELETE FROM users').run();
});

async function register(email: string) {
  const response = await request(app).post('/api/auth/register').send({
    email,
    password: 'pass1234',
  });
  return response.body as { token: string; user: { id: string } };
}

describe('Recommendations', () => {
  test('requires authentication', async () => {
    const response = await request(app).get('/api/v1/recommendations');
    expect(response.status).toBe(401);
  });

  test('returns only the current user goals with rounded monthly targets', async () => {
    const owner = await register('recommendations-owner@example.com');
    const other = await register('recommendations-other@example.com');
    createGoal(owner.user.id, { title: 'Emergency reserve', targetAmount: 10_000, currentAmount: 1_000, targetDate: '2027-01-01' });
    createGoal(other.user.id, { title: 'Private goal', targetAmount: 999_999 });

    const result = getRecommendations(owner.user.id, new Date('2026-08-16T12:00:00Z'));
    expect(result.savings).toEqual({
      totalMonthlyRequired: 1800,
      breakdown: [expect.objectContaining({ title: 'Emergency reserve', remaining: 9000, months: 5, monthly: 1800 })],
    });
    expect(result.allocation.profile).toBe('Conservative');
    expect(JSON.stringify(result)).not.toContain('Private goal');

    const response = await request(app).get('/api/v1/recommendations').set('Authorization', `Bearer ${owner.token}`);
    expect(response.status).toBe(200);
    expect(response.body.recommendations.apiVersion).toBe('v1');
    expect(response.body.recommendations.savings.breakdown).toHaveLength(1);
    expect(response.body.recommendations.user).toBeUndefined();
  });

  test('uses stable defaults and never recommends negative savings', async () => {
    const owner = await register('recommendations-defaults@example.com');
    createGoal(owner.user.id, { title: 'Already funded', targetAmount: 500, currentAmount: 800 });

    const result = getRecommendations(owner.user.id, new Date('2026-08-16T12:00:00Z'));
    expect(result.savings.breakdown[0]).toEqual(expect.objectContaining({ remaining: 0, months: 60, monthly: 0 }));
    expect(result.savings.totalMonthlyRequired).toBe(0);
    expect(result.allocation.profile).toBe('Balanced');
  });
});
