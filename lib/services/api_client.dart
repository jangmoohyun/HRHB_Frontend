import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hrhb_frontend/config/env.dart';
import 'package:hrhb_frontend/services/session_bootstrap.dart';

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.familyId,
    required this.isNewUser,
    this.isFamilyCreator,
    this.restored = false,
  });

  final String accessToken;
  final String refreshToken;
  final int userId;
  final int? familyId;
  final bool isNewUser;
  final bool? isFamilyCreator;
  final bool restored;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: json['userId'] as int,
      familyId: json['familyId'] as int?,
      isNewUser: json['isNewUser'] as bool? ?? false,
      isFamilyCreator: json['isFamilyCreator'] as bool?,
      restored: json['restored'] as bool? ?? false,
    );
  }
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<AuthResult> loginWithKakao(
    String kakaoAccessToken, {
    bool restoreDeletedAccount = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/kakao');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'accessToken': kakaoAccessToken,
        'restoreDeletedAccount': restoreDeletedAccount,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult.fromJson(body);
  }

  Future<SendEmailCodeResult> sendEmailSignupCode(String email) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/send-code');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SendEmailCodeResult.fromJson(body);
  }

  Future<EmailSignupStatusResult> checkEmailSignupStatus(String email) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/signup-status');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return EmailSignupStatusResult.fromJson(body);
  }

  Future<void> restoreEmailAccount(String email) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/restore');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
  }

  Future<VerifyEmailCodeResult> verifyEmailSignupCode({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/verify-code');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Verify email code failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return VerifyEmailCodeResult.fromJson(body);
  }

  Future<void> registerEmail({
    required String signupToken,
    required String password,
    required String passwordConfirm,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/register');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'signupToken': signupToken,
        'password': password,
        'passwordConfirm': passwordConfirm,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Email register failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/email/login');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Email login failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult.fromJson(body);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final uri = Uri.parse('$_baseUrl/api/auth/refresh');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Token refresh failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TokenPair.fromJson(body);
  }

  Future<MeResult> fetchMe(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/auth/me');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Session check failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MeResult.fromJson(body);
  }

  Future<void> registerDeviceToken({
    required String accessToken,
    required String token,
    required String platform,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/me/device-tokens');
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'token': token,
        'platform': platform,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Register device token failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteDeviceToken({
    required String accessToken,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/me/device-tokens');
    final response = await _client.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Delete device token failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> sendTestPush(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/me/push/test');
    final response = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Test push failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteAccount(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/auth/account');
    final response = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Delete account failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<CreateFamilyResult> createFamily({
    required String accessToken,
    required String name,
    required String role,
    int? birthOrder,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'name': name,
        'role': role,
        'birthOrder': ?birthOrder,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Create family failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateFamilyResult.fromJson(body);
  }

  Future<CreateFamilyResult> joinFamily({
    required String accessToken,
    required String inviteCode,
    required String role,
    int? birthOrder,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/join');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'inviteCode': inviteCode,
        'role': role,
        'birthOrder': ?birthOrder,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateFamilyResult.fromJson(body);
  }

  Future<MyFamilyResult> fetchMyFamily(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/families/me');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Fetch family failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MyFamilyResult.fromJson(body);
  }

  Future<void> updateFamilyName({
    required String accessToken,
    required String name,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Update family name failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<({String role, int? birthOrder})> updateMyRole({
    required String accessToken,
    required String role,
    int? birthOrder,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/role');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'role': role,
        'birthOrder': ?birthOrder,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Update role failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      role: body['role'] as String? ?? role,
      birthOrder: body['birthOrder'] as int?,
    );
  }

  Future<TodayDailyQuestionResult> fetchTodayDailyQuestion(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/daily-question/today');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TodayDailyQuestionResult.fromJson(body);
  }

  Future<MonthDailyQuestionsResult> fetchMonthDailyQuestions({
    required String accessToken,
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/daily-question').replace(
      queryParameters: {
        'year': '$year',
        'month': '$month',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MonthDailyQuestionsResult.fromJson(body);
  }

  Future<DailyAnswerListResult> fetchDailyAnswers({
    required String accessToken,
    required int dailyQuestionId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/families/me/daily-question/$dailyQuestionId/answers',
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DailyAnswerListResult.fromJson(body);
  }

  Future<PhotoUploadUrlResult> createAnswerPhotoUploadUrl({
    required String accessToken,
    required int dailyQuestionId,
    required String contentType,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/families/me/daily-question/$dailyQuestionId/answers/photo-upload-url',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'contentType': contentType}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PhotoUploadUrlResult.fromJson(body);
  }

  Future<void> uploadBytesToPresignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final response = await _client.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'S3 upload failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<DailyAnswerItemResult> saveDailyAnswer({
    required String accessToken,
    required int dailyQuestionId,
    required String content,
    String? imageKey,
    bool removeImage = false,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/families/me/daily-question/$dailyQuestionId/answers',
    );
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'content': content,
        'imageKey': ?imageKey,
        'removeImage': removeImage,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DailyAnswerItemResult.fromJson(body);
  }

  Future<GalleryAnswerPhotosResult> fetchGalleryAnswerPhotos({
    required String accessToken,
    int page = 0,
    int size = 21,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/gallery/answer-photos').replace(
      queryParameters: {
        'page': '$page',
        'size': '$size',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GalleryAnswerPhotosResult.fromJson(body);
  }

  Future<FamilyAlbumPageResult> fetchFamilyAlbums(
    String accessToken, {
    int page = 0,
    int size = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums').replace(
      queryParameters: {
        'page': '$page',
        'size': '$size',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyAlbumPageResult.fromJson(body);
  }

  Future<FamilyAlbumResult> createFamilyAlbum({
    required String accessToken,
    required String name,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyAlbumResult.fromJson(body);
  }

  Future<FamilyAlbumDetailResult> fetchFamilyAlbumDetail({
    required String accessToken,
    required int albumId,
    int page = 0,
    int size = 21,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums/$albumId').replace(
      queryParameters: {
        'page': '$page',
        'size': '$size',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyAlbumDetailResult.fromJson(body);
  }

  Future<FamilyAlbumResult> renameFamilyAlbum({
    required String accessToken,
    required int albumId,
    required String name,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums/$albumId');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyAlbumResult.fromJson(body);
  }

  Future<void> deleteFamilyAlbum({
    required String accessToken,
    required int albumId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums/$albumId');
    final response = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
  }

  Future<PhotoUploadUrlResult> createAlbumPhotoUploadUrl({
    required String accessToken,
    required int albumId,
    required String contentType,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/families/me/albums/$albumId/photos/upload-url',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'contentType': contentType}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PhotoUploadUrlResult.fromJson(body);
  }

  Future<List<FamilyAlbumPhotoResult>> addAlbumPhotos({
    required String accessToken,
    required int albumId,
    required List<String> imageKeys,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/albums/$albumId/photos');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'imageKeys': imageKeys}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = body['photos'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => FamilyAlbumPhotoResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteAlbumPhotos({
    required String accessToken,
    required int albumId,
    required List<int> photoIds,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/api/families/me/albums/$albumId/photos/delete');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'photoIds': photoIds}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
  }

  Future<FamilyTemperatureResult> fetchFamilyTemperature(String accessToken) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/temperature');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyTemperatureResult.fromJson(body);
  }

  Future<DiaryCalendarResult> fetchDiaryCalendar({
    required String accessToken,
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/diary/calendar').replace(
      queryParameters: {
        'year': '$year',
        'month': '$month',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiaryCalendarResult.fromJson(body);
  }

  Future<DiaryDayResult> fetchDiaryDay({
    required String accessToken,
    required DateTime date,
  }) async {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final uri = Uri.parse('$_baseUrl/api/families/me/diary/day').replace(
      queryParameters: {'date': '$y-$m-$d'},
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiaryDayResult.fromJson(body);
  }

  Future<DiaryDayResult> upsertTodayDiary({
    required String accessToken,
    required String content,
    required String weather,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/families/me/diary/today');
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'content': content,
        'weather': weather,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DiaryDayResult.fromJson(body);
  }
}

class FamilyTemperatureResult {
  const FamilyTemperatureResult({
    required this.temperature,
    required this.deltaFromYesterday,
    required this.statusLabel,
    required this.bubbleText,
    required this.colorHex,
    required this.recentChanges,
  });

  final double temperature;
  final double deltaFromYesterday;
  final String statusLabel;
  final String bubbleText;
  final String colorHex;
  final List<FamilyTemperatureChangeResult> recentChanges;

  factory FamilyTemperatureResult.fromJson(Map<String, dynamic> json) {
    final raw = json['recentChanges'] as List<dynamic>? ?? const [];
    return FamilyTemperatureResult(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 36.5,
      deltaFromYesterday:
          (json['deltaFromYesterday'] as num?)?.toDouble() ?? 0,
      statusLabel: json['statusLabel'] as String? ?? '',
      bubbleText: json['bubbleText'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#F09A4A',
      recentChanges: raw
          .map((e) =>
              FamilyTemperatureChangeResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FamilyTemperatureChangeResult {
  const FamilyTemperatureChangeResult({
    required this.date,
    required this.label,
    required this.delta,
  });

  final DateTime date;
  final String label;
  final double delta;

  factory FamilyTemperatureChangeResult.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    return FamilyTemperatureChangeResult(
      date: rawDate == null ? DateTime.now() : DateTime.parse(rawDate),
      label: json['label'] as String? ?? '',
      delta: (json['delta'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DiaryCalendarResult {
  const DiaryCalendarResult({required this.days});

  final List<DiaryCalendarDayResult> days;

  factory DiaryCalendarResult.fromJson(Map<String, dynamic> json) {
    final raw = json['days'] as List<dynamic>? ?? const [];
    return DiaryCalendarResult(
      days: raw
          .map((e) => DiaryCalendarDayResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DiaryCalendarDayResult {
  const DiaryCalendarDayResult({
    required this.date,
    required this.temperature,
    required this.statusLabel,
    required this.familyWeather,
    required this.entryCount,
  });

  final DateTime date;
  final double temperature;
  final String statusLabel;
  final String familyWeather;
  final int entryCount;

  factory DiaryCalendarDayResult.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    final parsed = rawDate == null ? DateTime.now() : DateTime.parse(rawDate);
    return DiaryCalendarDayResult(
      date: DateTime(parsed.year, parsed.month, parsed.day),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 36.5,
      statusLabel: json['statusLabel'] as String? ?? '',
      familyWeather: json['familyWeather'] as String? ?? '',
      entryCount: json['entryCount'] as int? ?? 0,
    );
  }
}

class DiaryDayResult {
  const DiaryDayResult({
    required this.date,
    required this.temperature,
    required this.statusLabel,
    required this.members,
    required this.entries,
    this.myEntry,
  });

  final DateTime date;
  final double temperature;
  final String statusLabel;
  final List<DiaryMemberWeatherResult> members;
  final List<DiaryEntryResult> entries;
  final DiaryMyEntryResult? myEntry;

  factory DiaryDayResult.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    final parsed = rawDate == null ? DateTime.now() : DateTime.parse(rawDate);
    final rawMembers = json['members'] as List<dynamic>? ?? const [];
    final rawEntries = json['entries'] as List<dynamic>? ?? const [];
    final rawMy = json['myEntry'];
    return DiaryDayResult(
      date: DateTime(parsed.year, parsed.month, parsed.day),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 36.5,
      statusLabel: json['statusLabel'] as String? ?? '',
      members: rawMembers
          .map((e) =>
              DiaryMemberWeatherResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      entries: rawEntries
          .map((e) => DiaryEntryResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      myEntry: rawMy is Map<String, dynamic>
          ? DiaryMyEntryResult.fromJson(rawMy)
          : null,
    );
  }
}

class DiaryMemberWeatherResult {
  const DiaryMemberWeatherResult({
    required this.userId,
    required this.roleLabel,
    required this.isMe,
    this.weather,
  });

  final int userId;
  final String roleLabel;
  final bool isMe;
  final String? weather;

  factory DiaryMemberWeatherResult.fromJson(Map<String, dynamic> json) {
    return DiaryMemberWeatherResult(
      userId: json['userId'] as int? ?? 0,
      roleLabel: json['roleLabel'] as String? ?? '',
      isMe: json['isMe'] as bool? ?? false,
      weather: json['weather'] as String?,
    );
  }
}

class DiaryEntryResult {
  const DiaryEntryResult({
    required this.userId,
    required this.roleLabel,
    required this.isMe,
    required this.content,
    required this.weather,
    required this.createdAt,
  });

  final int userId;
  final String roleLabel;
  final bool isMe;
  final String content;
  final String weather;
  final DateTime createdAt;

  factory DiaryEntryResult.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt'] as String?;
    return DiaryEntryResult(
      userId: json['userId'] as int? ?? 0,
      roleLabel: json['roleLabel'] as String? ?? '',
      isMe: json['isMe'] as bool? ?? false,
      content: json['content'] as String? ?? '',
      weather: json['weather'] as String? ?? '',
      createdAt: rawCreated == null ? DateTime.now() : DateTime.parse(rawCreated),
    );
  }
}

class DiaryMyEntryResult {
  const DiaryMyEntryResult({
    required this.content,
    required this.weather,
  });

  final String content;
  final String weather;

  factory DiaryMyEntryResult.fromJson(Map<String, dynamic> json) {
    return DiaryMyEntryResult(
      content: json['content'] as String? ?? '',
      weather: json['weather'] as String? ?? '',
    );
  }
}

class GalleryAnswerPhotosResult {
  const GalleryAnswerPhotosResult({
    required this.totalCount,
    required this.page,
    required this.size,
    required this.hasMore,
    required this.items,
  });

  final int totalCount;
  final int page;
  final int size;
  final bool hasMore;
  final List<GalleryAnswerPhotoResult> items;

  factory GalleryAnswerPhotosResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return GalleryAnswerPhotosResult(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 21,
      hasMore: json['hasMore'] as bool? ?? false,
      items: raw
          .map((e) => GalleryAnswerPhotoResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GalleryAnswerPhotoResult {
  const GalleryAnswerPhotoResult({
    required this.answerId,
    required this.dailyQuestionId,
    required this.imageUrl,
    required this.date,
    required this.role,
    this.birthOrder,
    required this.questionContent,
  });

  final int answerId;
  final int dailyQuestionId;
  final String imageUrl;
  final DateTime date;
  final String role;
  final int? birthOrder;
  final String questionContent;

  String get authorLabel =>
      FamilyMemberResult.labelFor(role: role, birthOrder: birthOrder);

  factory GalleryAnswerPhotoResult.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    final parsed = rawDate == null ? DateTime.now() : DateTime.parse(rawDate);
    return GalleryAnswerPhotoResult(
      answerId: json['answerId'] as int,
      dailyQuestionId: json['dailyQuestionId'] as int,
      imageUrl: json['imageUrl'] as String? ?? '',
      date: DateTime(parsed.year, parsed.month, parsed.day),
      role: json['role'] as String? ?? '',
      birthOrder: json['birthOrder'] as int?,
      questionContent: json['questionContent'] as String? ?? '',
    );
  }
}

class FamilyAlbumPageResult {
  const FamilyAlbumPageResult({
    required this.albums,
    required this.page,
    required this.size,
    required this.totalCount,
    required this.hasMore,
  });

  final List<FamilyAlbumResult> albums;
  final int page;
  final int size;
  final int totalCount;
  final bool hasMore;

  factory FamilyAlbumPageResult.fromJson(Map<String, dynamic> json) {
    final raw = json['albums'] as List<dynamic>? ?? const [];
    return FamilyAlbumPageResult(
      albums: raw
          .map((e) => FamilyAlbumResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class FamilyAlbumResult {
  const FamilyAlbumResult({
    required this.albumId,
    required this.title,
    required this.dateLabel,
    required this.count,
    this.coverUrl,
  });

  final int albumId;
  final String title;
  final String dateLabel;
  final int count;
  final String? coverUrl;

  factory FamilyAlbumResult.fromJson(Map<String, dynamic> json) {
    return FamilyAlbumResult(
      albumId: json['albumId'] as int,
      title: json['title'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl'] as String?,
    );
  }
}

class FamilyAlbumDetailResult {
  const FamilyAlbumDetailResult({
    required this.albumId,
    required this.title,
    required this.page,
    required this.size,
    required this.totalCount,
    required this.hasMore,
    required this.photos,
  });

  final int albumId;
  final String title;
  final int page;
  final int size;
  final int totalCount;
  final bool hasMore;
  final List<FamilyAlbumPhotoResult> photos;

  factory FamilyAlbumDetailResult.fromJson(Map<String, dynamic> json) {
    final raw = json['photos'] as List<dynamic>? ?? const [];
    return FamilyAlbumDetailResult(
      albumId: json['albumId'] as int,
      title: json['title'] as String? ?? '',
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 21,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      photos: raw
          .map((e) => FamilyAlbumPhotoResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FamilyAlbumPhotoResult {
  const FamilyAlbumPhotoResult({
    required this.photoId,
    required this.imageUrl,
    required this.savedAt,
  });

  final int photoId;
  final String imageUrl;
  final DateTime savedAt;

  factory FamilyAlbumPhotoResult.fromJson(Map<String, dynamic> json) {
    final raw = json['savedAt'] as String?;
    return FamilyAlbumPhotoResult(
      photoId: json['photoId'] as int,
      imageUrl: json['imageUrl'] as String? ?? '',
      savedAt: raw == null ? DateTime.now() : DateTime.parse(raw).toLocal(),
    );
  }
}

class PhotoUploadUrlResult {
  const PhotoUploadUrlResult({
    required this.uploadUrl,
    required this.imageKey,
    required this.contentType,
    required this.expiresInSeconds,
  });

  final String uploadUrl;
  final String imageKey;
  final String contentType;
  final int expiresInSeconds;

  factory PhotoUploadUrlResult.fromJson(Map<String, dynamic> json) {
    return PhotoUploadUrlResult(
      uploadUrl: json['uploadUrl'] as String,
      imageKey: json['imageKey'] as String,
      contentType: json['contentType'] as String? ?? 'image/jpeg',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
    );
  }
}

class DailyAnswerListResult {
  const DailyAnswerListResult({
    required this.dailyQuestionId,
    required this.answers,
  });

  final int dailyQuestionId;
  final List<DailyAnswerItemResult> answers;

  factory DailyAnswerListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['answers'] as List<dynamic>? ?? const [];
    return DailyAnswerListResult(
      dailyQuestionId: json['dailyQuestionId'] as int,
      answers: raw
          .map((e) => DailyAnswerItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyAnswerItemResult {
  const DailyAnswerItemResult({
    required this.answerId,
    required this.userId,
    required this.role,
    this.birthOrder,
    required this.content,
    this.imageUrl,
    required this.isMe,
    this.createdAt,
  });

  final int answerId;
  final int userId;
  final String role;
  final int? birthOrder;
  final String content;
  final String? imageUrl;
  final bool isMe;

  /// VER2 shows answer times and "먼저 도착한 답변" ordering.
  /// Optional until the backend adds `createdAt` (BACKEND_API_TODO.md).
  final DateTime? createdAt;

  String get roleLabel =>
      FamilyMemberResult.labelFor(role: role, birthOrder: birthOrder);

  factory DailyAnswerItemResult.fromJson(Map<String, dynamic> json) {
    return DailyAnswerItemResult(
      answerId: json['answerId'] as int,
      userId: json['userId'] as int,
      role: json['role'] as String? ?? '',
      birthOrder: json['birthOrder'] as int?,
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      isMe: json['isMe'] as bool? ?? false,
      createdAt: _parseOptionalDateTime(json['createdAt']),
    );
  }
}

DateTime? _parseOptionalDateTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

class MonthDailyQuestionsResult {
  const MonthDailyQuestionsResult({
    required this.year,
    required this.month,
    required this.items,
  });

  final int year;
  final int month;
  final List<TodayDailyQuestionResult> items;

  factory MonthDailyQuestionsResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return MonthDailyQuestionsResult(
      year: json['year'] as int,
      month: json['month'] as int,
      items: rawItems
          .map((e) => TodayDailyQuestionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TodayDailyQuestionResult {
  const TodayDailyQuestionResult({
    required this.status,
    this.message,
    required this.date,
    this.dailyQuestionId,
    this.questionId,
    this.content,
    this.category,
    this.sequenceNumber,
  });

  final String status;
  final String? message;
  final DateTime date;
  final int? dailyQuestionId;
  final int? questionId;
  final String? content;
  final String? category;

  /// "#128" on the VER2 question hero — the family's Nth question.
  /// Optional until the backend adds it (BACKEND_API_TODO.md).
  final int? sequenceNumber;

  bool get isReady => status == 'READY' && (content?.isNotEmpty ?? false);
  bool get isWaiting => !isReady;

  factory TodayDailyQuestionResult.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    final parsedDate = rawDate == null
        ? DateTime.now()
        : DateTime.parse(rawDate);
    return TodayDailyQuestionResult(
      status: json['status'] as String? ?? 'WAITING',
      message: json['message'] as String?,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      dailyQuestionId: json['dailyQuestionId'] as int?,
      questionId: json['questionId'] as int?,
      content: json['content'] as String?,
      category: json['category'] as String?,
      sequenceNumber: json['sequenceNumber'] as int?,
    );
  }
}

class MyFamilyResult {
  const MyFamilyResult({
    required this.familyId,
    required this.familyName,
    required this.inviteCode,
    required this.members,
  });

  final int familyId;
  final String familyName;
  final String inviteCode;
  final List<FamilyMemberResult> members;

  factory MyFamilyResult.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? const [];
    return MyFamilyResult(
      familyId: json['familyId'] as int,
      familyName: json['familyName'] as String,
      inviteCode: json['inviteCode'] as String,
      members: rawMembers
          .map((e) => FamilyMemberResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FamilyMemberResult {
  const FamilyMemberResult({
    required this.userId,
    required this.role,
    this.birthOrder,
    required this.isMe,
    this.isCreator,
  });

  final int userId;
  final String role;
  final int? birthOrder;
  final bool isMe;

  /// "만든 사람" badge. Optional until the backend adds it
  /// (BACKEND_API_TODO.md); null means unknown.
  final bool? isCreator;

  factory FamilyMemberResult.fromJson(Map<String, dynamic> json) {
    return FamilyMemberResult(
      userId: json['userId'] as int? ?? 0,
      role: json['role'] as String? ?? '',
      birthOrder: json['birthOrder'] as int?,
      isMe: json['isMe'] as bool? ?? false,
      isCreator: json['isCreator'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': role,
        'birthOrder': birthOrder,
        'isMe': isMe,
        if (isCreator != null) 'isCreator': isCreator,
      };

  /// 아빠 / 엄마 / 첫째 아들 / 둘째 딸 ...
  String get roleLabel => labelFor(role: role, birthOrder: birthOrder);

  static String labelFor({required String role, int? birthOrder}) {
    const birth = {1: '첫째', 2: '둘째', 3: '셋째', 4: '넷째', 5: '다섯째'};
    switch (role) {
      case 'FATHER':
        return '아빠';
      case 'MOTHER':
        return '엄마';
      case 'SON':
        final order = birth[birthOrder];
        return order == null ? '아들' : '$order 아들';
      case 'DAUGHTER':
        final order = birth[birthOrder];
        return order == null ? '딸' : '$order 딸';
      default:
        return role;
    }
  }
}

class CreateFamilyResult {
  const CreateFamilyResult({
    required this.familyId,
    required this.familyName,
    required this.inviteCode,
    required this.role,
    this.birthOrder,
    required this.isFamilyCreator,
  });

  final int familyId;
  final String familyName;
  final String inviteCode;
  final String role;
  final int? birthOrder;
  final bool isFamilyCreator;

  factory CreateFamilyResult.fromJson(Map<String, dynamic> json) {
    return CreateFamilyResult(
      familyId: json['familyId'] as int,
      familyName: json['familyName'] as String,
      inviteCode: json['inviteCode'] as String,
      role: json['role'] as String,
      birthOrder: json['birthOrder'] as int?,
      isFamilyCreator: json['isFamilyCreator'] as bool? ?? true,
    );
  }
}

class SendEmailCodeResult {
  const SendEmailCodeResult({
    required this.email,
    required this.expiresInSeconds,
    this.debugCode,
  });

  final String email;
  final int expiresInSeconds;
  final String? debugCode;

  factory SendEmailCodeResult.fromJson(Map<String, dynamic> json) {
    return SendEmailCodeResult(
      email: json['email'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 600,
      debugCode: json['debugCode'] as String?,
    );
  }
}

class EmailSignupStatusResult {
  const EmailSignupStatusResult({
    required this.email,
    required this.status,
  });

  final String email;

  /// AVAILABLE | REGISTERED | RECOVERABLE
  final String status;

  factory EmailSignupStatusResult.fromJson(Map<String, dynamic> json) {
    return EmailSignupStatusResult(
      email: json['email'] as String,
      status: json['status'] as String,
    );
  }
}

class VerifyEmailCodeResult {
  const VerifyEmailCodeResult({
    required this.email,
    required this.signupToken,
    required this.expiresInSeconds,
  });

  final String email;
  final String signupToken;
  final int expiresInSeconds;

  factory VerifyEmailCodeResult.fromJson(Map<String, dynamic> json) {
    return VerifyEmailCodeResult(
      email: json['email'] as String,
      signupToken: json['signupToken'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 1800,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  factory ApiException.fromResponse(int statusCode, String body) {
    String message = 'Request failed ($statusCode): $body';
    String? code;
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final serverMessage = json['message'] as String?;
        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
        code = json['code'] as String?;
      }
    } catch (_) {
      // Keep raw body message.
    }
    return ApiException(message, statusCode: statusCode, code: code);
  }

  @override
  String toString() => message;
}
