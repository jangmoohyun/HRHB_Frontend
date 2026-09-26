import 'package:hrhb_frontend/services/api_client.dart';

import 'pending_dummy.dart';
import 'pending_http.dart';
import 'pending_models.dart';

/// Switch between sample data and the real endpoints.
///
/// Defaults to sample data because the endpoints below are not implemented on
/// the server yet. Once the backend ships BACKEND_API_TODO.md, run with
///   flutter run --dart-define=HARU_PENDING_DUMMY=false
/// or flip the default here. **Must be false for a store release** — the
/// sample streak/report numbers are not the user's data.
const bool kPendingUseDummy =
    bool.fromEnvironment('HARU_PENDING_DUMMY', defaultValue: true);

/// VER2 features without a backend yet. Every method maps to one endpoint in
/// BACKEND_API_TODO.md (P1–P7).
abstract class PendingApi {
  static final PendingApi instance =
      kPendingUseDummy ? DummyPendingApi() : HttpPendingApi();

  /// P1 `GET /api/families/me/streak`
  Future<StreakSummary> fetchStreak();

  /// P2 `GET /api/families/me/daily-question/answer-status?year&month`
  Future<List<AnswerStatusDay>> fetchAnswerStatus({
    required int year,
    required int month,
  });

  /// P3 `GET /api/families/me/reports/weekly?weekStart=YYYY-MM-DD`
  Future<WeeklyReport> fetchWeeklyReport({required DateTime weekStart});

  /// P4 `GET /api/families/me/reports/monthly?year&month`
  Future<MonthlyReport> fetchMonthlyReport({required int year, required int month});

  /// P5 `GET /api/families/me/participation?year&month`
  Future<List<MemberParticipation>> fetchParticipation({
    required int year,
    required int month,
  });

  /// P6 `GET /api/me/notifications?page&size`
  Future<NotificationPage> fetchNotifications({int page = 0, int size = 30});

  /// P6 `POST /api/me/notifications/read-all`
  Future<void> markAllNotificationsRead();

  /// P7 `POST /api/auth/apple` — also needs the Sign in with Apple capability
  /// and `sign_in_with_apple` on the client (see the TODO doc).
  Future<AuthResult> loginWithApple({bool restoreDeletedAccount = false});
}
