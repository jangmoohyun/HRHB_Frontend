import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

class NotSignedInException implements Exception {
  const NotSignedInException();
  @override
  String toString() => '로그인이 필요해요.';
}

/// Runs an authenticated request, refreshing the access token once on 401.
///
/// The old screens each re-implemented this refresh-and-retry dance inline;
/// the VER2 screens go through here instead.
abstract final class AuthedCall {
  static final _api = ApiClient();
  static final _storage = TokenStorage();

  static Future<T> run<T>(Future<T> Function(String token) call) async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) throw const NotSignedInException();
    try {
      return await call(token);
    } on ApiException catch (e) {
      if (!_isUnauthorized(e)) rethrow;
      final refresh = await _storage.readRefreshToken();
      final userId = await _storage.readUserId();
      if (refresh == null || refresh.isEmpty || userId == null) rethrow;
      final pair = await _api.refresh(refresh);
      await _storage.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return await call(pair.accessToken);
    }
  }

  static bool _isUnauthorized(ApiException e) =>
      e.statusCode == 401 || e.message.contains('(401)');
}
