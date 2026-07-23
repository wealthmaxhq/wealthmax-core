import request from 'supertest';
import app from '../src/app';
import db from '../src/db';

beforeEach(() => {
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
});
