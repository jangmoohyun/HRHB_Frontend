import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../family/info/family_info_screen.dart';
import 'family_answers_screen.dart';
import 'profile_settings_modal.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);

class TodayQuestionScreen extends StatefulWidget {
  const TodayQuestionScreen({
    super.key,
    required this.familyName,
    required this.familyCode,
    required this.myRole,
    this.isFamilyCreator = false,
    this.onProfileSaved,
  });

  final String familyName;
  final String familyCode;
  final String myRole;
  final bool isFamilyCreator;
  final Future<void> Function()? onProfileSaved;

  @override
  State<TodayQuestionScreen> createState() => _TodayQuestionScreenState();
}

class _TodayQuestionScreenState extends State<TodayQuestionScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  late String _familyName;
  late String _familyCode;
  late String _myRole;
  late bool _isFamilyCreator;

  late int _year;
  late int _month;
  PageController? _pageController;

  bool _loading = true;
  String? _error;
  List<_QuestionItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _familyName = widget.familyName;
    _familyCode = widget.familyCode;
    _myRole = widget.myRole;
    _isFamilyCreator = widget.isFamilyCreator;
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadMonth();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _reloadProfileFromStorage() async {
    final profile = await _tokenStorage.readFamilyProfile();
    if (!mounted || profile == null) return;
    setState(() {
      _familyName = profile.familyName;
      _familyCode = profile.familyCode;
      _myRole = profile.myRoleLabel;
      _isFamilyCreator = profile.isFamilyCreator;
    });
    await widget.onProfileSaved?.call();
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('로그인이 필요합니다.');
      }

      late final MonthDailyQuestionsResult month;
      try {
        month = await _apiClient.fetchMonthDailyQuestions(
          accessToken: accessToken,
          year: _year,
          month: _month,
        );
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
        month = await _apiClient.fetchMonthDailyQuestions(
          accessToken: pair.accessToken,
          year: _year,
          month: _month,
        );
      }

      if (!mounted) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final items = month.items.map((q) {
        final date = q.date;
        final isToday =
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        return _QuestionItem(
          date: date,
          question: q.isWaiting
              ? (q.message ?? '오늘의 질문은 03:00에\n도착해요!')
              : (q.content ?? ''),
          isToday: isToday,
          isWaiting: q.isWaiting,
          dailyQuestionId: q.dailyQuestionId,
        );
      }).toList();

      var initialPage = items.indexWhere((item) => item.isToday);
      if (initialPage < 0) {
        initialPage = items.isEmpty ? 0 : items.length - 1;
      }

      _pageController?.dispose();
      _pageController = items.isEmpty
          ? null
          : PageController(initialPage: initialPage, viewportFraction: 0.98);

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickYearMonth() async {
    final selected = await showModalBottomSheet<({int year, int month})>(
      context: context,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _YearMonthPickerSheet(
          initialYear: _year,
          initialMonth: _month,
        );
      },
    );
    if (selected == null || !mounted) return;
    if (selected.year == _year && selected.month == _month) return;
    setState(() {
      _year = selected.year;
      _month = selected.month;
    });
    await _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final monthLabel = '$_year년 $_month월';

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SideBranches(),
          Positioned(
            left: 0,
            right: 0,
            bottom: -6,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/todayquestionscreen/grass.png',
                width: size.width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: size.height * 0.004),
                _HeaderBar(
                  shortest: shortest,
                  familyName: _familyName,
                  familyCode: _familyCode,
                  myRole: _myRole,
                  isFamilyCreator: _isFamilyCreator,
                  onProfileSaved: _reloadProfileFromStorage,
                ),
                SizedBox(height: size.height * 0.004),
                _DateBadge(
                  label: monthLabel,
                  width: size.width * 0.44 * 1.6,
                  height: size.height * 0.05 * 1.6,
                  onTap: _pickYearMonth,
                ),
                SizedBox(height: size.height * 0.004),
                Expanded(child: _buildContent(size, shortest)),
                SizedBox(height: bottomPad + size.height * 0.095),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Size size, double shortest) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _titleGreen),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '질문을 불러오지 못했어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Question',
                  color: _bodyGrey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadMonth,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty || _pageController == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '이 달에 도착한 질문이 아직 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Question',
              color: _bodyGrey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      clipBehavior: Clip.none,
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: shortest * 0.004),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const ratio = 447 / 558;
              const letterScale = 1.3;
              var height = constraints.maxHeight;
              var width = height * ratio;
              if (width > constraints.maxWidth) {
                width = constraints.maxWidth;
                height = width / ratio;
              }
              return Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, -size.height * 0.04),
                  child: Transform.scale(
                    scale: letterScale,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _QuestionCard(
                        familyName: _familyName,
                        item: _items[index],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _YearMonthPickerSheet extends StatefulWidget {
  const _YearMonthPickerSheet({
    required this.initialYear,
    required this.initialMonth,
  });

  final int initialYear;
  final int initialMonth;

  @override
  State<_YearMonthPickerSheet> createState() => _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends State<_YearMonthPickerSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxYear = now.year;
    final minYear = maxYear - 5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E0D4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '연도 · 월 선택',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: 22,
                color: _titleGreen,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _year <= minYear
                      ? null
                      : () => setState(() => _year -= 1),
                  icon: const Icon(Icons.chevron_left, color: _titleGreen),
                ),
                Text(
                  '$_year년',
                  style: const TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: 24,
                    color: _titleGreen,
                  ),
                ),
                IconButton(
                  onPressed: _year >= maxYear
                      ? null
                      : () => setState(() {
                            _year += 1;
                            if (_year == maxYear && _month > now.month) {
                              _month = now.month;
                            }
                          }),
                  icon: const Icon(Icons.chevron_right, color: _titleGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final disabled = _year == maxYear && month > now.month;
                final selected = month == _month;
                return Material(
                  color: selected
                      ? _titleGreen
                      : (disabled
                          ? const Color(0xFFECEFEA)
                          : const Color(0xFFE4EDE2)),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: disabled
                        ? null
                        : () => setState(() => _month = month),
                    child: Center(
                      child: Text(
                        '$month월',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: 16,
                          color: selected
                              ? Colors.white
                              : (disabled
                                  ? const Color(0xFFA0A89F)
                                  : _titleGreen),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _titleGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop((year: _year, month: _month));
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionItem {
  const _QuestionItem({
    required this.date,
    required this.question,
    required this.isToday,
    this.isWaiting = false,
    this.dailyQuestionId,
  });

  final DateTime date;
  final String question;
  final bool isToday;
  final bool isWaiting;
  final int? dailyQuestionId;

  String get monthDay => '${date.month}/${date.day}';
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.shortest,
    required this.familyName,
    required this.familyCode,
    required this.myRole,
    required this.isFamilyCreator,
    this.onProfileSaved,
  });

  final double shortest;
  final String familyName;
  final String familyCode;
  final String myRole;
  final bool isFamilyCreator;
  final Future<void> Function()? onProfileSaved;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final iconSize = shortest * 0.075;
    final titleTopPad = size.height * 0.012;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: shortest * 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              FamilyInfoScreen.show(context);
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: iconSize + 8,
              height: iconSize + 8,
            ),
            icon: Icon(
              Icons.groups_outlined,
              size: iconSize,
              color: _titleGreen,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: titleTopPad),
              child: Column(
                children: [
                  SproutIcon(size: shortest * 0.045),
                  SizedBox(height: shortest * 0.008),
                  Text(
                    '하루 한번',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.078,
                      height: 1.05,
                      color: _titleGreen,
                    ),
                  ),
                  SizedBox(height: shortest * 0.01),
                  SizedBox(
                    width: shortest * 0.28,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFB7C7B4),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Image.asset(
                            'assets/images/todayquestionscreen/greenheart1.png',
                            width: shortest * 0.035,
                            height: shortest * 0.035,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFB7C7B4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              final saved = await ProfileSettingsModal.show(
                context,
                familyName: familyName,
                currentRole: myRole,
                isFamilyCreator: isFamilyCreator,
              );
              if (saved) {
                await onProfileSaved?.call();
              }
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: iconSize + 8,
              height: iconSize + 8,
            ),
            icon: Icon(
              Icons.person_outline_rounded,
              size: iconSize,
              color: _titleGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.label,
    required this.width,
    required this.height,
    this.onTap,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/todayquestionscreen/datepanel.png',
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: height * 0.22),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: height * 0.32,
                  color: _titleGreen,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.familyName,
    required this.item,
  });

  final String familyName;
  final _QuestionItem item;

  void _openAnswers(BuildContext context) {
    if (item.isWaiting || item.dailyQuestionId == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FamilyAnswersScreen(
            familyName: familyName,
            date: item.date,
            question: item.question,
            dailyQuestionId: item.dailyQuestionId!,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final cardH = constraints.maxHeight;
        // Card-relative type so side/peek layouts don't overflow.
        final titleSize = cardW * 0.072;
        final dateSize = cardW * 0.074;
        final questionSize = cardW * 0.08;
        final heartSize = cardW * 0.048;
        final redlineH = cardH * 0.045;

        return GestureDetector(
          onTap: () => _openAnswers(context),
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/todayquestionscreen/letter.png',
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(
                  left: cardW * 0.06,
                  bottom: cardH * 0.08,
                  child: Image.asset(
                    'assets/images/todayquestionscreen/letterbranch.png',
                    width: cardW * 0.32,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  right: cardW * 0.14,
                  bottom: cardH * 0.075,
                  child: Image.asset(
                    'assets/images/todayquestionscreen/letterdesign.png',
                    width: cardW * 0.48,
                    fit: BoxFit.contain,
                  ),
                ),
                if (item.isToday)
                  Positioned(
                    top: cardH * 0.045,
                    right: cardW * 0.12,
                    child: Image.asset(
                      'assets/images/todayquestionscreen/todayquestiondisplay.png',
                      width: cardW * 0.2,
                      height: cardW * 0.2,
                      fit: BoxFit.contain,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    cardW * 0.17,
                    cardH * 0.16,
                    cardW * 0.19,
                    cardH * 0.28,
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'To. $familyName 가족',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'FamilyNameDate',
                                fontSize: titleSize,
                                color: _titleGreen,
                              ),
                            ),
                            SizedBox(height: cardH * 0.02),
                            SizedBox(
                              width: cardW * 0.55,
                              height: redlineH.clamp(10.0, 22.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      'assets/images/todayquestionscreen/redline2.png',
                                      height: 14,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: cardW * 0.02,
                                    ),
                                    child: Image.asset(
                                      'assets/images/todayquestionscreen/redheart.png',
                                      width: heartSize,
                                      height: heartSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Expanded(
                                    child: Image.asset(
                                      'assets/images/todayquestionscreen/redline2.png',
                                      height: 14,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: cardH * 0.025),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.monthDay,
                                  style: TextStyle(
                                    fontFamily: 'FamilyNameDate',
                                    fontSize: dateSize,
                                    color: _titleGreen,
                                    height: 0.9,
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, -cardH * 0.015),
                                  child: Image.asset(
                                    'assets/images/todayquestionscreen/dateunderline.png',
                                    width: cardW * 0.2,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: cardH * 0.008),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: cardW * 0.04,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: Text(
                                        item.question,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Question',
                                          fontSize: questionSize,
                                          height: 1.4,
                                          color: _bodyGrey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }
}

class _SideBranches extends StatelessWidget {
  const _SideBranches();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -size.width * 0.08,
            top: size.height * 0.12,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.34,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.16,
            child: Image.asset(
              'assets/images/todayquestionscreen/right_branch1.png',
              width: size.width * 0.36,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
