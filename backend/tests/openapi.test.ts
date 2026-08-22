import request from 'supertest';
import app from '../src/app';

describe('OpenAPI contract', () => {
  test('serves a complete public contract for every API route', async () => {
    const response = await request(app).get('/openapi.json');
    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body.openapi).toBe('3.1.0');

    const operations = Object.values(response.body.paths)
      .flatMap((path: any) => Object.entries(path))
      .filter(([method]) => ['get', 'post', 'put', 'patch', 'delete'].includes(method));
    expect(operations).toHaveLength(29);
    expect(new Set(operations.map(([, operation]: any) => operation.operationId)).size)
      .toBe(29);

    expect(response.body.paths['/api/auth/me'].delete.operationId)
      .toBe('deleteCurrentUser');

    expect(response.body.paths['/api/auth/register'].post.security).toBeUndefined();
    expect(response.body.paths['/api/auth/register'].post.responses['429'].description)
      .toContain('rate limit');
    expect(response.body.paths['/api/auth/login'].post.responses['429'].description)
      .toContain('rate limit');
    expect(response.body.paths['/api/goals'].get.security).toEqual([{ bearerAuth: [] }]);
    expect(response.body.paths['/api/v1/recommendations'].get.security)
      .toEqual([{ bearerAuth: [] }]);
    expect(response.body.paths['/api/v1/portfolio'].get.security)
      .toEqual([{ bearerAuth: [] }]);
    expect(response.body.paths['/api/v1/portfolio/export.csv'].get.operationId)
      .toBe('exportPortfolioCsv');
    expect(response.body.paths['/api/v1/decision-reports'].post.responses['503'])
      .toBeDefined();
    expect(response.body.components.securitySchemes.bearerAuth.scheme).toBe('bearer');
  });
});
