import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hrhb_frontend/config/env.dart';
import 'package:hrhb_frontend/services/api_client.dart';

import '../authed_call.dart';
import 'pending_api.dart';
import 'pending_models.dart';

/// Real implementation of [PendingApi]. The request/response contract lives in
/// BACKEND_API_TODO.md — keep the two in sync.
class HttpPendingApi implements PendingApi {
  HttpPendingApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => Env.apiBaseUrl;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) {
    return AuthedCall.run((token) async {
      final uri = Uri.parse('$_base$path').replace(queryParameters: query);
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException.fromResponse(res.statusCode, res.body);
      }
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    });
  }

  @override
  Future<StreakSummary> fetchStreak() async =>
      StreakSummary.fromJson(await _get('/api/families/me/streak'));

  @override
  Future<List<AnswerStatusDay>> fetchAnswerStatus({
    required int year,
    required int month,
  }) async {
    final j = await _get('/api/families/me/daily-question/answer-status', {
      'year': '$year',
      'month': '$month',
    });
    return [
      for (final d in (j['days'] as List? ?? const []))
        AnswerStatusDay.fromJson(d as Map<String, dynamic>),
    ];
  }

  @override
  Future<WeeklyReport> fetchWeeklyReport({required DateTime weekStart}) async =>
      WeeklyReport.fromJson(await _get(
        '/api/families/me/reports/weekly',
        {'weekStart': _ymd(weekStart)},
      ));

  @override
  Future<MonthlyReport> fetchMonthlyReport({
    required int year,
    required int month,
  }) async =>
      MonthlyReport.fromJson(await _get(
        '/api/families/me/reports/monthly',
        {'year': '$year', 'month': '$month'},
      ));

  @override
  Future<List<MemberParticipation>> fetchParticipation({
    required int year,
    required int month,
  }) async {
    final j = await _get('/api/families/me/participation', {
      'year': '$year',
      'month': '$month',
    });
    return [
      for (final m in (j['members'] as List? ?? const []))
        MemberParticipation.fromJson(m as Map<String, dynamic>),
    ];
  }

  @override
  Future<NotificationPage> fetchNotifications({int page = 0, int size = 30}) async =>
      NotificationPage.fromJson(await _get(
        '/api/me/notifications',
        {'page': '$page', 'size': '$size'},
      ));

  @override
  Future<void> markAllNotificationsRead() {
    return AuthedCall.run((token) async {
      final res = await _client.post(
        Uri.parse('$_base/api/me/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException.fromResponse(res.statusCode, res.body);
      }
    });
  }

  @override
  Future<AuthResult> loginWithApple({bool restoreDeletedAccount = false}) {
    // The server side is `POST /api/auth/apple` with
    // {identityToken, authorizationCode, restoreDeletedAccount} → AuthResult.
    // Obtaining identityToken needs the `sign_in_with_apple` package and the
    // Sign in with Apple capability in Xcode, which this build does not
    // include yet (BACKEND_API_TODO.md P7).
    throw const FeatureNotReadyException('Apple 로그인은 준비 중이에요.');
  }
}
