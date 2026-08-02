const { Pool } = require('pg');

// Single shared connection pool, reused by every route module. Replaces the
// original unused db.js, which checked out a client via pool.connect() just
// to log a message and never released it back - a connection leak on every
// boot. Also matches index.js's existing fallback defaults so behavior
// doesn't change for anyone running without every DB_* var set.
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'church_db',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
});

module.exports = pool;
