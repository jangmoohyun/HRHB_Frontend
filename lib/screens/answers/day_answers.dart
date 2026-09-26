import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';

class AnswerView {
  const AnswerView({required this.member, required this.raw});
  final MemberLook member;
  final DailyAnswerItemResult raw;

  String get timeLabel => raw.createdAt == null ? '' : answerTime(raw.createdAt!);
}

/// Everyone's answers for one question, arranged the way VER2 shows them.
class DayAnswers {
  const DayAnswers({
    required this.answers,
    required this.members,
  });

  /// Me first, then family order (prototype `answersList`).
  final List<AnswerView> answers;
  final List<MemberLook> members;

  static const empty = DayAnswers(answers: [], members: []);

  Set<int> get answeredIds => {for (final a in answers) a.member.userId};
  AnswerView? get mine => answers.where((a) => a.member.isMe).firstOrNull;

  /// Other members' answers, earliest first when the server sends
  /// `createdAt`, otherwise in family order.
  List<AnswerView> get othersByArrival {
    final others = answers.where((a) => !a.member.isMe).toList();
    if (others.every((a) => a.raw.createdAt != null)) {
      others.sort((a, b) => a.raw.createdAt!.compareTo(b.raw.createdAt!));
    }
    return others;
  }

  List<MemberLook> get pending =>
      members.where((m) => !answeredIds.contains(m.userId)).toList();

  static Future<DayAnswers> load(int dailyQuestionId) async {
    final fam = await FamilyContext.instance.ensure();
    final list = await AuthedCall.run(
      (t) => ApiClient().fetchDailyAnswers(accessToken: t, dailyQuestionId: dailyQuestionId),
    );
    return arrange(fam, list.answers);
  }

  static DayAnswers arrange(FamilySnapshot fam, List<DailyAnswerItemResult> raw) {
    final views = <AnswerView>[];
    for (final a in raw) {
      final look = fam.byUserId(a.userId) ??
          MemberLook(
            userId: a.userId,
            label: a.roleLabel,
            short: MemberLook.shortFor(a.role),
            initial: MemberLook.initialFor(MemberLook.shortFor(a.role), a.isMe),
            tint: MemberLook.baseTint(MemberLook.shortFor(a.role)),
            isMe: a.isMe,
          );
      views.add(AnswerView(member: look, raw: a));
    }
    int orderOf(AnswerView v) {
      if (v.member.isMe) return -1;
      final i = fam.members.indexWhere((m) => m.userId == v.member.userId);
      return i < 0 ? 999 : i;
    }

    views.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    return DayAnswers(answers: views, members: fam.members);
  }
}
