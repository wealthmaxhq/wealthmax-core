import request from 'supertest';
import app from '../src/app';

describe('HTTP security policy', () => {
  test('sets restrictive headers without exposing the framework', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.headers['x-powered-by']).toBeUndefined();
    expect(response.headers['content-security-policy']).toContain("default-src 'none'");
    expect(response.headers['content-security-policy']).toContain("frame-ancestors 'none'");
    expect(response.headers['cross-origin-resource-policy']).toBe('same-origin');
    expect(response.headers['permissions-policy']).toBe(
      'camera=(), geolocation=(), microphone=()',
    );
    expect(response.headers['referrer-policy']).toBe('no-referrer');
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('DENY');
  });

  test('prevents authenticated API responses from being cached', async () => {
    const response = await request(app).get('/api/auth/me');
    expect(response.status).toBe(401);
    expect(response.headers['cache-control']).toBe('no-store');
  });

  test('rejects malformed JSON with a stable public error', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email":');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Request body must contain valid JSON.' });
  });

  test('rejects JSON bodies larger than 64 KiB', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'large-body@example.com',
        password: 'password123',
        padding: 'x'.repeat(65 * 1024),
      });

    expect(response.status).toBe(413);
    expect(response.body).toEqual({ error: 'Request body is too large.' });
  });
});
