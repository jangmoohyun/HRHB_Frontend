import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/kakao_auth_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

enum SessionDestination {
  login,
  familySelect,
  home,
}

class SessionBootstrap {
  SessionBootstrap({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    KakaoAuthService? kakaoAuthService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _kakaoAuthService = kakaoAuthService ?? KakaoAuthService();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final KakaoAuthService _kakaoAuthService;

  Future<SessionDestination> resolve() async {
    final access = await _tokenStorage.readAccessToken();
    if (access != null && access.isNotEmpty) {
      try {
        final me = await _apiClient.fetchMe(access);
        return await _finish(
          me.familyId,
          accessToken: access,
          isFamilyCreator: me.isFamilyCreator,
        );
      } catch (_) {
        // Access may be expired — try refresh below.
      }
    }

    final refreshed = await _tryRefreshSession();
    if (refreshed != null) {
      final accessToken = await _tokenStorage.readAccessToken();
      return _finish(
        refreshed.familyId,
        accessToken: accessToken,
        isFamilyCreator: refreshed.isFamilyCreator,
      );
    }

    // Kakao SDK still has a token → try silent re-login.
    // Soft-deleted accounts are NOT restored here (restoreDeletedAccount=false).
    try {
      if (await AuthApi.instance.hasToken()) {
        final result = await _kakaoAuthService.loginWithExistingKakaoToken();
        final accessToken = await _tokenStorage.readAccessToken();
        return await _finish(
          result.familyId,
          accessToken: accessToken,
          isFamilyCreator: result.isFamilyCreator,
        );
      }
    } on ApiException catch (error) {
      await _tokenStorage.clear();
      if (error.code == 'ACCOUNT_SCHEDULED_FOR_DELETION' ||
          error.message.contains('scheduled for deletion')) {
        return SessionDestination.login;
      }
    } catch (_) {
      await _tokenStorage.clear();
    }

    return SessionDestination.login;
  }

  /// Fetches latest family name/role/creator flag and writes to local storage.
  Future<void> syncFamilyProfile({
    String? accessToken,
    bool? isFamilyCreator,
  }) async {
    final token = accessToken ?? await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return;

    Future<void> persist(String authedToken, bool creator) async {
      final family = await _apiClient.fetchMyFamily(authedToken);
      FamilyMemberResult? me;
      for (final member in family.members) {
        if (member.isMe) {
          me = member;
          break;
        }
      }
      await _tokenStorage.saveFamilyProfile(
        familyName: family.familyName,
        familyCode: family.inviteCode,
        myRoleLabel: me?.roleLabel ?? '',
        isFamilyCreator: creator,
      );
      await _tokenStorage.saveFamilyMembers(family.members);
    }

    try {
      final creator = isFamilyCreator ??
          (await _apiClient.fetchMe(token)).isFamilyCreator ??
          false;
      await persist(token, creator);
    } on ApiException catch (error) {
      if (!error.message.contains('(401)')) rethrow;
      final refreshed = await _tryRefreshTokensOnly();
      if (refreshed == null) rethrow;
      final creator = isFamilyCreator ??
          (await _apiClient.fetchMe(refreshed)).isFamilyCreator ??
          false;
      await persist(refreshed, creator);
    }
  }

  Future<MeResult?> _tryRefreshSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    final userId = await _tokenStorage.readUserId();
    if (refreshToken == null || refreshToken.isEmpty || userId == null) {
      return null;
    }

    try {
      final pair = await _apiClient.refresh(refreshToken);
      await _tokenStorage.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return await _apiClient.fetchMe(pair.accessToken);
    } catch (_) {
      await _tokenStorage.clear();
      return null;
    }
  }

  Future<String?> _tryRefreshTokensOnly() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    final userId = await _tokenStorage.readUserId();
    if (refreshToken == null || refreshToken.isEmpty || userId == null) {
      return null;
    }
    try {
      final pair = await _apiClient.refresh(refreshToken);
      await _tokenStorage.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return pair.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<SessionDestination> _finish(
    int? familyId, {
    required String? accessToken,
    bool? isFamilyCreator,
  }) async {
    if (familyId == null) {
      await _tokenStorage.clearFamilyProfile();
      return SessionDestination.familySelect;
    }

    try {
      await syncFamilyProfile(
        accessToken: accessToken,
        isFamilyCreator: isFamilyCreator,
      );
    } catch (_) {
      // Keep previous cached profile if sync fails; still enter home.
    }
    return SessionDestination.home;
  }
}

class MeResult {
  const MeResult({
    required this.userId,
    this.familyId,
    this.isFamilyCreator,
    this.provider,
  });

  final int userId;
  final int? familyId;
  final bool? isFamilyCreator;
  final String? provider;

  factory MeResult.fromJson(Map<String, dynamic> json) {
    return MeResult(
      userId: json['userId'] as int,
      familyId: json['familyId'] as int?,
      isFamilyCreator: json['isFamilyCreator'] as bool?,
      provider: json['provider'] as String?,
    );
  }
}
