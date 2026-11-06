import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrhb_frontend/services/api_client.dart';

class FamilyProfile {
  const FamilyProfile({
    required this.familyName,
    required this.familyCode,
    required this.myRoleLabel,
    required this.isFamilyCreator,
  });

  final String familyName;
  final String familyCode;
  final String myRoleLabel;
  final bool isFamilyCreator;
}

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'hrhb_access_token';
  static const _refreshTokenKey = 'hrhb_refresh_token';
  static const _userIdKey = 'hrhb_user_id';
  static const _familyNameKey = 'hrhb_family_name';
  static const _familyCodeKey = 'hrhb_family_code';
  static const _myRoleKey = 'hrhb_my_role';
  static const _isFamilyCreatorKey = 'hrhb_is_family_creator';
  static const _familyMembersKey = 'hrhb_family_members';
  static const _tempPopupShownDateKey = 'hrhb_temp_popup_shown_date';
  static const _fcmTokenKey = 'hrhb_fcm_token';
  static const _appGuideSeenKey = 'hrhb_app_guide_seen';
  static const _largeTextEnabledKey = 'hrhb_large_text_enabled';

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  Future<void> saveFamilyProfile({
    required String familyName,
    required String familyCode,
    required String myRoleLabel,
    required bool isFamilyCreator,
  }) async {
    await _storage.write(key: _familyNameKey, value: familyName);
    await _storage.write(key: _familyCodeKey, value: familyCode);
    await _storage.write(key: _myRoleKey, value: myRoleLabel);
    await _storage.write(
      key: _isFamilyCreatorKey,
      value: isFamilyCreator ? 'true' : 'false',
    );
  }

  Future<void> saveFamilyMembers(List<FamilyMemberResult> members) async {
    final encoded = jsonEncode(members.map((m) => m.toJson()).toList());
    await _storage.write(key: _familyMembersKey, value: encoded);
  }

  Future<List<FamilyMemberResult>> readFamilyMembers() async {
    final raw = await _storage.read(key: _familyMembersKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FamilyMemberResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<int?> readUserId() async {
    final raw = await _storage.read(key: _userIdKey);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<FamilyProfile?> readFamilyProfile() async {
    final familyName = await _storage.read(key: _familyNameKey);
    if (familyName == null || familyName.isEmpty) {
      return null;
    }
    final creatorRaw = await _storage.read(key: _isFamilyCreatorKey);
    return FamilyProfile(
      familyName: familyName,
      familyCode: await _storage.read(key: _familyCodeKey) ?? '',
      myRoleLabel: await _storage.read(key: _myRoleKey) ?? '',
      isFamilyCreator: creatorRaw == 'true',
    );
  }

  Future<void> clearFamilyProfile() async {
    await _storage.delete(key: _familyNameKey);
    await _storage.delete(key: _familyCodeKey);
    await _storage.delete(key: _myRoleKey);
    await _storage.delete(key: _isFamilyCreatorKey);
    await _storage.delete(key: _familyMembersKey);
  }

  /// Local calendar date `yyyy-MM-dd` when temperature-change popup was last shown.
  Future<String?> readTempPopupShownDate() =>
      _storage.read(key: _tempPopupShownDateKey);

  Future<void> saveTempPopupShownDate(String yyyyMmDd) async {
    await _storage.write(key: _tempPopupShownDateKey, value: yyyyMmDd);
  }

  Future<String?> readFcmToken() => _storage.read(key: _fcmTokenKey);

  Future<void> saveFcmToken(String token) async {
    await _storage.write(key: _fcmTokenKey, value: token);
  }

  Future<void> clearFcmToken() async {
    await _storage.delete(key: _fcmTokenKey);
  }

  /// 앱 가이드를 이미 봤는지.
  /// SharedPreferences에 저장 — 앱 삭제 시 초기화됨.
  /// (예전 Keychain 값은 iOS에서 재설치 후에도 남아 가이드가 안 뜨던 문제가 있어 이전함)
  Future<bool> readAppGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    // 예전 secure-storage 키는 더 이상 쓰지 않음 (재설치 후에도 남는 문제).
    try {
      await _storage.delete(key: _appGuideSeenKey);
    } catch (_) {}
    return prefs.getBool(_appGuideSeenKey) ?? false;
  }

  Future<void> saveAppGuideSeen(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appGuideSeenKey, seen);
    try {
      await _storage.delete(key: _appGuideSeenKey);
    } catch (_) {}
  }

  Future<bool> readLargeTextEnabled() async {
    final raw = await _storage.read(key: _largeTextEnabledKey);
    return raw == 'true';
  }

  Future<void> saveLargeTextEnabled(bool enabled) async {
    await _storage.write(
      key: _largeTextEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _tempPopupShownDateKey);
    await _storage.delete(key: _fcmTokenKey);
    await clearFamilyProfile();
  }
}
