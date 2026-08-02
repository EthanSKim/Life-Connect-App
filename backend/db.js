const { Pool } = require('pg');

// Single shared connection pool, reused by every route module.
//
// Two ways to configure this, chosen automatically:
// - DATABASE_URL set (e.g. Neon, or any hosted Postgres): connect via that
//   single connection string, with SSL required - hosted providers reject
//   plain connections. Use Neon's DIRECT (non-pooled) connection string here,
//   not the "-pooler" one: this app uses pg_advisory_xact_lock inside
//   multi-statement transactions (reservation booking, etc.), which needs a
//   real session-scoped connection. Neon/Supabase's pooled connection
//   strings default to transaction-mode pooling, which silently breaks
//   session-scoped advisory locks.
// - DATABASE_URL not set: fall back to the individual DB_* vars (local
//   docker-compose dev, unchanged from before, no SSL).
const pool = process.env.DATABASE_URL
  ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false },
    })
  : new Pool({
      user: process.env.DB_USER || 'postgres',
      host: process.env.DB_HOST || 'localhost',
      database: process.env.DB_NAME || 'church_db',
      password: process.env.DB_PASSWORD || 'password',
      port: process.env.DB_PORT || 5432,
    });

module.exports = pool;
