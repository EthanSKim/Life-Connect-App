// Centralized error handler. Every route that throws (either directly, or
// via asyncHandler catching a rejected promise) ends up here instead of
// each of ~25 routes formatting its own 500 response. Includes both
// `error` and `message` keys since existing frontend call sites read
// either one depending on which endpoint they're calling - this keeps
// both working without having to touch every call site.
module.exports = function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  console.error(`[${req.method} ${req.originalUrl}]`, err);

  const status = err.status || 500;
  const message = err.message || '서버 오류가 발생했습니다.';
  res.status(status).json({ success: false, error: message, message });
};
