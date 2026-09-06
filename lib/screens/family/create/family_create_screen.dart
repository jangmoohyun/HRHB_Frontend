import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/family_service.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../created/family_created_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF5F5F5F);
const _mutedGrey = Color(0xFF8F8F8F);
const _lineGrey = Color(0xFFD8D8D8);
const _mint = Color(0xFF57C17D);
const _softMint = Color(0xFFE4F4E2);
const _softOrange = Color(0xFFF5E2CF);
const _orangeIcon = Color(0xFFE8A05A);
const _buttonGreen = Color(0xFF3CB371);

class FamilyCreateScreen extends StatefulWidget {
  const FamilyCreateScreen({super.key});

  @override
  State<FamilyCreateScreen> createState() => _FamilyCreateScreenState();
}

class _FamilyCreateScreenState extends State<FamilyCreateScreen> {
  final _nameController = TextEditingController();
  final _familyService = FamilyService();
  String? _role;
  String? _birthOrder;
  bool _isSubmitting = false;

  static const _roles = ['아빠', '엄마', '아들', '딸'];
  static const _birthOrders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

  bool get _needsBirthOrder => _role == '아들' || _role == '딸';

  List<String> get _birthOrderOptions {
    if (_role == '아들') {
      return _birthOrders.map((order) => '$order 아들').toList();
    }
    if (_role == '딸') {
      return _birthOrders.map((order) => '$order 딸').toList();
    }
    return const [];
  }

  bool get _canSubmit {
    final name = _nameController.text.trim();
    if (name.isEmpty || _role == null || _isSubmitting) return false;
    if (_needsBirthOrder && _birthOrder == null) return false;
    return true;
  }

  Future<void> _createFamily() async {
    if (!_canSubmit) {
      _showMessage('가족 이름과 역할을 모두 선택해 주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await _familyService.create(
        familyName: _nameController.text.trim(),
        roleLabel: _role!,
        birthOrderLabel: _birthOrder,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FamilyCreatedScreen(
            familyCode: result.inviteCode,
            familyName: result.familyName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('가족 생성에 실패했습니다.\n$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _lineGrey,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _titleGreen,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final isSelected = option == current;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? _mint : _bodyGrey,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: _mint)
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _BranchDecorations(screenSize: size)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.05,
                    size.height * 0.012,
                    shortest * 0.08,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: _mint,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      label: const Text(
                        '뒤로',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: size.height * 0.01),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                '하루한번',
                                style: TextStyle(
                                  fontFamily: 'Cafe24Oneprettynight',
                                  fontSize: shortest * 0.105,
                                  height: 1.05,
                                  color: _titleGreen,
                                ),
                              ),
                              SizedBox(height: size.height * 0.012),
                              Text(
                                '가족을 잇는 감성 커뮤니케이션',
                                style: TextStyle(
                                  fontSize: shortest * 0.035,
                                  height: 1.3,
                                  letterSpacing: -0.3,
                                  color: _mutedGrey,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              const SproutDivider(),
                            ],
                          ),
                        ),
                        SizedBox(height: size.height * 0.04),
                        _FieldLabel(text: '가족 이름'),
                        SizedBox(height: size.height * 0.012),
                        _InputCard(
                          leading: const _CircleIcon(
                            background: _softMint,
                            icon: Icons.groups_rounded,
                            iconColor: _mint,
                          ),
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontSize: 16,
                              color: _bodyGrey,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: '가족 이름을 입력하세요',
                              hintStyle: TextStyle(
                                color: Color(0xFFB5B5B5),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.028),
                        _FieldLabel(text: '나는 우리 가족의?'),
                        SizedBox(height: size.height * 0.012),
                        _InputCard(
                          onTap: () => _pickOption(
                            title: '나는 우리 가족의?',
                            options: _roles,
                            current: _role,
                            onSelected: (value) {
                              setState(() {
                                _role = value;
                                _birthOrder = null;
                              });
                            },
                          ),
                          leading: const _CircleIcon(
                            background: _softOrange,
                            icon: Icons.person_rounded,
                            iconColor: _orangeIcon,
                          ),
                          trailing: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFB0B0B0),
                          ),
                          child: Text(
                            _role ?? '선택해주세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: _role == null
                                  ? const Color(0xFFB5B5B5)
                                  : _bodyGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_needsBirthOrder) ...[
                          SizedBox(height: size.height * 0.028),
                          _FieldLabel(
                            text: _role == '아들' ? '몇째 아들인가요?' : '몇째 딸인가요?',
                          ),
                          SizedBox(height: size.height * 0.012),
                          _InputCard(
                            onTap: () => _pickOption(
                              title: _role == '아들' ? '몇째 아들인가요?' : '몇째 딸인가요?',
                              options: _birthOrderOptions,
                              current: _birthOrder,
                              onSelected: (value) {
                                setState(() => _birthOrder = value);
                              },
                            ),
                            leading: const _CircleIcon(
                              background: _softMint,
                              icon: Icons.tag_rounded,
                              iconColor: _mint,
                            ),
                            trailing: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFFB0B0B0),
                            ),
                            child: Text(
                              _birthOrder ?? '선택해주세요',
                              style: TextStyle(
                                fontSize: 16,
                                color: _birthOrder == null
                                    ? const Color(0xFFB5B5B5)
                                    : _bodyGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: size.height * 0.05),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.08,
                    8,
                    shortest * 0.08,
                    size.height * 0.025,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: size.height * 0.065,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _buttonGreen,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _isSubmitting ? null : _createFamily,
                          child: Center(
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '가족 생성하기',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SproutIcon(size: 14),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2F2F2F),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.leading,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.background,
    required this.icon,
    required this.iconColor,
  });

  final Color background;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

class _BranchDecorations extends StatelessWidget {
  const _BranchDecorations({required this.screenSize});

  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final h = screenSize.height;

    Widget leftBranch({
      required String asset,
      required double top,
      required double height,
      double angle = 0,
      double opacity = 0.78,
    }) {
      return Positioned(
        top: top,
        left: 0,
        child: Transform.translate(
          offset: Offset(-height * 0.12, height * 0.08),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomLeft,
              child: Image.asset(asset, height: height, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    Widget rightBranch({
      required String asset,
      required double top,
      required double height,
      double angle = 0,
      double opacity = 0.78,
      double edgeNudge = 0.12,
    }) {
      return Positioned(
        top: top,
        right: 0,
        child: Transform.translate(
          offset: Offset(height * edgeNudge, height * 0.08),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomRight,
              child: Image.asset(asset, height: height, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          leftBranch(
            asset: 'assets/images/background/leftbranch_1.png',
            top: h * 0.02,
            height: h * 0.28,
            angle: 0.25,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_2.png',
            top: h * 0.28,
            height: h * 0.24,
            angle: -0.05,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_3.png',
            top: h * 0.45,
            height: h * 0.29,
            angle: 0.2,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_4.png',
            top: h * 0.74,
            height: h * 0.24,
            angle: 0.2,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_1.png',
            top: h * 0.1,
            height: h * 0.29,
            angle: 0.1,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_2.png',
            top: h * 0.42,
            height: h * 0.24,
            angle: -0.05,
            edgeNudge: 0.28,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_3.png',
            top: h * 0.64,
            height: h * 0.3,
            angle: -0.15,
          ),
        ],
      ),
    );
  }
}

