import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
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
const _cardBg = Color(0xFFFFFCF3);
const _buttonGreen = Color(0xFF3CB371);
const _danger = Color(0xFFD96050);

class ProfileSettingsModal extends StatefulWidget {
  const ProfileSettingsModal({
    super.key,
    required this.familyName,
    this.currentRole = '',
    this.notificationsEnabled = true,
    this.isFamilyCreator,
  });

  final String familyName;
  final String currentRole;
  final bool notificationsEnabled;
  final bool? isFamilyCreator;

  /// Returns true when settings were saved successfully.
  static Future<bool> show(
    BuildContext context, {
    required String familyName,
    String currentRole = '',
    bool notificationsEnabled = true,
    bool? isFamilyCreator,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return ProfileSettingsModal(
          familyName: familyName,
          currentRole: currentRole,
          notificationsEnabled: notificationsEnabled,
          isFamilyCreator: isFamilyCreator,
        );
      },
    );
    return result == true;
  }

  @override
  State<ProfileSettingsModal> createState() => _ProfileSettingsModalState();
}

class _ProfileSettingsModalState extends State<ProfileSettingsModal> {
  static const _roles = ['아빠', '엄마', '아들', '딸'];
  static const _birthOrders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

  late final TextEditingController _nameController;
  late String? _role;
  String? _birthOrder;
  late bool _notificationsOn;
  bool? _isFamilyCreator;
  bool _deleting = false;
  bool _saving = false;
  bool _loggingOut = false;

  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();
  final _familyService = FamilyService();

  bool get _needsBirthOrder => _role == '아들' || _role == '딸';
  bool get _canEditFamilyName => _isFamilyCreator == true;

  List<String> get _birthOrderOptions {
    if (_role == '아들') {
      return _birthOrders.map((order) => '$order 아들').toList();
    }
    if (_role == '딸') {
      return _birthOrders.map((order) => '$order 딸').toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.familyName);
    _notificationsOn = widget.notificationsEnabled;
    _isFamilyCreator = widget.isFamilyCreator;

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

    _loadCreatorFlagIfNeeded();
  }

