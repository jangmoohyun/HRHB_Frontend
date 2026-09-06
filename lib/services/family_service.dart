import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

class FamilyService {
  FamilyService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  static const roleLabels = {
    '아빠': 'FATHER',
    '엄마': 'MOTHER',
    '아들': 'SON',
    '딸': 'DAUGHTER',
  };

  static const birthOrderLabels = {
    '첫째': 1,
    '둘째': 2,
    '셋째': 3,
    '넷째': 4,
    '다섯째': 5,
  };

  Future<CreateFamilyResult> create({
    required String familyName,
    required String roleLabel,
    String? birthOrderLabel,
  }) async {
    final accessToken = await _requireAccessToken();
    final parsed = _parseRole(roleLabel, birthOrderLabel);

    late final CreateFamilyResult result;
    try {
      result = await _apiClient.createFamily(
        accessToken: accessToken,
        name: familyName,
        role: parsed.role,
        birthOrder: parsed.birthOrder,
      );
    } on ApiException catch (error) {
      result = await _retryAfterRefresh(
        error,
        (token) => _apiClient.createFamily(
          accessToken: token,
          name: familyName,
          role: parsed.role,
          birthOrder: parsed.birthOrder,
        ),
      );
    }

    await _tokenStorage.saveFamilyProfile(
      familyName: result.familyName,
      familyCode: result.inviteCode,
      myRoleLabel: FamilyMemberResult.labelFor(
        role: result.role,
        birthOrder: result.birthOrder,
      ),
      isFamilyCreator: true,
    );
    return result;
  }

  Future<CreateFamilyResult> join({
    required String inviteCode,
    required String roleLabel,
    String? birthOrderLabel,
  }) async {
    final accessToken = await _requireAccessToken();
    final parsed = _parseRole(roleLabel, birthOrderLabel);

    late final CreateFamilyResult result;
    try {
      result = await _apiClient.joinFamily(
        accessToken: accessToken,
        inviteCode: inviteCode.trim().toUpperCase(),
        role: parsed.role,
        birthOrder: parsed.birthOrder,
      );
    } on ApiException catch (error) {
      result = await _retryAfterRefresh(
        error,
        (token) => _apiClient.joinFamily(
          accessToken: token,
          inviteCode: inviteCode.trim().toUpperCase(),
          role: parsed.role,
          birthOrder: parsed.birthOrder,
        ),
      );
    }

    await _tokenStorage.saveFamilyProfile(
      familyName: result.familyName,
      familyCode: result.inviteCode,
      myRoleLabel: FamilyMemberResult.labelFor(
        role: result.role,
        birthOrder: result.birthOrder,
      ),
      isFamilyCreator: false,
    );
    return result;
  }

  Future<FamilyProfile> updateProfile({
    required String familyName,
    required String roleLabel,
    String? birthOrderLabel,
    required bool isFamilyCreator,
  }) async {
    final accessToken = await _requireAccessToken();
    final parsed = _parseRole(roleLabel, birthOrderLabel);
    final current = await _tokenStorage.readFamilyProfile();

    var nextName = current?.familyName ?? familyName;
    if (isFamilyCreator) {
      try {
        await _apiClient.updateFamilyName(
          accessToken: accessToken,
          name: familyName,
        );
      } on ApiException catch (error) {
        await _retryAfterRefresh(
          error,
          (token) => _apiClient.updateFamilyName(
            accessToken: token,
            name: familyName,
          ),
        );
      }
      nextName = familyName.trim();
    }

    late final ({String role, int? birthOrder}) roleResult;
    try {
      roleResult = await _apiClient.updateMyRole(
        accessToken: accessToken,
        role: parsed.role,
        birthOrder: parsed.birthOrder,
      );
    } on ApiException catch (error) {
      roleResult = await _retryAfterRefresh(
        error,
        (token) => _apiClient.updateMyRole(
          accessToken: token,
          role: parsed.role,
          birthOrder: parsed.birthOrder,
        ),
      );
    }

    final profile = FamilyProfile(
      familyName: nextName,
      familyCode: current?.familyCode ?? '',
      myRoleLabel: FamilyMemberResult.labelFor(
        role: roleResult.role,
        birthOrder: roleResult.birthOrder,
      ),
      isFamilyCreator: isFamilyCreator,
    );
    await _tokenStorage.saveFamilyProfile(
      familyName: profile.familyName,
      familyCode: profile.familyCode,
      myRoleLabel: profile.myRoleLabel,
      isFamilyCreator: profile.isFamilyCreator,
    );
    return profile;
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    return accessToken;
  }

  ({String role, int? birthOrder}) _parseRole(
    String roleLabel,
    String? birthOrderLabel,
  ) {
    final role = roleLabels[roleLabel];
    if (role == null) {
      throw ArgumentError('Invalid role: $roleLabel');
    }

    int? birthOrder;
    if (role == 'SON' || role == 'DAUGHTER') {
      birthOrder = _parseBirthOrder(birthOrderLabel);
      if (birthOrder == null) {
        throw ArgumentError('birth order is required for $roleLabel');
      }
    }
    return (role: role, birthOrder: birthOrder);
  }

  Future<T> _retryAfterRefresh<T>(
    ApiException error,
    Future<T> Function(String accessToken) action,
  ) async {
    if (!error.message.contains('(401)')) {
      throw error;
    }
    final refreshToken = await _tokenStorage.readRefreshToken();
    final userId = await _tokenStorage.readUserId();
    if (refreshToken == null || userId == null) {
      throw error;
    }

    final pair = await _apiClient.refresh(refreshToken);
    await _tokenStorage.saveSession(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      userId: userId,
    );
    return action(pair.accessToken);
  }

  int? _parseBirthOrder(String? label) {
    if (label == null || label.isEmpty) return null;
    for (final entry in birthOrderLabels.entries) {
      if (label.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
