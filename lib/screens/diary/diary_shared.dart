import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
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

  HaruWeather? get composite => HaruWeather.mode(members.map((m) => m.weather));

  static Future<DiaryDayView> load(DateTime date) async {
    final fam = await FamilyContext.instance.ensure();
    final day = await AuthedCall.run(
      (t) => ApiClient().fetchDiaryDay(accessToken: t, date: date),
    );
    return fromResult(fam, day);
  }

  static DiaryDayView fromResult(FamilySnapshot fam, DiaryDayResult day) {
    MemberLook lookFor(int userId, String roleLabel, bool isMe) =>
        fam.byUserId(userId) ??
        MemberLook(
          userId: userId,
          label: roleLabel,
          short: roleLabel,
          initial: MemberLook.initialFor(roleLabel, isMe),
          tint: HaruColors.accentTeal,
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
        for (final e in day.entries)
          (member: lookFor(e.userId, e.roleLabel, e.isMe), entry: e),
      ],
      myEntry: day.myEntry,
    );
  }
}

/// 4-column grid of member weather tiles (그날의 일지 / 일지 탭).
/// For today, *my* empty tile becomes a "+" that opens the composer.
class MembersWeatherGrid extends StatelessWidget {
  const MembersWeatherGrid({
    super.key,
    required this.members,
    required this.isToday,
    this.onAddMine,
  });

  final List<MemberWeather> members;
  final bool isToday;
  final VoidCallback? onAddMine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 6 * 3) / 4;
      return Wrap(
        spacing: 6,
        runSpacing: 10,
        children: [
          for (final mw in members)
            SizedBox(
              width: w,
              child: _MemberTile(
                mw: mw,
                canAdd: isToday && mw.member.isMe && mw.weather == null,
                onAdd: onAddMine,
              ),
            ),
        ],
      );
    });
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.mw, required this.canAdd, this.onAdd});

  final MemberWeather mw;
  final bool canAdd;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tile = WeatherTile(
      weather: mw.weather,
      size: 46,
      radius: 14,
      iconSize: 20,
      emptyIcon: canAdd ? LucideIcons.plus : LucideIcons.minus,
      emptyIconColor: canAdd ? HaruColors.primary : HaruColors.dsInkFaint,
    );
    final col = Column(
      children: [
        tile,
        const SizedBox(height: 6),
        Text(mw.member.short, style: haruText(12, color: HaruColors.inkSecondary)),
      ],
    );
    return canAdd ? Pressable(onTap: onAdd, child: col) : col;
  }
}

/// One diary entry card.
class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({super.key, required this.member, required this.entry});

  final MemberLook member;
  final DiaryEntryResult entry;

  @override
  Widget build(BuildContext context) {
    final w = HaruWeather.fromWire(entry.weather);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HaruAvatar(initial: member.initial, tint: member.tint, size: 24),
              const SizedBox(width: 8),
              Text(member.label, style: haruText(14, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(w?.icon ?? LucideIcons.minus, size: 16, color: HaruColors.inkSecondary),
              const Spacer(),
              Text(ampmTime(entry.createdAt.toLocal()), style: haruText(12, color: HaruColors.inkSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(entry.content, style: haruText(15, height: 1.6)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 오늘의 일지 작성 시트
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true when saved.
Future<bool> showDiaryComposeSheet(
  BuildContext context, {
  HaruWeather? initialWeather,
  String initialText = '',
}) async {
  final saved = await showHaruSheet<bool>(
    context,
    title: '오늘의 일지',
    builder: (_) => _ComposeBody(initialWeather: initialWeather, initialText: initialText),
  );
  if (saved == true && context.mounted) {
    HaruToast.show(context, '오늘의 일지를 저장했어요');
  }
  return saved == true;
}

class _ComposeBody extends StatefulWidget {
  const _ComposeBody({required this.initialWeather, required this.initialText});

  final HaruWeather? initialWeather;
  final String initialText;

  @override
  State<_ComposeBody> createState() => _ComposeBodyState();
}

class _ComposeBodyState extends State<_ComposeBody> {
  late HaruWeather? _w = widget.initialWeather;
  late final _text = TextEditingController(text: widget.initialText);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final w = _w;
    final text = _text.text.trim();
    if (w == null || text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await AuthedCall.run(
        (t) => ApiClient().upsertTodayDiary(accessToken: t, content: text, weather: w.wire),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HaruToast.show(
        context,
        '일지를 저장하지 못했어요. 다시 시도해 주세요.',
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
        bottom: 40,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _w == null || _text.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -12),
          child: Text(
            '하루에 하나만 남길 수 있어요. 다시 쓰면 수정돼요.',
            style: haruText(14, color: HaruColors.dsInkMuted),
          ),
        ),
        const SizedBox(height: 6),
        Text('오늘의 날씨', style: HaruType.fieldLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final w in HaruWeather.values) ...[
              if (w != HaruWeather.values.first) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _w = w),
                  child: Column(
                    children: [
                      AnimatedScale(
                        scale: _w == w ? 1.08 : 1,
                        duration: HaruMotion.base,
                        child: AnimatedContainer(
                          duration: HaruMotion.base,
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: w.tint,
                            borderRadius: BorderRadius.circular(HaruRadius.lg),
                            boxShadow: _w == w
                                ? const [
                                    BoxShadow(color: HaruColors.primary, spreadRadius: 4),
                                    BoxShadow(color: HaruColors.canvas, spreadRadius: 2),
                                  ]
                                : null,
                          ),
                          child: Icon(w.icon, size: 24, color: HaruColors.dsInkSecondary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        w.label,
                        maxLines: 1,
                        style: haruText(
                          12,
                          weight: _w == w ? FontWeight.w600 : FontWeight.w400,
                          color: _w == w ? HaruColors.dsInk : HaruColors.dsInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Text('오늘의 일지', style: HaruType.fieldLabel),
        const SizedBox(height: 8),
        HaruTextField(
          controller: _text,
          hint: '오늘 가족과 나눈 하루를 적어 보세요.',
          height: null,
          maxLines: 5,
          minLines: 5,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        HaruButton(
          label: '저장하기',
          size: HaruButtonSize.lg,
          fullWidth: true,
          loading: _saving,
          onPressed: invalid ? null : _save,
        ),
      ],
    );
  }
}
