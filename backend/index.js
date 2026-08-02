const express = require('express');
const cors = require('cors');
const compression = require('compression');
require('dotenv').config();

const pool = require('./db');
const errorHandler = require('./middleware/errorHandler');
const asyncHandler = require('./middleware/asyncHandler');

// --- Fail fast on missing/invalid required config ---
// Previously ENCRYPTION_KEY/JWT_SECRET only logged a warning and kept
// running with broken crypto - better to refuse to start than to accept
// requests that will fail unpredictably later.
function validateEnv() {
  const problems = [];
  if (!process.env.JWT_SECRET) {
    problems.push('JWT_SECRET is not set');
  }
  if (!/^[0-9a-f]{64}$/i.test(process.env.ENCRYPTION_KEY || '')) {
    problems.push('ENCRYPTION_KEY must be a 64-character hex string (32 bytes)');
  }
  if (problems.length > 0) {
    console.error('[startup] Refusing to start due to invalid configuration:');
    problems.forEach(p => console.error(`  - ${p}`));
    process.exit(1);
  }
}
validateEnv();

const app = express();
app.use(cors());
app.use(compression()); // gzip JSON responses (member lists, etc.)
app.use(express.json());

// Docker/Compose healthcheck endpoint (checks DB connectivity too)
app.get('/health', asyncHandler(async (req, res) => {
  await pool.query('SELECT 1');
  res.status(200).json({ status: 'ok' });
}));

// --- Route modules ---
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/members', require('./routes/members.routes'));
app.use('/api/households', require('./routes/households.routes'));
app.use('/api/life-teams', require('./routes/lifeteams.routes'));
app.use('/api/attendance', require('./routes/attendance.routes'));
app.use('/api/notices', require('./routes/notices.routes'));
app.use('/api/metadata', require('./routes/metadata.routes'));
app.use('/api/facilities', require('./routes/facilities.routes'));
app.use('/api/reservations', require('./routes/reservations.routes'));
app.use('/api/wallet', require('./routes/wallet.routes'));

// Centralized error handler - must be registered last, after all routes.
app.use(errorHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
