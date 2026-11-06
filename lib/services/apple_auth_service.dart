import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

/// Result of native Apple Sign In (before our backend exchange).
class AppleSignInResult {
  const AppleSignInResult({
    required this.identityToken,
    required this.userIdentifier,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String identityToken;
  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;

  String? get fullName {
    final parts = [
      if (givenName != null && givenName!.trim().isNotEmpty) givenName!.trim(),
      if (familyName != null && familyName!.trim().isNotEmpty)
        familyName!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}

class AppleAuthService {
  AppleAuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// Explicit Apple login from the login screen. Restores soft-deleted accounts.
  Future<AuthResult> login() async {
    final apple = await _signInNative();
    return _exchangeAndStore(apple, restoreDeletedAccount: true);
  }

  Future<AppleSignInResult> _signInNative() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw StateError('이 기기에서는 Apple 로그인을 사용할 수 없습니다.');
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final identityToken = credential.identityToken;
    final userIdentifier = credential.userIdentifier;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple identityToken이 비어 있습니다.');
    }
    if (userIdentifier == null || userIdentifier.isEmpty) {
      throw StateError('Apple userIdentifier가 비어 있습니다.');
    }

    debugPrint(
      'apple sign-in ok: user=$userIdentifier '
      'email=${credential.email} '
      'tokenLen=${identityToken.length}',
    );

    return AppleSignInResult(
      identityToken: identityToken,
      userIdentifier: userIdentifier,
      email: credential.email,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  Future<AuthResult> _exchangeAndStore(
    AppleSignInResult apple, {
    required bool restoreDeletedAccount,
  }) async {
    final result = await _apiClient.loginWithApple(
      identityToken: apple.identityToken,
      userIdentifier: apple.userIdentifier,
      email: apple.email,
      fullName: apple.fullName,
      restoreDeletedAccount: restoreDeletedAccount,
    );
    await _tokenStorage.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId,
    );
    return result;
  }
}
