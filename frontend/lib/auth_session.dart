/// Holds the current login session in memory for the lifetime of the app.
///
/// This is a minimal placeholder to unblock Phase 4 (reservations), which
/// needs *some* way to attach the JWT issued at login to API requests.
/// Phase 5 will build this out properly (secure/persistent storage, logout,
/// and wiring it through the remaining screens - profile, admin, PIN
/// lookup - that don't use it yet).
class AuthSession {
  static String? token;

  static Map<String, String> get authHeaders => {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };
}
