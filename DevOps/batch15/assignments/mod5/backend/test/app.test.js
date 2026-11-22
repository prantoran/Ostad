const request = require('supertest');
const { createApp } = require('../src/app');

const products = [
  { id: 1, name: 'Nest Mug', price_cents: 1200 },
  { id: 2, name: 'Nest Hoodie', price_cents: 4500 },
];

const healthyRepo = {
  ping: async () => {},
  listProducts: async () => products,
};
const brokenRepo = {
  ping: async () => { throw new Error('db down'); },
  listProducts: async () => { throw new Error('db down'); },
};

describe('backend API', () => {
  test('GET /health returns ok and version when db is up', async () => {
    const res = await request(createApp({ repo: healthyRepo, version: 'abc123' })).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up', version: 'abc123' });
  });

  test('GET /health returns 503 when db is down', async () => {
    const res = await request(createApp({ repo: brokenRepo })).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
  });

  test('GET /api/products returns the product list', async () => {
    const res = await request(createApp({ repo: healthyRepo })).get('/api/products');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    expect(res.body[0].name).toBe('Nest Mug');
  });

  test('GET /api/products returns 500 on repository failure', async () => {
    const res = await request(createApp({ repo: brokenRepo })).get('/api/products');
    expect(res.status).toBe(500);
  });

  test('GET /api/version exposes the deployed version', async () => {
    const res = await request(createApp({ repo: healthyRepo, version: 'v9' })).get('/api/version');
    expect(res.body).toEqual({ version: 'v9' });
  });

  test('unknown route returns 404', async () => {
    const res = await request(createApp({ repo: healthyRepo })).get('/nope');
    expect(res.status).toBe(404);
  });
});
