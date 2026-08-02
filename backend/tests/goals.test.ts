import request from 'supertest';
import app from '../src/app';
import db from '../src/db';

beforeEach(() => {
  db.prepare('DELETE FROM goals').run();
  db.prepare('DELETE FROM users').run();
});

describe('Goals E2E', () => {
  test('create, list, get, update, delete goal', async () => {
    const email = 'gtest@example.com';
    const password = 'pass1234';

    // Register
    const reg = await request(app).post('/api/auth/register').send({ email, password, name: 'GoalUser' });
    expect(reg.status).toBe(200);
    const token = reg.body.token;

    // Create goal
    const create = await request(app).post('/api/goals').set('Authorization', `Bearer ${token}`).send({ title: 'Buy a car', targetAmount: 10000 });
    expect(create.status).toBe(201);
    const goal = create.body.goal;
    expect(goal.title).toBe('Buy a car');

    // List goals
    const list = await request(app).get('/api/goals').set('Authorization', `Bearer ${token}`);
    expect(list.status).toBe(200);
    expect(Array.isArray(list.body.goals)).toBe(true);
    expect(list.body.goals.length).toBe(1);

    // Get goal
    const get = await request(app).get(`/api/goals/${goal.id}`).set('Authorization', `Bearer ${token}`);
    expect(get.status).toBe(200);
    expect(get.body.goal.id).toBe(goal.id);

    // Update
    const upd = await request(app).put(`/api/goals/${goal.id}`).set('Authorization', `Bearer ${token}`).send({ currentAmount: 500 });
    expect(upd.status).toBe(200);
    expect(upd.body.goal.currentAmount).toBe(500);

    const invalid = await request(app)
      .put(`/api/goals/${goal.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ targetAmount: -1 });
    expect(invalid.status).toBe(400);

    const other = await request(app).post('/api/auth/register').send({
      email: 'other-goals@example.com',
      password,
    });
    const hiddenUpdate = await request(app)
      .put(`/api/goals/${goal.id}`)
      .set('Authorization', `Bearer ${other.body.token}`)
      .send({ currentAmount: 9999 });
    expect(hiddenUpdate.status).toBe(404);

    const unchanged = await request(app)
      .get(`/api/goals/${goal.id}`)
      .set('Authorization', `Bearer ${token}`);
    expect(unchanged.body.goal.currentAmount).toBe(500);

    // Delete
    const del = await request(app).delete(`/api/goals/${goal.id}`).set('Authorization', `Bearer ${token}`);
    expect(del.status).toBe(204);

    // Ensure gone
    const list2 = await request(app).get('/api/goals').set('Authorization', `Bearer ${token}`);
    expect(list2.status).toBe(200);
    expect(list2.body.goals.length).toBe(0);
  }, 10000);
});
