// Centralized error handler. Every route that throws (either directly, or
// via asyncHandler catching a rejected promise) ends up here instead of
// each of ~25 routes formatting its own 500 response. Includes both
// `error` and `message` keys since existing frontend call sites read
// either one depending on which endpoint they're calling - this keeps
// both working without having to touch every call site.

// Common Postgres error codes worth translating into a clean, non-leaky
// response instead of falling through to a generic 500 with the raw driver
// message. Found via testing: routes that do `$1::BIGINT` on a route param
// (20+ call sites across the app) throw a raw "invalid input syntax for
// type bigint" Postgres error on non-numeric input - mapping this once here
// protects every current AND future route that does the same cast, instead
// of needing input validation added to each call site individually.
const PG_ERROR_MAP = {
  '22P02': { status: 400, message: '요청 형식이 올바르지 않습니다.' },      // invalid_text_representation (bad ::BIGINT/::INTEGER cast, etc.)
  '22007': { status: 400, message: '날짜/시간 형식이 올바르지 않습니다.' }, // invalid_datetime_format
  '23505': { status: 409, message: '이미 존재하는 데이터입니다.' },         // unique_violation
  '23503': { status: 400, message: '연결된 데이터를 찾을 수 없습니다.' },   // foreign_key_violation
  '23514': { status: 400, message: '허용되지 않는 값입니다.' },            // check_violation
};

module.exports = function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  console.error(`[${req.method} ${req.originalUrl}]`, err);

  const pgMapped = err.code && PG_ERROR_MAP[err.code];
  const status = pgMapped?.status || err.status || 500;
  const message = pgMapped?.message || err.message || '서버 오류가 발생했습니다.';
  res.status(status).json({ success: false, error: message, message });
};
