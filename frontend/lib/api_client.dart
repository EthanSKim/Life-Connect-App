import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'auth_session.dart';

/// Thrown by [ApiClient] when a request completes but the server reports
/// failure (4xx/5xx), or when the request couldn't be made at all (timeout,
/// no connection). Carries the user-facing Korean message the backend
/// already provides, so screens can show it directly without re-parsing.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Centralizes what used to be duplicated in every screen: building the
/// URL, attaching AuthSession's headers, applying a timeout, decoding JSON,
/// and turning a non-2xx response into a catchable error with the server's
/// actual message. This is also what prevents the "forgot to attach the
/// auth header on this one call site" class of bug that came up repeatedly
/// while wiring auth through the app - there's now exactly one place that
/// attaches headers, not N.
class ApiClient {
  static const _timeout = Duration(seconds: 8);
  static String get _baseUrl => AppConfig.baseUrl;

  static Future<dynamic> get(String path) => _send('GET', path);

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  static Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      http.Response response;
      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: AuthSession.authHeaders, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: AuthSession.authHeaders, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: AuthSession.authHeaders).timeout(_timeout);
          break;
        default:
          response = await http.get(uri, headers: AuthSession.authHeaders).timeout(_timeout);
      }

      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      final message = (decoded is Map && (decoded['message'] ?? decoded['error']) != null)
          ? (decoded['message'] ?? decoded['error']).toString()
          : "요청을 처리하지 못했습니다. (${response.statusCode})";
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException("서버 연결에 실패했습니다. 네트워크 상태를 확인해주세요.");
    }
  }
}
