// Wraps an async route handler so a thrown/rejected error is forwarded to
// Express's error-handling middleware (errorHandler.js) instead of needing
// a try/catch + res.status(500) duplicated in every single route. Routes
// still use try/catch locally when they need to do something on failure
// (e.g. ROLLBACK a transaction) - they just rethrow afterward instead of
// formatting their own response.
module.exports = function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
