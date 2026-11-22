const express = require('express');
const cors = require('cors');

/**
 * Builds the Express app. The data layer is injected so tests can use a fake.
 * `repo` must implement: listProducts(), ping().
 */
function createApp({ repo, version = 'dev' }) {
  const app = express();
  app.use(cors());
  app.use(express.json());

  // Liveness + dependency check used by deploy health checks.
  app.get('/health', async (_req, res) => {
    try {
      await repo.ping();
      res.json({ status: 'ok', db: 'up', version });
    } catch (_err) {
      res.status(503).json({ status: 'error', db: 'down', version });
    }
  });

  app.get('/api/version', (_req, res) => res.json({ version }));

  app.get('/api/products', async (_req, res) => {
    try {
      res.json(await repo.listProducts());
    } catch (_err) {
      res.status(500).json({ error: 'failed to load products' });
    }
  });

  app.use((_req, res) => res.status(404).json({ error: 'not found' }));
  return app;
}

module.exports = { createApp };
