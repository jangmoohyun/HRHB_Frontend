import 'package:flutter/material.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

/// A member's weather on a given day.
class MemberWeather {
  const MemberWeather({required this.member, required this.weather});
  final MemberLook member;
  final HaruWeather? weather;
}

/// Diary day mapped onto family looks.
class DiaryDayView {
  const DiaryDayView({
    required this.date,
    required this.temperature,
    required this.members,
    required this.entries,
    required this.myEntry,
  });

  final DateTime date;
  final double temperature;
  final List<MemberWeather> members;
  final List<({MemberLook member, DiaryEntryResult entry})> entries;
  final DiaryMyEntryResult? myEntry;

  /// Family weather (prototype `composite`: averaged).
  HaruWeather? get composite => HaruWeather.composite(members.map((m) => m.weather));

  static Future<DiaryDayView> load(DateTime date) async {
    final fam = await FamilyContext.instance.ensure();
    final day = await AuthedCall.run((t) => ApiClient().fetchDiaryDay(accessToken: t, date: date));
    return fromResult(fam, day);
  }

  static DiaryDayView fromResult(FamilySnapshot fam, DiaryDayResult day) {
    MemberLook lookFor(int userId, String roleLabel, bool isMe) =>
        fam.byUserId(userId) ??
        MemberLook(
          userId: userId,
          label: roleLabel,
          role: MemberLook.roleFor(roleLabel),
          tint: HaruColors.sand,
          isMe: isMe,
        );

    final byId = {for (final m in day.members) m.userId: m};
    final members = <MemberWeather>[
      for (final m in fam.members)
        MemberWeather(member: m, weather: HaruWeather.fromWire(byId[m.userId]?.weather)),
    ];
    return DiaryDayView(
      date: dateOnly(day.date),
      temperature: day.temperature,
      members: members,
      entries: [
        for (final e in day.entries) (member: lookFor(e.userId, e.roleLabel, e.isMe), entry: e),
      ],
      myEntry: day.myEntry,
    );
  }
}

/// The five weather tiles (54 tall, radius 14) with labels.
class WeatherPicker extends StatelessWidget {
  const WeatherPicker({super.key, required this.value, required this.onPick, this.gap = 6});

  final HaruWeather? value;
  final ValueChanged<HaruWeather> onPick;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in HaruWeather.values) ...[
          if (w != HaruWeather.values.first) SizedBox(width: gap),
          Expanded(
            child: Pressable(
              onTap: () => onPick(w),
              semanticLabel: w.label,
              child: Column(
                children: [
                  AnimatedScale(
                    scale: value == w ? 1.08 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: HaruMotion.pop,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: w.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: value == w ? HaruColors.forest : Colors.transparent,
                          width: 1.6,
                        ),
                      ),
                      child: Icon(w.icon, size: 28, color: w.color),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    w.label,
                    maxLines: 1,
                    style: hr(13.5, color: value == w ? HaruColors.forest : HaruColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 오늘의 일지 작성/수정 sheet. Returns true when saved.
Future<bool> showDiaryComposeSheet(
  BuildContext context, {
  HaruWeather? initialWeather,
  String initialText = '',
}) async {
  final editing = initialText.isNotEmpty;
  final saved = await showHaruSheet<bool>(
    context,
    builder: (_) => _ComposeBody(
      title: editing ? '오늘의 일지 수정하기' : '오늘의 일지 작성하기',
      initialWeather: initialWeather ?? HaruWeather.sun,
      initialText: initialText,
    ),
  );
  if (saved == true && context.mounted) HaruToast.show(context, '오늘의 일지를 저장했어요.');
  return saved == true;
}

class _ComposeBody extends StatefulWidget {
  const _ComposeBody({required this.title, required this.initialWeather, required this.initialText});

  final String title;
  final HaruWeather initialWeather;
  final String initialText;

  @override
  State<_ComposeBody> createState() => _ComposeBodyState();
}

class _ComposeBodyState extends State<_ComposeBody> {
  late HaruWeather _w = widget.initialWeather;
  late final _text = TextEditingController(text: widget.initialText);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await AuthedCall.run(
        (t) => ApiClient().upsertTodayDiary(accessToken: t, content: text, weather: _w.wire),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HaruToast.show(context, '일지를 저장하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.title),
        const SizedBox(height: 16),
        Text('오늘 나의 날씨', style: hr(14, color: HaruColors.forest)),
        const SizedBox(height: 8),
        WeatherPicker(value: _w, gap: 8, onPick: (w) => setState(() => _w = w)),
        const SizedBox(height: 16),
        Text('오늘의 일지', style: hr(14, color: HaruColors.forest)),
        const SizedBox(height: 8),
        HaruTextArea(
          controller: _text,
          placeholder: '오늘 하루는 어땠나요?',
          minHeight: 104,
          lineHeight: 1.45,
          borderColor: HaruColors.softGreen,
          borderWidth: 1.6,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: '저장하기',
          loading: _saving,
          onPressed: _text.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}
