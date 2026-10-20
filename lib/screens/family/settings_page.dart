import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/app_prefs.dart';
import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/auth_scaffold.dart';
import '../login/login_screen.dart';
import '../login/policy_document_screen.dart';
import '../onboarding/family_select_screen.dart';
import '../shell/home_shell.dart';
import 'family_sheets.dart';

const _roleCodes = {'아빠': 'FATHER', '엄마': 'MOTHER', '아들': 'SON', '딸': 'DAUGHTER'};
const _orderWords = {1: '첫째', 2: '둘째', 3: '셋째', 4: '넷째', 5: '다섯째'};

/// 방해 금지 presets (label, start, end).
const _dndPresets = [
  ('오후 10:00 – 오전 7:00', '22:00', '07:00'),
  ('오후 11:00 – 오전 8:00', '23:00', '08:00'),
  ('자정 – 오전 6:00', '00:00', '06:00'),
];

/// 설정 — 가족 탭의 ⚙에서 열려요: 사용 편의 · 알림 · 가족 · 도움 · 계정.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiClient();
  FamilySnapshot? _fam;
  NotificationSettings _notif = const NotificationSettings();

  @override
  void initState() {
    super.initState();
    _fam = FamilyContext.instance.value;
    FamilyContext.instance.addListener(_onFamily);
    _load();
  }

  @override
  void dispose() {
    FamilyContext.instance.removeListener(_onFamily);
    super.dispose();
  }

  void _onFamily() {
    if (mounted) setState(() => _fam = FamilyContext.instance.value);
  }

  Future<void> _load() async {
    try {
      final n = await PendingApi.instance.fetchNotificationSettings();
      if (mounted) setState(() => _notif = n);
    } catch (_) {}
  }

  Future<void> _renameFamily() async {
    final fam = _fam;
    if (fam == null || !fam.isCreator) return;
    final name = await showHaruInputDialog(
      context,
      title: '가족 이름 바꾸기',
      placeholder: '예: 하루',
      okLabel: '저장',
      initial: fam.name,
      maxLength: 10,
    );
    if (name == null || !mounted) return;
    try {
      await AuthedCall.run((t) => _api.updateFamilyName(accessToken: t, name: name));
      await FamilyContext.instance.refresh();
      if (mounted) HaruToast.show(context, '가족 이름을 바꿨어요.');
    } catch (_) {
      if (mounted) HaruToast.show(context, '가족 이름을 바꾸지 못했어요.');
    }
  }

  Future<void> _changeRole() async {
    final fam = _fam;
    final current = MemberLook.roleFor(fam?.myRole ?? '');
    final picked = await showRoleSheet(
      context,
      role: _roleCodes.containsKey(current) ? current : null,
      birthOrder: fam?.myBirthOrder,
    );
    if (picked == null || !mounted) return;
    final (role, order) = picked;
    try {
      await AuthedCall.run((t) => _api.updateMyRole(accessToken: t, role: _roleCodes[role]!, birthOrder: order));
      await FamilyContext.instance.refresh();
      if (mounted) HaruToast.show(context, '나의 역할을 바꿨어요.');
    } catch (_) {
      if (mounted) HaruToast.show(context, '역할을 바꾸지 못했어요.');
    }
  }

  Future<void> _setNotif(NotificationSettings next, String? toast) async {
    final prev = _notif;
    setState(() => _notif = next);
    try {
      final saved = await PendingApi.instance.updateNotificationSettings(next);
      await AppPrefs.setNotificationsEnabled(saved.anyOn);
      if (!mounted) return;
      setState(() => _notif = saved);
      if (toast != null) HaruToast.show(context, toast);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notif = prev);
      HaruToast.show(context, '알림 설정을 바꾸지 못했어요.');
    }
  }

  int get _dndIndex {
    final i = _dndPresets.indexWhere((p) => p.$2 == _notif.dndStart && p.$3 == _notif.dndEnd);
    return i < 0 ? 0 : i;
  }

  void _toggleDnd() {
    final on = !_notif.dndEnabled;
    final p = _dndPresets[_dndIndex];
    _setNotif(
      _notif.copyWith(dndEnabled: on, dndStart: p.$2, dndEnd: p.$3),
      on ? '${p.$1}에는 알림을 보내지 않아요.' : '방해 금지를 껐어요.',
    );
  }

  /// Tapping the time label: turns 방해 금지 on, or steps to the next preset
  /// (no toast either way).
  void _cycleDnd() {
    if (!_notif.dndEnabled) {
      final p = _dndPresets[_dndIndex];
      _setNotif(_notif.copyWith(dndEnabled: true, dndStart: p.$2, dndEnd: p.$3), null);
      return;
    }
    final p = _dndPresets[(_dndIndex + 1) % _dndPresets.length];
    _setNotif(_notif.copyWith(dndStart: p.$2, dndEnd: p.$3), null);
  }

  void _goTo(Widget page, String? toast) {
    FamilyContext.instance.clear();
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pushAndRemoveUntil(flowRoute<void>(page), (_) => false);
    if (toast != null) HaruToast.show(nav.context, toast);
  }

  Future<void> _leave() async {
    final fam = _fam;
    final name = fam == null ? '우리' : fam.name;
    final ok = await showHaruConfirm(
      context,
      title: '가족을 나갈까요?',
      body: '나가면 $name 가족의 편지와 답장, 사진을 더 볼 수 없어요. 다시 들어오려면 가족 코드가 필요해요.',
      okLabel: '나가기',
    );
    if (!ok || !mounted) return;
    try {
      await PendingApi.instance.leaveFamily();
      await TokenStorage().clearFamilyProfile();
      if (mounted) _goTo(const FamilySelectScreen(), '$name 가족에서 나왔어요.');
    } on FeatureNotReadyException catch (e) {
      if (mounted) HaruToast.show(context, e.message);
    } catch (_) {
      if (mounted) HaruToast.show(context, '가족을 나가지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _logout() async {
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } catch (_) {}
    await TokenStorage().clear();
    if (mounted) _goTo(const LoginScreen(), '로그아웃했어요.');
  }

  Future<void> _deleteAccount() async {
    final step1 = await showHaruConfirm(
      context,
      title: '계정을 삭제할까요?',
      body: '삭제 후 30일 동안 데이터가 보관돼요. 30일 안에 다시 로그인하면 복구할 수 있어요.',
      okLabel: '계속',
    );
    if (!step1 || !mounted) return;
    final step2 = await showHaruConfirm(
      context,
      title: '정말 삭제할까요?',
      body: '30일이 지나면 내 답변과 일지가 모두 삭제돼요. 가족을 만든 사람이 탈퇴하면 30일 뒤 가족의 공동 데이터도 함께 삭제돼요.',
      okLabel: '계정 삭제',
    );
    if (!step2 || !mounted) return;
    try {
      await AuthedCall.run(_api.deleteAccount);
      try {
        await PushNotificationService.instance.unregisterCurrentDevice();
      } catch (_) {}
      await TokenStorage().clear();
      if (mounted) _goTo(const LoginScreen(), '계정 삭제를 예약했어요.');
    } catch (_) {
      if (mounted) HaruToast.show(context, '계정을 삭제하지 못했어요.');
    }
  }

  void _policy(String title, String asset) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PolicyDocumentScreen(title: title, assetPath: asset)),
      );

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, kNavClearance),
        children: [
          // The 설정 back button has no style-active and no transition.
          const SubHeader(title: '설정', backScale: 1, backDuration: Duration.zero, backInlineTransition: false),
          const SectionCaption(icon: Symbols.tune_rounded, label: '사용 편의', top: 8),
          _fontCard(),
          const SizedBox(height: 10),
          _notifCard(),
          const SectionCaption(icon: Symbols.groups_rounded, label: '가족'),
          _familyMenu(_fam),
          const SectionCaption(icon: Symbols.help_rounded, label: '도움 · 계정'),
          _helpMenu(),
        ],
      ),
    );
  }

  Widget _fontCard() {
    return ValueListenableBuilder<int>(
      valueListenable: AppPrefs.fontSize,
      builder: (context, fs, _) => HrCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('글자 크기', style: hr(16))),
                Text(const ['작게', '보통', '크게', '아주 크게'][fs], style: hr(14.5, color: HaruColors.inkMuted)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: HaruColors.cream,
                border: Border.all(color: HaruColors.hairline),
                borderRadius: BorderRadius.circular(HaruRadius.full),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Pressable(
                        onTap: () => AppPrefs.setFontSize(i),
                        scale: .94,
                        duration: Duration.zero,
                        semanticLabel: const ['작게', '보통', '크게', '아주 크게'][i],
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.ease,
                          height: 34,
                          decoration: BoxDecoration(
                            color: fs == i ? HaruColors.forest : Colors.transparent,
                            borderRadius: BorderRadius.circular(HaruRadius.full),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '가',
                            style: hr(const [13.0, 15.0, 17.0, 19.0][i], color: fs == i ? Colors.white : HaruColors.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            DashedBox(
              color: HaruColors.fieldBorder,
              radius: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: HaruColors.cream, borderRadius: BorderRadius.circular(12)),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                  style: hrQuestion(const [14.0, 16.0, 18.0, 20.0][fs], height: 1.45),
                  child: const Text('요즘 가족에게 가장 고마웠던 순간은 언제였나요?'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifCard() {
    final n = _notif;
    final rows = [
      (Symbols.mail_rounded, '오늘의 질문 도착', '매일 03:00', n.questionArrived,
          (bool v) => n.copyWith(questionArrived: v)),
      (Symbols.chat_bubble_rounded, '가족 답장', '가족이 답장을 남기면', n.answerPosted,
          (bool v) => n.copyWith(answerPosted: v)),
      (Symbols.device_thermostat_rounded, '가족 온도 변화', '매일 02:50 결과', n.temperatureChanged,
          (bool v) => n.copyWith(temperatureChanged: v)),
      (Symbols.photo_library_rounded, '일지 · 앨범 소식', '새 일지나 사진이 올라오면', n.diaryAlbum,
          (bool v) => n.copyWith(diaryAlbum: v)),
    ];
    final dnd = _dndPresets[_dndIndex];
    return HrCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
            child: Text('알림 받기', style: hr(14.5, color: HaruColors.inkMuted)),
          ),
          for (final (icon, label, sub, on, next) in rows)
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HaruColors.hairline))),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: HaruColors.softGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: hr(16)),
                        Text(sub, style: hr(13.5, color: HaruColors.inkMuted)),
                      ],
                    ),
                  ),
                  HaruSwitch(
                    value: on,
                    label: label,
                    onChanged: (v) => _setNotif(next(v), '$label 알림을 ${v ? '켰어요.' : '껐어요.'}'),
                  ),
                ],
              ),
            ),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                const Icon(Symbols.bedtime_rounded, size: 20, color: HaruColors.softGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('방해 금지 시간', style: hr(16)),
                      Pressable(
                        onTap: _cycleDnd,
                        scale: .96,
                        duration: Duration.zero,
                        inlineTransition: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              n.dndEnabled ? dnd.$1 : '꺼져 있어요',
                              style: hr(14, color: n.dndEnabled ? HaruColors.forest : HaruColors.inkMuted),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Symbols.expand_more_rounded,
                              size: 14,
                              color: n.dndEnabled ? HaruColors.forest : HaruColors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                HaruSwitch(value: n.dndEnabled, label: '방해 금지 시간', onChanged: (_) => _toggleDnd()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyMenu(FamilySnapshot? fam) {
    final me = fam?.me;
    final order = fam?.myBirthOrder;
    final roleText = me == null
        ? ''
        : order == null || (me.role != '아들' && me.role != '딸')
            ? me.role
            : '${me.role} · ${_orderWords[order] ?? ''}';
    return HrCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          MenuRow(
            icon: Symbols.person_add_rounded,
            label: '가족 초대하기',
            trailing: Text('코드 · QR', style: hr(14.5, color: HaruColors.inkMuted)),
            onTap: fam == null ? null : () => showInviteSheet(context, fam),
          ),
          MenuRow(
            icon: Symbols.manage_accounts_rounded,
            label: '구성원 관리',
            trailing: fam != null && !fam.isCreator
                ? const Icon(Symbols.lock_rounded, size: 16, color: HaruColors.inkFaint)
                : null,
            onTap: fam == null ? null : () => showMembersSheet(context, fam: fam, onRename: _renameFamily),
          ),
          MenuRow(
            icon: Symbols.badge_rounded,
            label: '나의 역할',
            trailing: Text(roleText, style: hrHand(16)),
            onTap: _changeRole,
          ),
          MenuRow(
            icon: Symbols.logout_rounded,
            label: '가족 나가기',
            color: HaruColors.danger,
            iconColor: HaruColors.danger,
            chevron: false,
            last: true,
            onTap: _leave,
          ),
        ],
      ),
    );
  }

  Widget _helpMenu() {
    return HrCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          MenuRow(icon: Symbols.mail_rounded, label: '문의하기 · 의견 보내기', onTap: () => showInquirySheet(context)),
          MenuRow(icon: Symbols.auto_stories_rounded, label: '사용 방법 다시 보기', onTap: () => showGuideSheet(context)),
          MenuRow(
            icon: Symbols.description_rounded,
            label: '이용약관',
            onTap: () => _policy('이용약관', PolicyDocumentScreen.termsAsset),
          ),
          MenuRow(
            icon: Symbols.shield_person_rounded,
            label: '개인정보처리방침',
            onTap: () => _policy('개인정보처리방침', PolicyDocumentScreen.privacyAsset),
          ),
          MenuRow(
            icon: Symbols.power_settings_new_rounded,
            label: '로그아웃',
            color: HaruColors.inkMuted,
            iconColor: HaruColors.inkMuted,
            chevron: false,
            onTap: _logout,
          ),
          // Not in the mockup; the App Store requires in-app account deletion.
          MenuRow(
            icon: Symbols.person_remove_rounded,
            label: '계정 삭제',
            color: HaruColors.danger,
            iconColor: HaruColors.danger,
            chevron: false,
            last: true,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
