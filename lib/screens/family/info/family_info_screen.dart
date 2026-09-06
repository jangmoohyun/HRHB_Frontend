import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/modal_branch_decor.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _mint = Color(0xFF57C17D);
const _softMint = Color(0xFFE8F5E6);
const _cardBg = Color(0xFFFFFCF3);
const _lineGrey = Color(0xFFE2E2E2);

class FamilyInfoScreen extends StatefulWidget {
  const FamilyInfoScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const FamilyInfoScreen(),
    );
  }

  @override
  State<FamilyInfoScreen> createState() => _FamilyInfoScreenState();
}

class _FamilyInfoScreenState extends State<FamilyInfoScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  bool _loading = true;
  String? _error;
  MyFamilyResult? _family;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _tokenStorage.readFamilyProfile();
      final cachedMembers = await _tokenStorage.readFamilyMembers();
      if (profile != null && cachedMembers.isNotEmpty && mounted) {
        setState(() {
          _family = MyFamilyResult(
            familyId: 0,
            familyName: profile.familyName,
            inviteCode: profile.familyCode,
            members: cachedMembers,
          );
          _loading = false;
        });
      }

      var accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (_family == null) throw StateError('로그인이 필요합니다.');
        return;
      }

      try {
        final family = await _apiClient.fetchMyFamily(accessToken);
        await _tokenStorage.saveFamilyMembers(family.members);
        var myRoleLabel = profile?.myRoleLabel ?? '';
        for (final member in family.members) {
          if (member.isMe) {
            myRoleLabel = member.roleLabel;
            break;
          }
        }
        await _tokenStorage.saveFamilyProfile(
          familyName: family.familyName,
          familyCode: family.inviteCode,
          myRoleLabel: myRoleLabel,
          isFamilyCreator: profile?.isFamilyCreator ?? false,
        );
        if (!mounted) return;
        setState(() {
          _family = family;
          _loading = false;
          _error = null;
        });
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
        final family = await _apiClient.fetchMyFamily(pair.accessToken);
        await _tokenStorage.saveFamilyMembers(family.members);
        if (!mounted) return;
        setState(() {
          _family = family;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (_family != null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('가족 코드가 복사되었어요.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final family = _family;
    final members = family?.members ?? const <FamilyMemberResult>[];

    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.12),
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
                      size.height * 0.008,
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
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _mint),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: shortest * 0.08,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '가족 정보를 불러오지 못했어요.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _bodyGrey,
                                          fontSize: shortest * 0.038,
                                        ),
                                      ),
                                      SizedBox(height: size.height * 0.016),
                                      TextButton(
                                        onPressed: _load,
                                        child: const Text(
                                          '다시 시도',
                                          style: TextStyle(color: _mint),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  shortest * 0.07,
                                  0,
                                  shortest * 0.07,
                                  bottomInset + size.height * 0.03,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Center(child: SproutIcon(size: 18)),
                                    SizedBox(height: size.height * 0.01),
                                    Text(
                                      '우리 가족 정보',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        fontSize: shortest * 0.065,
                                        color: _titleGreen,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.006),
                                    Text(
                                      '${family!.familyName} 가족',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'FamilyNameDate',
                                        fontSize: shortest * 0.058,
                                        color: _bodyGrey,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.024),
                                    Text(
                                      '우리 가족 코드',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        fontSize: shortest * 0.04,
                                        color: _titleGreen,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.01),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE8E4D8),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x14000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: shortest * 0.04,
                                          vertical: size.height * 0.016,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                family.inviteCode,
                                                style: TextStyle(
                                                  fontFamily: 'FamilyNameDate',
                                                  fontSize: shortest * 0.05,
                                                  letterSpacing: 1.2,
                                                  color: _titleGreen,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _copyCode(family.inviteCode),
                                              style: TextButton.styleFrom(
                                                foregroundColor: _mint,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.copy_rounded,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                '복사',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.01),
                                    Text(
                                      '이 코드를 가족에게 공유하면 함께할 수 있어요.',
                                      style: TextStyle(
                                        fontSize: shortest * 0.028,
                                        color: _mutedGrey,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.028),
                                    Row(
                                      children: [
                                        Text(
                                          '우리 가족 구성원',
                                          style: TextStyle(
                                            fontFamily: 'Cafe24Oneprettynight',
                                            fontSize: shortest * 0.04,
                                            color: _titleGreen,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${members.length}명',
                                          style: TextStyle(
                                            fontSize: shortest * 0.03,
                                            color: _mutedGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: size.height * 0.01),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE8E4D8),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          for (var i = 0;
                                              i < members.length;
                                              i++) ...[
                                            if (i > 0)
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: _lineGrey,
                                                indent: 16,
                                                endIndent: 16,
                                              ),
                                            _MemberTile(
                                              label: members[i].roleLabel,
                                              isMe: members[i].isMe,
                                              shortest: shortest,
                                            ),
                                          ],
                                        ],
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.label,
    required this.isMe,
    required this.shortest,
  });

  final String label;
  final bool isMe;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: shortest * 0.04,
        vertical: shortest * 0.032,
      ),
      child: Row(
        children: [
          Container(
            width: shortest * 0.095,
            height: shortest * 0.095,
            decoration: const BoxDecoration(
              color: _softMint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: _mint,
              size: shortest * 0.05,
            ),
          ),
          SizedBox(width: shortest * 0.035),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'FamilyNameDate',
                      fontSize: shortest * 0.04,
                      color: _bodyGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: shortest * 0.02),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _softMint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '나',
                      style: TextStyle(
                        fontSize: shortest * 0.026,
                        color: _titleGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
