import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/app_settings.dart';
import 'package:hrhb_frontend/services/family_service.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/modal_branch_decor.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../login/login_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _mint = Color(0xFF57C17D);
const _meadow = Color(0xFFE8F5E6);
const _cardBg = Color(0xFFFFFCF3);
const _buttonGreen = Color(0xFF3CB371);
const _danger = Color(0xFFD96050);
const _hairline = Color(0xFFE8E4D8);

/// renewal 가족 탭의 가족 카드 + 내 설정 (이번 달 참여·온도 제외).
/// 나뭇가지 배경 모달.
class FamilySettingsSheet extends StatefulWidget {
  const FamilySettingsSheet({
    super.key,
    required this.familyName,
    this.currentRole = '',
    this.isFamilyCreator,
  });

  final String familyName;
  final String currentRole;
  final bool? isFamilyCreator;

  static Future<bool> show(
    BuildContext context, {
    required String familyName,
    String currentRole = '',
    bool? isFamilyCreator,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => FamilySettingsSheet(
        familyName: familyName,
        currentRole: currentRole,
        isFamilyCreator: isFamilyCreator,
      ),
    );
    return result == true;
  }

  @override
  State<FamilySettingsSheet> createState() => _FamilySettingsSheetState();
}

class _FamilySettingsSheetState extends State<FamilySettingsSheet> {
  static const _roles = ['할아버지', '할머니', '아빠', '엄마', '아들', '딸'];
  static const _birthOrders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

  final _api = ApiClient();
  final _tokens = TokenStorage();
  final _familyService = FamilyService();

  late final TextEditingController _nameController;
  late String? _role;
  String? _birthOrder;
  bool? _isFamilyCreator;
  bool _notificationsOn = true;
  bool _largeText = false;
  bool _loadingFamily = true;
  String? _familyError;
  MyFamilyResult? _family;
  bool _saving = false;
  bool _loggingOut = false;
  bool _deleting = false;

  bool get _needsBirthOrder => _role == '아들' || _role == '딸';
  bool get _canEditFamilyName => _isFamilyCreator == true;

