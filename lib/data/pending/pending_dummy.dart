import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/utils/korean.dart';

import '../authed_call.dart';
import '../family_context.dart';
import 'pending_api.dart';
import 'pending_models.dart';

/// Sample data for [PendingApi], shaped like the VER2 design mockups
/// (스트릭 12일, 참여율 92/100/76/64%, 리포트 하이라이트 …).
///
/// Uses the real family members and — where an existing endpoint can answer —
/// real data (e.g. whether I answered today), so the sample stays consistent
/// with the rest of the screen. Everything else is deterministic per date.
class DummyPendingApi implements PendingApi {
  final _api = ApiClient();
  bool _notificationsRead = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<List<int>> _memberIds() async {
    final fam = await FamilyContext.instance.ensure();
    return [for (final m in fam.members) m.userId];
  }

  Future<int?> _myId() async {
    final fam = await FamilyContext.instance.ensure();
    return fam.me?.userId;
  }

  /// Real answers for today (so the sample agrees with the home hero).
  Future<Set<int>> _todayAnsweredIds() async {
    try {
      final today = await AuthedCall.run(_api.fetchTodayDailyQuestion);
      final id = today.dailyQuestionId;
      if (id == null) return {};
      final list = await AuthedCall.run(
        (t) => _api.fetchDailyAnswers(accessToken: t, dailyQuestionId: id),
      );
      return {for (final a in list.answers) a.userId};
    } catch (_) {
      return {};
    }
  }

  Future<bool> _answeredToday() async {
    final me = await _myId();
    return me != null && (await _todayAnsweredIds()).contains(me);
  }

  @override
  Future<StreakSummary> fetchStreak() async {
    final today = _today();
    final answered = await _answeredToday();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return StreakSummary(
      current: answered ? 13 : 12,
      answeredToday: answered,
      week: [
        for (var i = 0; i < 7; i++)
          () {
            final d = monday.add(Duration(days: i));
            return StreakDay(
              date: d,
              answered: d.isBefore(today) || (d == today && answered),
            );
          }(),
      ],
    );
  }

  @override
  Future<List<AnswerStatusDay>> fetchAnswerStatus({
    required int year,
    required int month,
  }) async {
    final ids = await _memberIds();
    final me = await _myId();
    final today = _today();
    final todayIds = await _todayAnsweredIds();
    final last = DateTime(year, month + 1, 0).day;
    final out = <AnswerStatusDay>[];
    for (var d = 1; d <= last; d++) {
      final date = DateTime(year, month, d);
      if (date.isAfter(today)) break;
      if (date == today) {
        out.add(AnswerStatusDay(date: date, answeredUserIds: todayIds));
        continue;
      }
      final seed = d * 7 + month * 3 + year;
      final picked = <int>{};
      for (var i = 0; i < ids.length; i++) {
        if ((seed + i * 5) % 5 != 0) picked.add(ids[i]);
      }
      // "12일째" — I answered every one of the last 12 days.
      if (me != null && today.difference(date).inDays <= 12) picked.add(me);
      out.add(AnswerStatusDay(date: date, answeredUserIds: picked));
    }
    return out;
  }

