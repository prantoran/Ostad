const fs = require('fs');
const path = require('path');
const { createApp } = require('./app');
const { createRepo } = require('./db');

function readVersion() {
  try {
    return fs.readFileSync(path.join(__dirname, '..', 'VERSION'), 'utf8').trim();
  } catch (_e) {
    return process.env.GIT_SHA || 'dev';
  }
}

async function main() {
  const repo = createRepo({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });
  await repo.init();

  const port = Number(process.env.PORT || 3000);
  const app = createApp({ repo, version: readVersion() });
  app.listen(port, '127.0.0.1', () => console.log(`backend listening on ${port}`));
}

main().catch((err) => {
  console.error('fatal startup error:', err.message);
  process.exit(1);
});