  List<String> get _birthOrderOptions {
    if (_role == '아들') {
      return _birthOrders.map((o) => '$o 아들').toList();
    }
    if (_role == '딸') {
      return _birthOrders.map((o) => '$o 딸').toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.familyName);
    _isFamilyCreator = widget.isFamilyCreator;
    _largeText = AppSettings.instance.largeText;

    final role = widget.currentRole;
    if (_roles.contains(role)) {
      _role = role;
    } else if (role.contains('아들')) {
      _role = '아들';
      _birthOrder = role;
    } else if (role.contains('딸')) {
      _role = '딸';
      _birthOrder = role;
    } else {
      _role = role.isEmpty ? null : role;
    }

    _loadFamily();
    _loadCreatorIfNeeded();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    var access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      return await action(access);
    } on ApiException catch (e) {
      if (!(e.statusCode == 401 ||
          e.statusCode == 403 ||
          e.message.contains('(401)') ||
          e.message.contains('(403)'))) {
        rethrow;
      }
      final refresh = await _tokens.readRefreshToken();
      final userId = await _tokens.readUserId();
      if (refresh == null || userId == null) rethrow;
      final pair = await _api.refresh(refresh);
      await _tokens.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return action(pair.accessToken);
    }
  }

  Future<void> _loadFamily() async {
    setState(() {
      _loadingFamily = true;
      _familyError = null;
    });
    try {
      final profile = await _tokens.readFamilyProfile();
      final cached = await _tokens.readFamilyMembers();
      if (profile != null && cached.isNotEmpty && mounted) {
        setState(() {
          _family = MyFamilyResult(
            familyId: 0,
            familyName: profile.familyName,
            inviteCode: profile.familyCode,
            members: cached,
          );
          _nameController.text = profile.familyName;
          _isFamilyCreator ??= profile.isFamilyCreator;
          _loadingFamily = false;
        });
      }

      final family = await _withAuth(_api.fetchMyFamily);
      await _tokens.saveFamilyMembers(family.members);
      var myRoleLabel = profile?.myRoleLabel ?? '';
      for (final m in family.members) {
        if (m.isMe) {
          myRoleLabel = m.roleLabel;
          break;
        }
      }
      await _tokens.saveFamilyProfile(
        familyName: family.familyName,
        familyCode: family.inviteCode,
        myRoleLabel: myRoleLabel,
        isFamilyCreator: profile?.isFamilyCreator ?? _isFamilyCreator ?? false,
      );
      if (!mounted) return;
      setState(() {
        _family = family;
        _nameController.text = family.familyName;
        _loadingFamily = false;
        _familyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_family != null) {
        setState(() => _loadingFamily = false);
        return;
      }
      setState(() {
        _familyError = e.toString();
        _loadingFamily = false;
      });
    }
  }

  Future<void> _loadCreatorIfNeeded() async {
    if (_isFamilyCreator != null) return;
    final profile = await _tokens.readFamilyProfile();
    if (!mounted) return;
    if (profile != null) {
      setState(() => _isFamilyCreator = profile.isFamilyCreator);
      return;
    }
    try {
      final me = await _withAuth(_api.fetchMe);
      if (!mounted) return;
      setState(() => _isFamilyCreator = me.isFamilyCreator ?? false);
    } catch (_) {}
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _toast('가족 코드가 복사되었어요.');
  }

  Future<String?> _pickOption({
    required String title,
    required List<String> options,
    required String? current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: 18,
                    color: _titleGreen,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: option == current ? _mint : _bodyGrey,
                      fontWeight:
                          option == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: option == current
                      ? const Icon(Icons.check_rounded, color: _mint)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (_canEditFamilyName && name.isEmpty) {
      _toast('가족 이름을 입력해주세요.');
      return;
    }
    if (_role == null) {
      _toast('나의 역할을 선택해주세요.');
      return;
    }
    if (_needsBirthOrder && _birthOrder == null) {
      _toast(
        _role == '아들' ? '몇째 아들인지 선택해주세요.' : '몇째 딸인지 선택해주세요.',
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _familyService.updateProfile(
        familyName: name.isEmpty ? widget.familyName : name,
        roleLabel: _role!,
        birthOrderLabel: _birthOrder,
        isFamilyCreator: _canEditFamilyName,
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었어요.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('설정 저장에 실패했습니다.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '로그아웃 할까요?',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: _titleGreen,
          ),
        ),
        content: const Text(
          '이 기기에서 로그아웃됩니다. 계정은 삭제되지 않아요.',
          style: TextStyle(color: _bodyGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: _mutedGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: _titleGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
      await _tokens.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _toast('로그아웃에 실패했습니다.\n$e');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final isCreator = _isFamilyCreator == true;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '계정을 삭제하시나요?',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: _titleGreen,
          ),
        ),
        content: Text(
          isCreator
              ? '계정을 삭제하시면 우리 가족의 데이터가 30일 후에 삭제됩니다.'
              : '30일후 데이터는 완전 삭제됩니다.',
          style: const TextStyle(color: _bodyGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: _mutedGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: _danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _withAuth(_api.deleteAccount);
      await _tokens.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _toast('계정 삭제에 실패했습니다.\n$e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final family = _family;
    final members = family?.members ?? const <FamilyMemberResult>[];

    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.06, bottom: keyboard),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ColoredBox(
          color: _cream,
          child: Stack(
            children: [
              const Positioned.fill(child: ModalBranchDecor()),
              Column(
                children: [
                  SizedBox(height: size.height * 0.012),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D4C8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      shortest * 0.04,
                      size.height * 0.004,
                      shortest * 0.02,
                      0,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            children: [
                              const SproutIcon(size: 16),
                              const SizedBox(height: 4),
                              Text(
                                '설정',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cafe24Oneprettynight',
                                  fontSize: shortest * 0.055,
                                  color: _titleGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _mutedGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loadingFamily && family == null
                        ? const Center(
                            child: CircularProgressIndicator(color: _mint),
                          )
                        : _familyError != null && family == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '가족 정보를 불러오지 못했어요.',
                                      style: TextStyle(color: _bodyGrey),
                                    ),
                                    TextButton(
                                      onPressed: _loadFamily,
                                      child: const Text(
                                        '다시 시도',
                                        style: TextStyle(color: _mint),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  shortest * 0.055,
                                  8,
                                  shortest * 0.055,
                                  bottomInset + 24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (family != null)
                                      _FamilyCard(
                                        family: family,
                                        members: members,
                                        onCopy: () =>
                                            _copyCode(family.inviteCode),
                                      ),
                                    const SizedBox(height: 28),
                                    const Text(
                                      '내 설정',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        fontSize: 18,
                                        color: _titleGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _SettingsGroup(
                                      children: [
                                        _SettingsRow(
                                          label: '나의 역할',
                                          value: _role ?? '선택해주세요',
                                          muted: _role == null,
                                          onTap: () async {
                                            final selected = await _pickOption(
                                              title: '나는 우리 가족의?',
                                              options: _roles,
                                              current: _role,
                                            );
                                            if (selected == null) return;
                                            setState(() {
                                              _role = selected;
                                              _birthOrder = null;
                                            });
                                          },
                                        ),
                                        if (_needsBirthOrder)
                                          _SettingsRow(
                                            label: '출생 순서',
                                            value: _birthOrder ??
                                                (_role == '아들'
                                                    ? '몇째 아들인가요?'
                                                    : '몇째 딸인가요?'),
                                            muted: _birthOrder == null,
                                            onTap: () async {
                                              final selected =
                                                  await _pickOption(
                                                title: _role == '아들'
                                                    ? '몇째 아들인가요?'
                                                    : '몇째 딸인가요?',
                                                options: _birthOrderOptions,
                                                current: _birthOrder,
                                              );
                                              if (selected == null) return;
                                              setState(
                                                () => _birthOrder = selected,
                                              );
                                            },
                                          ),
                                        _SettingsRow(
                                          label: '가족 이름',
                                          value: _canEditFamilyName
                                              ? null
                                              : (_nameController.text.isEmpty
                                                  ? widget.familyName
                                                  : _nameController.text),
                                          trailing: _canEditFamilyName
                                              ? null
                                              : const Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 16,
                                                  color: _mutedGrey,
                                                ),
                                          onTap: _canEditFamilyName
                                              ? null
                                              : () => _toast(
                                                    '가족 이름은 가족을 만든 사람만 바꿀 수 있어요',
                                                  ),
                                          valueChild: _canEditFamilyName
                                              ? SizedBox(
                                                  width: 140,
                                                  child: TextField(
                                                    controller: _nameController,
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          'FamilyNameDate',
                                                      fontSize: 15,
                                                      color: _bodyGrey,
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                      isDense: true,
                                                      border: InputBorder.none,
                                                      hintText: '가족 이름',
                                                      hintStyle: TextStyle(
                                                        color: _mutedGrey,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        _SettingsRow(
                                          label: '질문 도착 알림',
                                          sub: _notificationsOn
                                              ? '매일 새 질문이 도착하면 알려 드려요'
                                              : '알림이 꺼져 있어요',
                                          trailing: Switch.adaptive(
                                            value: _notificationsOn,
                                            activeTrackColor: _mint,
                                            onChanged: (v) => setState(
                                              () => _notificationsOn = v,
                                            ),
                                          ),
                                        ),
                                        _SettingsRow(
                                          label: '큰 글씨',
                                          sub: _largeText
                                              ? '앱 글자가 조금 더 크게 보여요'
                                              : '작은 글씨가 부담될 때 켜 보세요',
                                          trailing: Switch.adaptive(
                                            value: _largeText,
                                            activeTrackColor: _mint,
                                            onChanged: (v) async {
                                              setState(() => _largeText = v);
                                              await AppSettings.instance
                                                  .setLargeText(v);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 50,
                                      child: FilledButton(
                                        onPressed: (_saving ||
                                                _loggingOut ||
                                                _deleting)
                                            ? null
                                            : _save,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _buttonGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          _saving ? '저장 중...' : '저장',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _SettingsGroup(
                                      children: [
                                        _SettingsRow(
                                          label: '로그아웃',
                                          leading: const Icon(
                                            Icons.logout_rounded,
                                            size: 18,
                                            color: _mutedGrey,
                                          ),
                                          onTap: (_loggingOut ||
                                                  _deleting ||
                                                  _saving)
                                              ? null
                                              : _logout,
                                        ),
                                        _SettingsRow(
                                          label: '계정 삭제',
                                          labelColor: _danger,
                                          leading: const Icon(
                                            Icons.person_off_outlined,
                                            size: 18,
                                            color: _danger,
                                          ),
                                          onTap: (_deleting || _loggingOut)
                                              ? null
                                              : _deleteAccount,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '탈퇴 후 30일 동안 데이터가 보관되고, 그 안에 다시 로그인하면 복구돼요. 가족을 만든 사람이 탈퇴하면 30일 뒤 가족 공동 데이터도 삭제돼요.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: _mutedGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.members,
    required this.onCopy,
  });

  final MyFamilyResult family;
  final List<FamilyMemberResult> members;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48, child: ColoredBox(color: _meadow)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 28,
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    minWidth: 0,
                    maxHeight: 50,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          for (var i = 0; i < members.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _Avatar(
                              label: members[i].roleLabel,
                              isMe: members[i].isMe,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        family.familyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'FamilyNameDate',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _bodyGrey,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${members.length}명',
                      style: const TextStyle(fontSize: 14, color: _mutedGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '가족 코드',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _mutedGrey,
                              ),
                            ),
                            Text(
                              family.inviteCode,
                              style: const TextStyle(
                                fontFamily: 'FamilyNameDate',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: _titleGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onCopy,
                        style: TextButton.styleFrom(
                          foregroundColor: _mint,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text(
                          '복사',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                for (final m in members)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _hairline)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.roleLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _bodyGrey,
                            ),
                          ),
                        ),
                        if (m.isCreator) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEE6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '만든 사람',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _mutedGrey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (m.isMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _meadow,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '나',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _titleGreen,
                              ),
                            ),
                          ),
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
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.isMe});

  final String label;
  final bool isMe;

  Color get _tint {
    if (label.contains('할아버지')) return const Color(0xFFB8D4E8);
    if (label.contains('할머니')) return const Color(0xFFD4C4E8);
    if (label.contains('아빠')) return const Color(0xFFB8D4E8);
    if (label.contains('엄마')) return const Color(0xFFF3D0D8);
    if (label.contains('아들')) return const Color(0xFFC5D9BE);
    if (label.contains('딸')) return const Color(0xFFF5E6A8);
    return const Color(0xFFB8D4D0);
  }

  String get _initial {
    if (isMe) return '나';
    if (label.contains('할아버지')) return '할';
    if (label.contains('할머니')) return '감';
    if (label.contains('아빠')) return '빠';
    if (label.contains('엄마')) return '엄';
    if (label.contains('아들')) return '아';
    if (label.contains('딸')) return '딸';
    return label.isEmpty ? '?' : label.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tint,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        _initial,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _bodyGrey,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.value,
    this.sub,
    this.leading,
    this.trailing,
    this.valueChild,
    this.onTap,
    this.muted = false,
    this.labelColor,
  });

  final String label;
  final String? value;
  final String? sub;
  final Widget? leading;
  final Widget? trailing;
  final Widget? valueChild;
  final VoidCallback? onTap;
  final bool muted;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? _bodyGrey,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(fontSize: 12, color: _mutedGrey),
                  ),
                ],
              ],
            ),
          ),
          if (valueChild != null)
            valueChild!
          else if (value != null) ...[
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: muted ? _mutedGrey : _bodyGrey,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _mutedGrey,
              ),
            ],
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