  Future<void> _loadCreatorFlagIfNeeded() async {
    if (_isFamilyCreator != null) return;
    final profile = await _tokenStorage.readFamilyProfile();
    if (!mounted) return;
    if (profile != null) {
      setState(() => _isFamilyCreator = profile.isFamilyCreator);
      return;
    }
    try {
      final token = await _tokenStorage.readAccessToken();
      if (token == null) return;
      final me = await _apiClient.fetchMe(token);
      if (!mounted) return;
      setState(() => _isFamilyCreator = me.isFamilyCreator ?? false);
    } catch (_) {
      // Keep null; treat as non-creator for editing.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    if (_canEditFamilyName && name.isEmpty) {
      _showMessage('가족 이름을 입력해주세요.');
      return;
    }
    if (_role == null) {
      _showMessage('나의 역할을 선택해주세요.');
      return;
    }
    if (_needsBirthOrder && _birthOrder == null) {
      _showMessage(
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
    } catch (error) {
      if (!mounted) return;
      _showMessage('설정 저장에 실패했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
      await _tokenStorage.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('로그아웃에 실패했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;

    final isCreator = _isFamilyCreator == true;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
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
                style: TextStyle(
                  color: _danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      var accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('로그인이 필요합니다.');
      }

      try {
        await _apiClient.deleteAccount(accessToken);
      } on ApiException catch (error) {
        if (!error.message.contains('(401)')) rethrow;
        final refreshToken = await _tokenStorage.readRefreshToken();
        final userId = await _tokenStorage.readUserId();
        if (refreshToken == null || userId == null) rethrow;
        final pair = await _apiClient.refresh(refreshToken);
        await _tokenStorage.saveSession(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
          userId: userId,
        );
        await _apiClient.deleteAccount(pair.accessToken);
      }

      await _tokenStorage.clear();
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('계정 삭제에 실패했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.08, bottom: keyboard),
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
                      shortest * 0.04,
                      0,
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
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
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        shortest * 0.07,
                        0,
                        shortest * 0.07,
                        bottomInset + size.height * 0.03,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: SproutIcon(size: 18)),
                          SizedBox(height: size.height * 0.01),
                          Text(
                            '내 설정',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontSize: shortest * 0.065,
                              color: _titleGreen,
                            ),
                          ),
                          SizedBox(height: size.height * 0.024),
                          _SectionLabel(text: '나의 역할 변경', shortest: shortest),
                          SizedBox(height: size.height * 0.008),
                          _SelectField(
                            value: _role ?? '선택해주세요',
                            isPlaceholder: _role == null,
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
                          if (_needsBirthOrder) ...[
                            SizedBox(height: size.height * 0.01),
                            _SelectField(
                              value: _birthOrder ??
                                  (_role == '아들'
                                      ? '몇째 아들인가요?'
                                      : '몇째 딸인가요?'),
                              isPlaceholder: _birthOrder == null,
                              onTap: () async {
                                final selected = await _pickOption(
                                  title: _role == '아들'
                                      ? '몇째 아들인가요?'
                                      : '몇째 딸인가요?',
                                  options: _birthOrderOptions,
                                  current: _birthOrder,
                                );
                                if (selected == null) return;
                                setState(() => _birthOrder = selected);
                              },
                            ),
                          ],
                          SizedBox(height: size.height * 0.022),
                          _SectionLabel(
                            text: '우리 가족 이름 변경',
                            shortest: shortest,
                          ),
                          if (!_canEditFamilyName) ...[
                            SizedBox(height: size.height * 0.006),
                            Text(
                              '가족이름은 가족 생성자만 수정할 수 있습니다.',
                              style: TextStyle(
                                fontSize: shortest * 0.028,
                                color: _mutedGrey,
                                height: 1.3,
                              ),
                            ),
                          ],
                          SizedBox(height: size.height * 0.008),
                          TextField(
                            controller: _nameController,
                            enabled: _canEditFamilyName,
                            readOnly: !_canEditFamilyName,
                            style: TextStyle(
                              fontFamily: 'FamilyNameDate',
                              fontSize: shortest * 0.042,
                              color: _canEditFamilyName
                                  ? _bodyGrey
                                  : _mutedGrey,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _canEditFamilyName
                                  ? _cardBg
                                  : const Color(0xFFF3F0E6),
                              hintText: '가족 이름',
                              hintStyle: const TextStyle(color: _mutedGrey),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: shortest * 0.04,
                                vertical: size.height * 0.018,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E4D8),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E4D8),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _mint,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.022),
                          Material(
                            color: _cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE8E4D8)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: shortest * 0.04,
                              ),
                              title: Text(
                                '알림',
                                style: TextStyle(
                                  fontFamily: 'Cafe24Oneprettynight',
                                  fontSize: shortest * 0.04,
                                  color: _titleGreen,
                                ),
                              ),
                              subtitle: Text(
                                _notificationsOn
                                    ? '알림이 켜져 있어요'
                                    : '알림이 꺼져 있어요',
                                style: TextStyle(
                                  fontSize: shortest * 0.028,
                                  color: _mutedGrey,
                                ),
                              ),
                              value: _notificationsOn,
                              activeThumbColor: Colors.white,
                              activeTrackColor: _mint,
                              onChanged: (value) {
                                setState(() => _notificationsOn = value);
                              },
                            ),
                          ),
                          SizedBox(height: size.height * 0.028),
                          SizedBox(
                            height: size.height * 0.056,
                            child: FilledButton(
                              onPressed: (_saving || _loggingOut || _deleting)
                                  ? null
                                  : _confirm,
                              style: FilledButton.styleFrom(
                                backgroundColor: _buttonGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _buttonGreen.withValues(
                                  alpha: 0.55,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _saving ? '저장 중...' : '확인',
                                style: TextStyle(
                                  fontSize: shortest * 0.042,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.014),
                          SizedBox(
                            height: size.height * 0.052,
                            child: OutlinedButton(
                              onPressed: (_loggingOut || _deleting || _saving)
                                  ? null
                                  : _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _titleGreen,
                                side: const BorderSide(color: _titleGreen),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loggingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: _titleGreen,
                                      ),
                                    )
                                  : Text(
                                      '로그아웃',
                                      style: TextStyle(
                                        fontSize: shortest * 0.038,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.014),
                          SizedBox(
                            height: size.height * 0.052,
                            child: OutlinedButton(
                              onPressed: (_deleting || _loggingOut)
                                  ? null
                                  : _deleteAccount,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _danger,
                                side: const BorderSide(color: _danger),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _deleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: _danger,
                                      ),
                                    )
                                  : Text(
                                      '계정 삭제',
                                      style: TextStyle(
                                        fontSize: shortest * 0.038,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.shortest});

  final String text;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Cafe24Oneprettynight',
        fontSize: shortest * 0.04,
        color: _titleGreen,
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E4D8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isPlaceholder ? _mutedGrey : _bodyGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _mutedGrey),
            ],
          ),
        ),
      ),
    );
  }
}