  Future<Map<DateTime, Set<int>>> _statusRange(DateTime from, DateTime to) async {
    final map = <DateTime, Set<int>>{};
    var cursor = DateTime(from.year, from.month);
    while (!cursor.isAfter(DateTime(to.year, to.month))) {
      for (final s in await fetchAnswerStatus(year: cursor.year, month: cursor.month)) {
        map[s.date] = s.answeredUserIds;
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return map;
  }

  static const _sampleDeltas = [0.3, -0.2, 0.5, 0.0, -0.4, 0.5];

  List<TempChange> _sampleTemps() {
    final today = _today();
    return [
      for (var i = 0; i < 6; i++)
        TempChange(
          date: today.subtract(Duration(days: 5 - i)),
          delta: _sampleDeltas[i],
        ),
    ];
  }

  Future<List<ReportHighlight>> _highlights(String countText) async {
    final fam = await FamilyContext.instance.ensure();
    final first = fam.members.where((m) => !m.isMe).firstOrNull ?? fam.me;
    final who = first?.label ?? '가족';
    return [
      ReportHighlight(
        type: 'FIRST_RESPONDER',
        title: '${withSubjectParticle(who)} 가장 먼저 답했어요',
        subtitle: countText,
      ),
      const ReportHighlight(
        type: 'LONGEST_ANSWER',
        title: '가장 긴 답변이 나온 질문',
        subtitle: '가족에게 고마웠지만 말하지 못한 순간이 있나요?',
      ),
    ];
  }

  @override
  Future<WeeklyReport> fetchWeeklyReport({required DateTime weekStart}) async {
    final ids = await _memberIds();
    final today = _today();
    final end = weekStart.add(const Duration(days: 6));
    final status = await _statusRange(weekStart, end);
    var answered = 0, total = 0;
    final rows = [
      for (final id in ids)
        ReportMemberRow(
          userId: id,
          days: [
            for (var i = 0; i < 7; i++)
              () {
                final d = weekStart.add(Duration(days: i));
                if (d.isAfter(today)) return null;
                final hit = status[d]?.contains(id) ?? false;
                total++;
                if (hit) answered++;
                return hit;
              }(),
          ],
        ),
    ];
    final rate = total == 0 ? 0 : (answered * 100 / total).round();
    final temps = _sampleTemps();
    final pastDays = today.difference(weekStart).inDays.clamp(0, 6) + 1;
    return WeeklyReport(
      start: weekStart,
      end: end,
      answerRate: rate,
      previousAnswerRate: 60,
      rows: rows,
      temperatureChanges: temps,
      temperatureSum: temps.fold(0.0, (a, t) => a + t.delta),
      highlights: await _highlights('이번 주 $pastDays번 중 ${(pastDays * 0.8).round()}번'),
    );
  }

  @override
  Future<MonthlyReport> fetchMonthlyReport({
    required int year,
    required int month,
  }) async {
    final ids = await _memberIds();
    final today = _today();
    final status = {
      for (final s in await fetchAnswerStatus(year: year, month: month))
        s.date: s.answeredUserIds.length,
    };
    final last = DateTime(year, month + 1, 0).day;
    var sum = 0, past = 0;
    final days = <ReportDayCount>[];
    for (var d = 1; d <= last; d++) {
      final date = DateTime(year, month, d);
      if (date.isAfter(today)) {
        days.add(ReportDayCount(date: date, answeredCount: null));
      } else {
        final n = status[date] ?? 0;
        sum += n;
        past++;
        days.add(ReportDayCount(date: date, answeredCount: n));
      }
    }
    final rate = past == 0 || ids.isEmpty ? 0 : (sum * 100 / (past * ids.length)).round();
    return MonthlyReport(
      year: year,
      month: month,
      answerRate: rate,
      previousAnswerRate: rate - 6,
      memberCount: ids.length,
      days: days,
      temperatureChanges: _sampleTemps(),
      temperatureSum: 1.9,
      highlights: await _highlights('$month월 $past번 중 ${(past * 0.68).round()}번'),
    );
  }

  @override
  Future<List<MemberParticipation>> fetchParticipation({
    required int year,
    required int month,
  }) async {
    final ids = await _memberIds();
    final me = await _myId();
    final answered = await _answeredToday();
    const rates = [92, 100, 76, 64];
    return [
      for (var i = 0; i < ids.length; i++)
        MemberParticipation(
          userId: ids[i],
          answerRate: ids[i] == me
              ? (answered ? 80 : 76)
              : rates[i % rates.length],
        ),
    ];
  }

  @override
  Future<NotificationPage> fetchNotifications({int page = 0, int size = 30}) async {
    final fam = await FamilyContext.instance.ensure();
    final others = fam.members.where((m) => !m.isMe).toList();
    String who(int i) =>
        others.isEmpty ? '가족' : others[i % others.length].label;
    final today = _today();
    DateTime at(int h, int m) => today.add(Duration(hours: h, minutes: m));
    final items = [
      AppNotification(
        id: 6,
        type: NotificationType.questionArrived,
        message: '오늘의 질문이 도착했어요.',
        createdAt: at(3, 0),
        read: _notificationsRead,
        targetDate: today,
      ),
      AppNotification(
        id: 5,
        type: NotificationType.answerPosted,
        message: '${withSubjectParticle(who(0))} 오늘의 질문에 답변을 남겼어요.',
        createdAt: at(8, 10),
        read: _notificationsRead,
        targetDate: today,
      ),
      AppNotification(
        id: 4,
        type: NotificationType.temperatureChanged,
        message: '가족 온도가 어제보다 0.5°C 올랐어요.',
        createdAt: at(10, 0),
        read: _notificationsRead,
      ),
      AppNotification(
        id: 3,
        type: NotificationType.answerPosted,
        message: '${withSubjectParticle(who(1))} 오늘의 질문에 답변을 남겼어요.',
        createdAt: at(12, 32),
        read: true,
        targetDate: today,
      ),
      AppNotification(
        id: 2,
        type: NotificationType.diaryPosted,
        message: '${withSubjectParticle(who(0))} 오늘의 일지를 남겼어요.',
        createdAt: at(13, 20),
        read: true,
        targetDate: today,
      ),
      AppNotification(
        id: 1,
        type: NotificationType.albumPhotosAdded,
        message: "'추석' 앨범에 사진 7장이 올라왔어요.",
        createdAt: today.subtract(const Duration(days: 5)),
        read: true,
      ),
    ];
    return NotificationPage(
      items: items,
      hasMore: false,
      unreadCount: items.where((n) => !n.read).length,
    );
  }

  @override
  Future<void> markAllNotificationsRead() async {
    _notificationsRead = true;
  }

  @override
  Future<AuthResult> loginWithApple({bool restoreDeletedAccount = false}) {
    throw const FeatureNotReadyException('Apple 로그인은 준비 중이에요.');
  }
}
