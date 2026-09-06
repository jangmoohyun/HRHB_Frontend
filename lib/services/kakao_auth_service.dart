import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

class KakaoAuthService {
  KakaoAuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// Explicit Kakao login from the login screen. Restores soft-deleted accounts.
  Future<AuthResult> login() async {
    final oauthToken = await _loginWithKakao();
    return _exchangeAndStore(
      oauthToken.accessToken,
      restoreDeletedAccount: true,
    );
  }

  /// Silent session bootstrap. Does NOT restore soft-deleted accounts.
  Future<AuthResult> loginWithExistingKakaoToken() async {
    final token = await TokenManagerProvider.instance.manager.getToken();
    final accessToken = token?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('No Kakao access token');
    }
    return _exchangeAndStore(accessToken, restoreDeletedAccount: false);
  }

  Future<AuthResult> _exchangeAndStore(
    String kakaoAccessToken, {
    required bool restoreDeletedAccount,
  }) async {
    final result = await _apiClient.loginWithKakao(
      kakaoAccessToken,
      restoreDeletedAccount: restoreDeletedAccount,
    );
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
    );
    return result;
  }

  Future<OAuthToken> _loginWithKakao() async {
    final keyHash = await KakaoSdk.origin;
    debugPrint('kakao keyHash: $keyHash');

    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        debugPrint('kakao talk login failed: $error');
      }
    }
    return UserApi.instance.loginWithKakaoAccount();
  }
}
