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
});
