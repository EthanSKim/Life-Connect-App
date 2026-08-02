const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || '';
const JWT_EXPIRES_IN = '12h';

if (!JWT_SECRET) {
  console.warn('[auth] JWT_SECRET is not set - login tokens will fail to sign/verify.');
}

// membership_role is free-text in the DB (e.g. 'Admin', 'Member', 'Pastor').
// Only the exact value 'Admin' grants admin API access - keep this in sync
// with whatever value the admin-creation flow actually sets.
function roleFor(membershipRole) {
  return membershipRole === 'Admin' ? 'admin' : 'member';
}

function signToken({ person_id, membership_role }) {
  return jwt.sign(
    { person_id, role: roleFor(membership_role) },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

// Verifies the request's auth token and attaches req.user. Accepts the
// token either as a standard Authorization: Bearer header, or as a ?token=
// query param - the latter exists only for direct-link endpoints (like the
// Apple Wallet pass download) that get opened directly by the OS/browser
// and can't attach custom headers.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : (req.query.token || null);

  if (!token) {
    return res.status(401).json({ success: false, message: '로그인이 필요합니다.' });
  }

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: '세션이 만료되었거나 유효하지 않습니다. 다시 로그인해주세요.' });
  }
}

function requireAdmin(req, res, next) {
  requireAuth(req, res, () => {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '관리자 권한이 필요합니다.' });
    }
    next();
  });
}

// Allows the request through if the caller IS the person the route is about,
// OR is an admin. `idParam` is the route param holding the target person_id
// (e.g. 'id' for /api/members/:id).
function requireSelfOrAdmin(idParam) {
  return (req, res, next) => {
    requireAuth(req, res, () => {
      const targetId = req.params[idParam];
      if (req.user.role === 'admin' || String(req.user.person_id) === String(targetId)) {
        return next();
      }
      return res.status(403).json({ success: false, message: '본인 정보만 접근할 수 있습니다.' });
    });
  };
}

module.exports = { signToken, requireAuth, requireAdmin, requireSelfOrAdmin, roleFor };
