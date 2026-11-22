const { Pool } = require('pg');

function createRepo(config) {
  const pool = new Pool(config);

  return {
    async init() {
      await pool.query(`CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        price_cents INTEGER NOT NULL CHECK (price_cents >= 0)
      )`);
      const { rows } = await pool.query('SELECT COUNT(*)::int AS n FROM products');
      if (rows[0].n === 0) {
        await pool.query(
          `INSERT INTO products (name, price_cents) VALUES
           ('Nest Mug', 1200), ('Nest Hoodie', 4500), ('Nest Sticker Pack', 500)`
        );
      }
    },
    async ping() {
      await pool.query('SELECT 1');
    },
    async listProducts() {
      const { rows } = await pool.query(
        'SELECT id, name, price_cents FROM products ORDER BY id'
      );
      return rows;
    },
  };
}

module.exports = { createRepo };
