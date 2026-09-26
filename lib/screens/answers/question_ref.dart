import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/utils/korean.dart';

/// A dated question as the VER2 screens pass it around.
class QuestionRef {
  const QuestionRef({
    required this.date,
    required this.dailyQuestionId,
    required this.content,
    this.category,
    this.sequenceNumber,
    this.waitingMessage,
  });

  final DateTime date;
  final int? dailyQuestionId;
  final String content;
  final String? category;
  final int? sequenceNumber;

  /// Set when the question has not arrived yet ("03:00에 도착해요").
  final String? waitingMessage;

  bool get isReady => dailyQuestionId != null && waitingMessage == null;
  bool get isToday => sameDay(date, DateTime.now());

  /// Emotional questions get the pink band (prototype `emo`).
  bool get isEmotional {
    final c = category ?? '';
    return c.contains('감성') || c.contains('마음') || c.toUpperCase().contains('EMOTION');
  }

  factory QuestionRef.fromResult(TodayDailyQuestionResult r) => QuestionRef(
        date: dateOnly(r.date),
        dailyQuestionId: r.isReady ? r.dailyQuestionId : null,
        content: r.content ?? '',
        category: r.category,
        sequenceNumber: r.sequenceNumber,
        waitingMessage: r.isReady
            ? null
            : (r.message?.isNotEmpty == true ? r.message : '오늘의 질문은 새벽 3시에 도착해요.'),
      );

  factory QuestionRef.waiting(DateTime date, {String? message}) => QuestionRef(
        date: dateOnly(date),
        dailyQuestionId: null,
        content: '',
        waitingMessage: message ??
            (sameDay(date, DateTime.now())
                ? '오늘의 질문은 새벽 3시에 도착해요.'
                : '이 날은 도착한 질문이 없어요.'),
      );
}
