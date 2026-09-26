import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/login_screen.dart';
import '../shell/home_shell.dart';
import 'temperature_screen.dart';

const _roles = ['아빠', '엄마', '아들', '딸'];
const _roleCodes = {'아빠': 'FATHER', '엄마': 'MOTHER', '아들': 'SON', '딸': 'DAUGHTER'};
const _orders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

/// 가족 탭 — family card, this month's participation, temperature, settings.
class FamilyTabScreen extends StatefulWidget {
  const FamilyTabScreen({super.key});

  @override
  State<FamilyTabScreen> createState() => _FamilyTabScreenState();
}

class _FamilyTabScreenState extends State<FamilyTabScreen> {
  final _api = ApiClient();
  FamilySnapshot? _fam;
  List<MemberParticipation>? _participation;
  FamilyTemperatureResult? _temp;
  bool _notify = true;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _error = false;
      _loading = _fam == null;
    });
    try {
      _fam = await FamilyContext.instance.refresh();
      final now = DateTime.now();
      final results = await Future.wait<Object?>([
        PendingApi.instance
            .fetchParticipation(year: now.year, month: now.month)
            .then<Object?>((v) => v)
            .catchError((_) => null),
        AuthedCall.run(_api.fetchFamilyTemperature).then<Object?>((v) => v).catchError((_) => null),
        AppPrefs.notificationsEnabled(),
      ]);
      if (!mounted) return;
      setState(() {
        _participation = results[0] as List<MemberParticipation>?;
        _temp = results[1] as FamilyTemperatureResult?;
        _notify = results[2]! as bool;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _fam == null;
        });
      }
    }
  }

  void _toast(String m, {IconData icon = LucideIcons.check}) => HaruToast.show(context, m, icon: icon);

  void _toastError(String m) => HaruToast.show(
        context,
        m,
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );

  Future<void> _copyCode() async {
    final code = _fam?.code ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast('가족 코드가 복사되었어요', icon: LucideIcons.copy);
  }

  String get _myShort => MemberLook.shortFor(_fam?.myRole ?? '');
  bool get _needBirth => _myShort == '아들' || _myShort == '딸';

  Future<void> _saveRole(String role, int? birthOrder) async {
    try {
      await AuthedCall.run((t) => _api.updateMyRole(
            accessToken: t,
            role: _roleCodes[role]!,
            birthOrder: birthOrder,
          ));
      await FamilyContext.instance.refresh();
      if (mounted) _toast('설정을 저장했어요');
    } catch (_) {
      if (mounted) _toastError('역할을 바꾸지 못했어요');
    }
  }

  Future<void> _pickRole() async {
    final i = await showHaruPicker(
      context,
      title: '나는 우리 가족의?',
      options: _roles,
      selected: _roles.indexOf(_myShort),
    );
    if (i == null || !mounted) return;
    final role = _roles[i];
    if (role == '아들' || role == '딸') {
      final keep = role == _myShort ? _fam?.myBirthOrder : null;
      final order = keep ?? await _pickBirth(role);
      if (order == null) return;
      await _saveRole(role, order);
    } else {
      await _saveRole(role, null);
    }
  }

  Future<int?> _pickBirth(String role) async {
    final current = _fam?.myBirthOrder;
    final i = await showHaruPicker(
      context,
      title: '몇째 $role인가요?',
      options: [for (final o in _orders) '$o $role'],
      selected: role == _myShort && current != null ? current - 1 : null,
    );
    return i == null ? null : i + 1;
  }

  Future<void> _changeBirth() async {
    final order = await _pickBirth(_myShort);
    if (order == null || !mounted) return;
    await _saveRole(_myShort, order);
  }

  Future<void> _renameFamily() async {
    final fam = _fam;
    if (fam == null) return;
    if (!fam.isCreator) {
      _toast('가족 이름은 가족을 만든 사람만 바꿀 수 있어요', icon: LucideIcons.lock);
      return;
    }
    final name = await showHaruInputDialog(
      context,
      title: '가족 이름 바꾸기',
      initialValue: fam.name,
      hint: '가족 이름',
      confirmLabel: '저장',
    );
    if (name == null || !mounted) return;
    try {
      await AuthedCall.run((t) => _api.updateFamilyName(accessToken: t, name: name));
      await FamilyContext.instance.refresh();
      if (mounted) _toast('가족 이름을 바꿨어요');
    } catch (_) {
      if (mounted) _toastError('가족 이름을 바꾸지 못했어요');
    }
  }

  Future<void> _toggleNotify(bool v) async {
    setState(() => _notify = v);
    try {
      await AppPrefs.setNotificationsEnabled(v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notify = !v);
      _toastError('알림 설정을 바꾸지 못했어요');
    }
  }

  void _goLogin(String? toast) {
    FamilyContext.instance.clear();
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    if (toast != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = nav.context;
        if (ctx.mounted) HaruToast.show(ctx, toast);
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showHaruConfirm(
      context,
      title: '로그아웃할까요?',
      body: '이 기기에서만 로그아웃돼요. 계정은 그대로 남아 있어요.',
      confirmLabel: '로그아웃',
    );
    if (!ok || !mounted) return;
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } catch (_) {}
    await TokenStorage().clear();
    if (mounted) _goLogin('로그아웃했어요');
  }

  Future<void> _deleteAccount() async {
    final step1 = await showHaruConfirm(
      context,
      title: '계정을 삭제할까요?',
      body: '삭제 후 30일 동안 데이터가 보관돼요.\n30일 안에 다시 로그인하면 복구할 수 있어요.',
      confirmLabel: '계속',
      danger: true,
    );
    if (!step1 || !mounted) return;
    final step2 = await showHaruConfirm(
      context,
      title: '정말 삭제할까요?',
      body: '30일이 지나면 내 답변과 일지가 모두 삭제돼요. 가족을 만든 사람이 탈퇴하면 30일 뒤 가족의 공동 데이터도 함께 삭제돼요.',
      confirmLabel: '계정 삭제',
      danger: true,
    );
    if (!step2 || !mounted) return;
    try {
      await AuthedCall.run(_api.deleteAccount);
      await TokenStorage().clear();
      if (mounted) _goLogin('계정 삭제를 예약했어요');
    } catch (_) {
      if (mounted) _toastError('계정을 삭제하지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HaruColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kTabBarClearance),
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('가족', style: HaruType.screenTitle),
                  ),
                ),
              ),
              if (_loading)
                const HaruSkeleton()
              else if (_error || _fam == null)
                HaruErrorState(onRetry: _load)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _content(_fam!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(FamilySnapshot fam) {
    final t = _temp;
    final d = t?.deltaFromYesterday ?? 0;
    return [
      _familyCard(fam),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
        child: Text('이번 달 참여', style: HaruType.sectionTitle),
      ),
      _participationGrid(fam),
      const SizedBox(height: 16),
      Pressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TemperatureScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(HaruRadius.xl),
            boxShadow: HaruShadows.s1,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HaruColors.streakTile,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.thermometerSun, size: 24, color: HaruColors.tempRiseText),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가족 온도', style: haruText(13, weight: FontWeight.w600, color: HaruColors.inkSecondary)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          t == null ? '–' : '${t.temperature.toStringAsFixed(1)}°C',
                          style: haruText(22, weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        if (t != null)
                          Text(
                            '${d >= 0 ? '+' : '−'}${d.abs().toStringAsFixed(1)}°',
                            style: haruText(
                              13,
                              weight: FontWeight.w700,
                              color: d >= 0 ? HaruColors.tempRiseText : HaruColors.tempDropText,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(t?.statusLabel ?? '', style: haruText(13, color: HaruColors.inkSecondary)),
              const SizedBox(width: 14),
              const Icon(LucideIcons.chevronRight, size: 18, color: HaruColors.inkSecondary),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
        child: Text('내 설정', style: HaruType.sectionTitle),
      ),
      _settingsCard(fam),
      const SizedBox(height: 12),
      _group([
        _row(
          leading: const Icon(LucideIcons.logOut, size: 18, color: HaruColors.inkSecondary),
          label: '로그아웃',
          onTap: _logout,
        ),
        _row(
          leading: const Icon(LucideIcons.userX, size: 18, color: HaruColors.statusAttention),
          label: '계정 삭제',
          labelColor: HaruColors.statusAttention,
          onTap: _deleteAccount,
        ),
      ]),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '탈퇴 후 30일 동안 데이터가 보관되고, 그 안에 다시 로그인하면 복구돼요. 가족을 만든 사람이 탈퇴하면 30일 뒤 가족 공동 데이터도 삭제돼요.',
          style: haruText(12, height: 1.5, color: HaruColors.inkSecondary),
        ),
      ),
    ];
  }

  Widget _familyCard(FamilySnapshot fam) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 52, child: ColoredBox(color: HaruColors.meadow)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // margin-top:-22px — the avatars overlap the meadow band and
                // only the remaining 28px take up layout space.
                SizedBox(
                  height: 50 - 22,
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    minWidth: 0,
                    maxHeight: 50,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: HaruAvatarStack(
                        overlap: 8,
                        itemSize: 50, // 44 + 3px ring each side
                        children: [
                          for (final m in fam.members)
                            HaruAvatar(
                              initial: m.initial,
                              tint: m.tint,
                              size: 44,
                              ringColor: Colors.white,
                              ringWidth: 3,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        fam.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: haruText(22, weight: FontWeight.w700, letterSpacing: -0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(fam.countText, style: haruText(14, color: HaruColors.inkSecondary)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: HaruColors.canvas,
                    borderRadius: BorderRadius.circular(HaruRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('가족 코드', style: haruText(12, weight: FontWeight.w600, color: HaruColors.inkSecondary)),
                            Text(fam.code, style: haruText(20, weight: FontWeight.w700, letterSpacing: 3)),
                          ],
                        ),
                      ),
                      HaruButton(
                        label: '복사',
                        icon: LucideIcons.copy,
                        variant: HaruButtonVariant.utility,
                        onPressed: _copyCode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final m in fam.members)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: HaruColors.hairline)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.label, style: haruText(15, weight: FontWeight.w500))),
                        if (m.isCreator) ...[
                          const HaruBadge('만든 사람', tone: HaruBadgeTone.neutral),
                          const SizedBox(width: 10),
                        ],
                        if (m.isMe) const HaruBadge('나'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _participationGrid(FamilySnapshot fam) {
    final rates = {for (final p in _participation ?? const <MemberParticipation>[]) p.userId: p.answerRate};
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < fam.members.length; i++)
            SizedBox(
              width: w,
              child: HaruRise(
                delay: Duration(milliseconds: 80 + i * 70),
                duration: const Duration(milliseconds: 450),
                child: _gaugeCard(fam.members[i], rates[fam.members[i].userId]),
              ),
            ),
        ],
      );
    });
  }

  Widget _gaugeCard(MemberLook m, int? pct) {
    final p = pct ?? 0;
    final low = pct != null && p < 70;
    final (String status, IconData icon) = switch (p) {
      _ when pct == null => ('준비 중', LucideIcons.minus),
      100 => ('빠짐없이 답해요', LucideIcons.star),
      >= 90 => ('꾸준해요', LucideIcons.check),
      >= 70 => ('잘 이어가요', LucideIcons.check),
      _ => ('조금 더 힘내요', LucideIcons.triangleAlert),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              HaruAvatar(initial: m.initial, tint: m.tint, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: haruText(14, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          HalfGauge(
            percent: p.toDouble(),
            color: low ? HaruColors.warn : HaruColors.house,
            label: pct == null ? '–' : '$p%',
            width: 96,
          ),
          const SizedBox(height: 10),
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: low ? HaruColors.warnPill : HaruColors.meadow,
              borderRadius: BorderRadius.circular(HaruRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: low ? HaruColors.warnText : HaruColors.positivePillText),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: haruText(
                    12,
                    weight: FontWeight.w600,
                    color: low ? HaruColors.warnText : HaruColors.positivePillText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(FamilySnapshot fam) {
    final value = haruText(15, color: HaruColors.inkSecondary);
    final chevron = const Icon(LucideIcons.chevronRight, size: 16, color: HaruColors.inkSecondary);
    final order = fam.myBirthOrder;
    return _group([
      _row(label: '나의 역할', trailing: [Text(_myShort, style: value), const SizedBox(width: 12), chevron], onTap: _pickRole),
      if (_needBirth)
        _row(
          label: '출생 순서',
          trailing: [
            Text(order == null ? '선택' : '${_orders[order - 1]} $_myShort', style: value),
            const SizedBox(width: 12),
            chevron,
          ],
          onTap: _changeBirth,
        ),
      _row(
        label: '가족 이름',
        trailing: [
          Flexible(child: Text(fam.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: value)),
          const SizedBox(width: 12),
          Icon(
            fam.isCreator ? LucideIcons.chevronRight : LucideIcons.lock,
            size: 16,
            color: HaruColors.inkSecondary,
          ),
        ],
        onTap: _renameFamily,
      ),
      _row(
        label: '질문 도착 알림',
        sub: _notify ? '매일 새 질문이 도착하면 알려 드려요' : '알림이 꺼져 있어요',
        trailing: [HaruSwitch(value: _notify, onChanged: _toggleNotify)],
      ),
    ]);
  }

  Widget _group(List<Widget> rows) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HaruRadius.xl),
          boxShadow: HaruShadows.s1,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: i == 0 ? Colors.transparent : HaruColors.hairline),
                  ),
                ),
                child: rows[i],
              ),
          ],
        ),
      );

  Widget _row({
    required String label,
    String? sub,
    Widget? leading,
    List<Widget> trailing = const [],
    Color labelColor = HaruColors.ink,
    VoidCallback? onTap,
  }) {
    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 12)],
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: sub == null ? 0 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: haruText(15, color: labelColor)),
                    if (sub != null) Text(sub, style: haruText(12, color: HaruColors.inkSecondary)),
                  ],
                ),
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }
}
