/// Centralized app configuration.
///
/// The backend base URL is resolved at BUILD time via --dart-define, not
/// hardcoded per-screen. This lets the same source compile correctly
/// against any backend location (local Docker, LAN, staging, prod) without
/// editing Dart files.
///
/// Default (`http://localhost:3000`) is correct for the standard
/// `docker-compose up` setup, since the backend container's port is
/// published to the host the browser is running on.
///
/// To override, pass a build arg, e.g.:
///   flutter build web --dart-define=API_BASE_URL=http://my-server:3000
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
