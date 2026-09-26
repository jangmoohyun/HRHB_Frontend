/// Models for VER2 features whose backend endpoints do not exist yet.
///
/// JSON shapes are specified in BACKEND_API_TODO.md; `fromJson` here is
/// the exact parser the HTTP implementation uses, so the backend only has to
/// match that document.
library;

DateTime _date(Object? raw) {
  final s = raw as String;
  final d = DateTime.parse(s);
  return DateTime(d.year, d.month, d.day);
}

double _num(Object? raw) => (raw as num?)?.toDouble() ?? 0;

// ── P1 streak ───────────────────────────────────────────────────────────────

class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.answeredToday,
    required this.week,
  });

  /// Consecutive days *I* answered, including today if answered.
  final int current;
  final bool answeredToday;

  /// Monday → Sunday of the current week.
  final List<StreakDay> week;

  factory StreakSummary.fromJson(Map<String, dynamic> j) => StreakSummary(
        current: j['currentStreak'] as int? ?? 0,
        answeredToday: j['answeredToday'] as bool? ?? false,
        week: [
          for (final d in (j['week'] as List? ?? const []))
            StreakDay.fromJson(d as Map<String, dynamic>),
        ],
      );
}

class StreakDay {
  const StreakDay({required this.date, required this.answered});
  final DateTime date;
  final bool answered;

  factory StreakDay.fromJson(Map<String, dynamic> j) =>
      StreakDay(date: _date(j['date']), answered: j['answered'] as bool? ?? false);
}

// ── P2 per-day answer status ────────────────────────────────────────────────

class AnswerStatusDay {
  const AnswerStatusDay({required this.date, required this.answeredUserIds});
  final DateTime date;
  final Set<int> answeredUserIds;

  factory AnswerStatusDay.fromJson(Map<String, dynamic> j) => AnswerStatusDay(
        date: _date(j['date']),
        answeredUserIds: {
          for (final id in (j['answeredUserIds'] as List? ?? const [])) id as int,
        },
      );
}

// ── P3 / P4 reports ─────────────────────────────────────────────────────────

class TempChange {
  const TempChange({required this.date, required this.delta});
  final DateTime date;
  final double delta;

  factory TempChange.fromJson(Map<String, dynamic> j) =>
      TempChange(date: _date(j['date']), delta: _num(j['delta']));
}

class ReportHighlight {
  const ReportHighlight({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  /// FIRST_RESPONDER | LONGEST_ANSWER | (anything else → generic icon)
  final String type;
  final String title;
  final String subtitle;

  factory ReportHighlight.fromJson(Map<String, dynamic> j) => ReportHighlight(
        type: j['type'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
      );
}

class ReportMemberRow {
  const ReportMemberRow({required this.userId, required this.days});
  final int userId;

  /// Monday → Sunday. null = day hasn't happened yet.
  final List<bool?> days;

  factory ReportMemberRow.fromJson(Map<String, dynamic> j) => ReportMemberRow(
        userId: j['userId'] as int,
        days: [for (final v in (j['answered'] as List? ?? const [])) v as bool?],
      );
}

class WeeklyReport {
  const WeeklyReport({
    required this.start,
    required this.end,
    required this.answerRate,
    required this.previousAnswerRate,
    required this.rows,
    required this.temperatureChanges,
    required this.temperatureSum,
    required this.highlights,
  });

  final DateTime start;
  final DateTime end;
  final int answerRate;
  final int? previousAnswerRate;
  final List<ReportMemberRow> rows;
  final List<TempChange> temperatureChanges;
  final double temperatureSum;
  final List<ReportHighlight> highlights;

  factory WeeklyReport.fromJson(Map<String, dynamic> j) => WeeklyReport(
        start: _date(j['periodStart']),
        end: _date(j['periodEnd']),
        answerRate: j['answerRate'] as int? ?? 0,
        previousAnswerRate: j['previousAnswerRate'] as int?,
        rows: [
          for (final r in (j['members'] as List? ?? const []))
            ReportMemberRow.fromJson(r as Map<String, dynamic>),
        ],
        temperatureChanges: [
          for (final t in (j['temperatureChanges'] as List? ?? const []))
            TempChange.fromJson(t as Map<String, dynamic>),
        ],
        temperatureSum: _num(j['temperatureSum']),
        highlights: [
          for (final h in (j['highlights'] as List? ?? const []))
            ReportHighlight.fromJson(h as Map<String, dynamic>),
        ],
      );
}

class ReportDayCount {
  const ReportDayCount({required this.date, required this.answeredCount});
  final DateTime date;

  /// null = future day.
  final int? answeredCount;

  factory ReportDayCount.fromJson(Map<String, dynamic> j) => ReportDayCount(
        date: _date(j['date']),
        answeredCount: j['answeredCount'] as int?,
      );
}

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.answerRate,
    required this.previousAnswerRate,
    required this.memberCount,
    required this.days,
    required this.temperatureChanges,
    required this.temperatureSum,
    required this.highlights,
  });

