import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../onboarding/family_done_screens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 가족 초대하기
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showInviteSheet(BuildContext context, FamilySnapshot fam) {
  return showHaruSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('가족 초대하기', subtitle: '가족에게 코드를 보내거나 QR을 보여주세요'),
        const SizedBox(height: 16),
        Center(
          child: Entrance(
            kind: EntranceKind.popIn,
            duration: const Duration(milliseconds: 360),
            child: Container(
              // 168 + 1px border each side (content-box in the prototype).
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: HaruColors.ivory,
                border: Border.all(color: HaruColors.hairline),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: QrImageView(
                data: inviteMessage(fam.name, fam.code),
                size: 128,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: HaruColors.forest),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: HaruColors.forest,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(fam.code, textAlign: TextAlign.center, style: hrHand(32, letterSpacing: 2)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: CopyCodeButton(
                code: fam.code,
                height: 46,
                fontSize: 16,
                iconSize: 18,
                pressScale: .96,
                pressDuration: Duration.zero,
              )),
            const SizedBox(width: 8),
            Expanded(
              child: Builder(
                builder: (bctx) => Pressable(
                  onTap: () => shareInvite(bctx, fam.name, fam.code, '초대 링크를 보냈어요.'),
                  scale: .96,
                  duration: Duration.zero,
                  inlineTransition: false,
                  semanticLabel: '초대 링크 보내기',
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(color: HaruColors.cta, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.share_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('초대 링크 보내기', style: hr(16, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 구성원 관리
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showMembersSheet(
  BuildContext context, {
  required FamilySnapshot fam,
  required Future<void> Function() onRename,
}) {
  return showHaruSheet<void>(
    context,
    builder: (ctx) => _MembersSheet(fam: fam, onRename: onRename),
  );
}

class _MembersSheet extends StatefulWidget {
  const _MembersSheet({required this.fam, required this.onRename});

  final FamilySnapshot fam;
  final Future<void> Function() onRename;

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  late List<MemberLook> _members = widget.fam.members;

  Future<void> _kick(MemberLook m) async {
    final ok = await showHaruConfirm(
      context,
      title: '${m.label}님을 내보낼까요?',
      body: '내보내면 이 가족의 편지를 더 받지 않아요. 남긴 답장은 그대로 남아요.',
      okLabel: '내보내기',
    );
    if (!ok || !mounted) return;
    try {
      await PendingApi.instance.removeMember(m.userId);
      if (!mounted) return;
      setState(() => _members = _members.where((x) => x.userId != m.userId).toList());
      HaruToast.show(context, '${m.label}님을 내보냈어요.');
      FamilyContext.instance.refresh().ignore();
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message);
    } catch (_) {
      if (mounted) HaruToast.show(context, '내보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final creator = widget.fam.isCreator;
    final owner = _members.where((m) => m.isCreator).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('구성원 관리'),
        if (!creator) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.lock_rounded, size: 15, color: HaruColors.inkFaint),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  owner == null ? '가족을 만든 사람만 구성원을 관리할 수 있어요' : '가족을 만든 ${owner.label}만 구성원을 관리할 수 있어요',
                  style: hr(15, color: HaruColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (creator) ...[
          // App-only row; pressed like the 설정 rows (scale .96 +
          // brightness .96, no transition).
          Pressable(
            onTap: () async {
              Navigator.of(context).pop();
              await widget.onRename();
            },
            scale: .96,
            duration: Duration.zero,
            inlineTransition: false,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: HaruColors.ivory,
                border: Border.all(color: HaruColors.hairline),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.edit_rounded, size: 20, color: HaruColors.softGreen),
                  const SizedBox(width: 10),
                  Expanded(child: Text('가족 이름 바꾸기', style: hr(16))),
                  Text(widget.fam.name, style: hrHand(16)),
                  const SizedBox(width: 6),
                  const Icon(Symbols.chevron_right_rounded, size: 18, color: HaruColors.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < _members.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _members.length - 1 ? 0 : 8),
            child: Entrance(
              kind: EntranceKind.riseIn,
              duration: const Duration(milliseconds: 400),
              delay: stagger(i, 50),
              child: Container(
                height: 58, // 56 + 1px border each side
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: HaruColors.ivory,
                  border: Border.all(color: HaruColors.hairline),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    MemberAvatar(member: _members[i], size: 34, fontSize: 14.5, hand: true),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_members[i].displayName, style: hrHand(18))),
                    if (_members[i].isCreator) ...[
                      const SizedBox(width: 10),
                      Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: HaruColors.mint,
                          borderRadius: BorderRadius.circular(HaruRadius.full),
                        ),
                        alignment: Alignment.center,
                        child: Text('만든 사람', style: hr(13.5, color: HaruColors.forest)),
                      ),
                    ],
                    if (creator && !_members[i].isCreator && !_members[i].isMe) ...[
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () => _kick(_members[i]),
                        scale: .94,
                        duration: Duration.zero,
                        inlineTransition: false,
                        child: Container(
                          height: 32, // 30 + 1px border each side
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: HaruColors.dangerBorder),
                            borderRadius: BorderRadius.circular(HaruRadius.full),
                          ),
                          alignment: Alignment.center,
                          child: Text('내보내기', style: hr(14.5, color: HaruColors.danger)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 문의하기 · 의견 보내기
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showInquirySheet(BuildContext context) {
  return showHaruSheet<void>(context, builder: (_) => const _InquirySheet());
}

class _InquirySheet extends StatefulWidget {
  const _InquirySheet();

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  final _text = TextEditingController();
  InquiryCategory _cat = InquiryCategory.questionAnswer;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await PendingApi.instance.sendInquiry(category: _cat, content: content);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      HaruToast.show(nav.context, '문의를 보냈어요. 이메일로 답장드릴게요.');
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message);
    } catch (_) {
      if (mounted) HaruToast.show(context, '문의를 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('문의하기 · 의견 보내기', subtitle: '보내주신 내용은 가입한 이메일로 답장드려요'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in InquiryCategory.values)
              _CategoryChip(label: c.label, selected: _cat == c, onTap: () => setState(() => _cat = c)),
          ],
        ),
        const SizedBox(height: 12),
        HaruTextArea(
          controller: _text,
          placeholder: '불편했던 점이나 바라는 점을 편하게 적어 주세요.',
          minHeight: 130,
          fixedHeight: true,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: '보내기', loading: _sending, onPressed: _text.text.trim().isEmpty ? null : _send),
      ],
    );
  }
}

/// Category pill: 34 tall, padding 0 13, 1.4 border, `transition: background
/// 200ms`, pressed scale .94.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .94,
      duration: Duration.zero,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        height: 36.8, // 34 + 1.4px border each side
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? HaruColors.forest : HaruColors.ivory,
          borderRadius: BorderRadius.circular(HaruRadius.full),
          border: Border.all(color: selected ? HaruColors.forest : HaruColors.fieldBorder, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label, style: hr(14.5, color: selected ? Colors.white : HaruColors.forest))],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 사용 방법 다시 보기
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showGuideSheet(BuildContext context) {
  return showHaruSheet<void>(context, builder: (_) => const _GuideSheet());
}

class _GuideSheet extends StatefulWidget {
  const _GuideSheet();

  @override
  State<_GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<_GuideSheet> {
  int _step = 0;

  static const _steps = [
    (Symbols.mail_rounded, HaruColors.mint, '매일 03:00, 편지가 도착해요', '하루에 하나씩 우리 가족에게 질문이 담긴 편지가 와요.'),
    (Symbols.flip_rounded, HaruColors.orange, '편지를 뒤집어 답장해요', '편지를 탭하거나 옆으로 넘기면 뒷면에 바로 답장을 쓸 수 있어요.'),
    (Symbols.device_thermostat_rounded, HaruColors.yellow, '가족 온도가 올라가요', '가족이 함께 답할수록 우리 가족의 마음 온도가 따뜻해져요.'),
    (Symbols.photo_library_rounded, HaruColors.lavender, '기록과 앨범에 모여요', '지난 답장과 사진, 일지는 기록·앨범 탭에서 언제든 다시 볼 수 있어요.'),
  ];

  @override
  Widget build(BuildContext context) {
    final (icon, bg, title, body) = _steps[_step];
    final last = _step == _steps.length - 1;
    // min-height 330 with a flex:1 spacer above the dots. The entrances run
    // once when the sheet opens; later steps just swap content.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 330),
      child: IntrinsicHeight(
        child: Column(
          children: [
            Text('${_step + 1} / ${_steps.length}', style: hr(14.5, color: HaruColors.inkMuted)),
            const SizedBox(height: 14),
            Entrance(
              kind: EntranceKind.pop,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
                child: Icon(icon, size: 60, color: HaruColors.forest),
              ),
            ),
            const SizedBox(height: 18),
            Entrance(
              kind: EntranceKind.riseIn,
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 80),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: hr(22, color: HaruColors.forest),
              ),
            ),
            const SizedBox(height: 8),
            Entrance(
              kind: EntranceKind.riseIn,
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 140),
              child: Text(body, textAlign: TextAlign.center, style: hr(15.5, height: 1.55)),
            ),
            const Spacer(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.ease,
                    width: i == _step ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _step ? HaruColors.forest : HaruColors.lineGrey,
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: last ? '시작하기' : '다음',
              onPressed: () => last ? Navigator.of(context).pop() : setState(() => _step++),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 나의 역할
// ─────────────────────────────────────────────────────────────────────────────

const _roles = ['아빠', '엄마', '아들', '딸'];
const _orders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

/// Returns (role word, birthOrder 1…5 or null) or null when dismissed.
Future<(String, int?)?> showRoleSheet(BuildContext context, {String? role, int? birthOrder}) {
  return showHaruSheet<(String, int?)>(
    context,
    builder: (_) => _RoleSheet(role: role, birthOrder: birthOrder),
  );
}

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.role, required this.birthOrder});

  final String? role;
  final int? birthOrder;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late String? _role = widget.role;
  late int? _order = widget.birthOrder;

  bool get _needOrder => _role == '아들' || _role == '딸';
  bool get _valid => _role != null && (!_needOrder || _order != null);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('나의 역할'),
        const SizedBox(height: 16),
        Text('나는 우리 가족의?', style: HaruType.fieldLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _roles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: ChoiceChipBox(
                  height: 48.8, // 46 + 1.4px border each side
                  label: _roles[i],
                  selected: _role == _roles[i],
                  onTap: () => setState(() {
                    if (_role != _roles[i]) _order = null;
                    _role = _roles[i];
                  }),
                ),
              ),
            ],
          ],
        ),
        if (_needOrder) ...[
          const SizedBox(height: 18),
          Text('몇째인가요?', style: HaruType.fieldLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _orders.length; i++)
                ChoiceChipBox(
                  label: _orders[i],
                  selected: _order == i + 1,
                  height: 40.8, // 38 + 1.4px border each side
                  animateBackground: false,
                  pressScale: .95,
                  pressDuration: const Duration(milliseconds: 200),
                  radius: HaruRadius.full,
                  fontSize: 15,
                  expand: false,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onTap: () => setState(() => _order = i + 1),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        PrimaryButton(
          label: '저장하기',
          onPressed: _valid ? () => Navigator.of(context).pop((_role!, _needOrder ? _order : null)) : null,
        ),
      ],
    );
  }
}
