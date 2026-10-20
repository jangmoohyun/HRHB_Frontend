/// Korean text helpers.
library;

bool _hasFinalConsonant(String word) {
  if (word.isEmpty) return false;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// "엄마" → "엄마가", "첫째 아들" → "첫째 아들이".
String withSubjectParticle(String word) =>
    '$word${_hasFinalConsonant(word) ? '이' : '가'}';

/// "'행복한 우리집'이" / "'우리 가족'이" — particle after a quoted name.
String quotedWithSubjectParticle(String word) =>
    "'$word'${_hasFinalConsonant(word) ? '이' : '가'}";

const weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

/// DateTime.weekday is 1 (Mon) … 7 (Sun).
String dowOf(DateTime d) => weekdayShort[d.weekday - 1];

String ampmTime(DateTime t) {
  final h = t.hour;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = h < 12 ? '오전' : '오후';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$ampm $hh:$m';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "9월 25일 금요일"
String fullDate(DateTime d) => '${d.month}월 ${d.day}일 ${dowOf(d)}요일';

/// Relative time label used on answers and notifications:
/// today → "오전 8:10", this year → "9월 21일 오후 9:12".
String answerTime(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return ampmTime(t);
  return '${t.month}월 ${t.day}일 ${ampmTime(t)}';
}

/// Notification time: "오늘 오전 3:00" / "9월 20일".
String notificationTime(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return '오늘 ${ampmTime(t)}';
  return '${t.month}월 ${t.day}일';
}