  final int year;
  final int month;
  final int answerRate;
  final int? previousAnswerRate;
  final int memberCount;
  final List<ReportDayCount> days;
  final List<TempChange> temperatureChanges;
  final double temperatureSum;
  final List<ReportHighlight> highlights;

  factory MonthlyReport.fromJson(Map<String, dynamic> j) => MonthlyReport(
        year: j['year'] as int,
        month: j['month'] as int,
        answerRate: j['answerRate'] as int? ?? 0,
        previousAnswerRate: j['previousAnswerRate'] as int?,
        memberCount: j['memberCount'] as int? ?? 0,
        days: [
          for (final d in (j['days'] as List? ?? const []))
            ReportDayCount.fromJson(d as Map<String, dynamic>),
        ],
        temperatureChanges: [
          for (final t in (j['temperatureChanges'] as List? ?? const []))
            TempChange.fromJson(t as Map<String, dynamic>),
        ],
        temperatureSum: _num(j['temperatureSum']),
        highlights: [
          for (final h in (j['highlights'] as List? ?? const []))
            ReportHighlight.fromJson(h as Map<String, dynamic>),
        ],
      );
}

// ── P5 participation ────────────────────────────────────────────────────────

class MemberParticipation {
  const MemberParticipation({required this.userId, required this.answerRate});
  final int userId;
  final int answerRate;

  factory MemberParticipation.fromJson(Map<String, dynamic> j) =>
      MemberParticipation(
        userId: j['userId'] as int,
        answerRate: j['answerRate'] as int? ?? 0,
      );
}

// ── P6 notifications ────────────────────────────────────────────────────────

enum NotificationType {
  questionArrived,
  answerPosted,
  temperatureChanged,
  diaryPosted,
  albumPhotosAdded,
  unknown;

  static NotificationType parse(String? raw) => switch (raw) {
        'QUESTION_ARRIVED' => questionArrived,
        'ANSWER_POSTED' => answerPosted,
        'TEMPERATURE_CHANGED' => temperatureChanged,
        'DIARY_POSTED' => diaryPosted,
        'ALBUM_PHOTOS_ADDED' => albumPhotosAdded,
        _ => unknown,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.read,
    this.targetDate,
    this.albumId,
  });

  final int id;
  final NotificationType type;
  final String message;
  final DateTime createdAt;
  final bool read;

  /// Question/diary date the notification points at.
  final DateTime? targetDate;
  final int? albumId;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final target = j['target'] as Map<String, dynamic>?;
    final rawDate = target?['date'] as String?;
    return AppNotification(
      id: j['id'] as int,
      type: NotificationType.parse(j['type'] as String?),
      message: j['message'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      read: j['read'] as bool? ?? false,
      targetDate: rawDate == null ? null : _date(rawDate),
      albumId: target?['albumId'] as int?,
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final bool hasMore;
  final int unreadCount;

  factory NotificationPage.fromJson(Map<String, dynamic> j) => NotificationPage(
        items: [
          for (final n in (j['items'] as List? ?? const []))
            AppNotification.fromJson(n as Map<String, dynamic>),
        ],
        hasMore: j['hasMore'] as bool? ?? false,
        unreadCount: j['unreadCount'] as int? ?? 0,
      );
}

/// Thrown by features that need client-side setup the app does not have yet
/// (e.g. Sign in with Apple entitlement).
class FeatureNotReadyException implements Exception {
  const FeatureNotReadyException(this.message);
  final String message;
  @override
  String toString() => message;
}
