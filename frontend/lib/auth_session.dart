/// Holds the current login session in memory for the lifetime of the app.
class AuthSession {
  static String? token;

  static Map<String, String> get authHeaders => {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };
}
