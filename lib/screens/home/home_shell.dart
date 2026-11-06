import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/app_guide_overlay.dart';
import 'package:hrhb_frontend/widgets/temperature_drop_popup.dart';
import 'package:hrhb_frontend/widgets/temperature_rise_popup.dart';

import 'family_answers_screen.dart';
import 'family_archive_screen.dart';
import 'family_diary_screen.dart';
import 'family_gallery_screen.dart';
import 'family_temperature_screen.dart';
import 'today_question_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _navShadow = Color(0x1A000000);
const _navBarFill = Color(0xA3EAF3E4);
const _navBarBorder = Color(0x44B5C9AE);
const _homeGreenDeep = Color(0xFF5A6B42);
const _navLabel = Color(0xFF5E6B55);

/// Tab order: 기록 · 갤러리 · 오늘의 질문(중앙) · 온도 · 일지
const _kArchive = 0;
const _kGallery = 1;
const _kToday = 2;
const _kTemp = 3;
const _kDiary = 4;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = _kToday;
  final _archiveNavKey = GlobalKey<NavigatorState>();
  final _todayNavKey = GlobalKey<NavigatorState>();
  final _galleryNavKey = GlobalKey<NavigatorState>();
  final _navBarKey = GlobalKey();
  final _archiveTabKey = GlobalKey();
  final _galleryTabKey = GlobalKey();
  final _todayTabKey = GlobalKey();
  final _tempTabKey = GlobalKey();
  final _diaryTabKey = GlobalKey();
  final _tokenStorage = TokenStorage();
  final _apiClient = ApiClient();
  double _navBarHeight = 0;
  bool _showAppGuide = false;

  /// 디자인 확인용. 실제 반영 후 둘 다 false.
  static const _previewTempRisePopup = false;
  static const _previewTempDropPopup = false;

  /// 가이드를 매번 보고 싶을 때 true (배포 전 false).
  static const _forceAppGuide = false;

  FamilyProfile? _profile;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureNavBar();
      _maybeShowAppGuideThenTempPopup();
    });
  }

  Future<void> _maybeShowAppGuideThenTempPopup() async {
    try {
      final seen = await _tokenStorage.readAppGuideSeen();
      if (!mounted) return;
      if (_forceAppGuide || !seen) {
        setState(() => _showAppGuide = true);
        return;
      }
    } catch (_) {}
    await _maybeShowTemperaturePopup();
  }

  Future<void> _finishAppGuide() async {
    if (!mounted) return;
    setState(() => _showAppGuide = false);
    setState(() => _index = _kToday);
    try {
      await _tokenStorage.saveAppGuideSeen(true);
    } catch (_) {}
    await _maybeShowTemperaturePopup();
  }

  List<AppGuideStep> get _guideSteps => [
        AppGuideStep(
          title: '하루한번에 오신 걸 환영해요',
          body: '가족이 매일 한 번씩 묻고 답하며 온도를 키우는 앱이에요.\n'
              '아래에서 주요 기능을 같이 눌러보며 알아볼게요.',
        ),
        AppGuideStep(
          title: '오늘의 질문',
          body: '가운데 편지 버튼이 오늘의 질문이에요.\n'
              '매일 도착하는 질문에 답하고, 가족의 답변을 읽어보세요.',
          targetKey: _todayTabKey,
          tabIndex: _kToday,
          holePadding: 8,
          holeRadius: 999,
        ),
        AppGuideStep(
          title: '기록',
          body: '날짜별 답변·사진·주간/월간 리포트·가족 캘린더를 볼 수 있어요.\n'
              '이번 주 별명도 리포트에서 확인해요.',
          targetKey: _archiveTabKey,
          tabIndex: _kArchive,
        ),
        AppGuideStep(
          title: '갤러리',
          body: '답변에 올린 사진을 모아서 보고,\n'
              '이벤트별 앨범에 추억을 담을 수 있어요.',
          targetKey: _galleryTabKey,
          tabIndex: _kGallery,
        ),
        AppGuideStep(
          title: '가족 온도',
          body: '가족이 얼마나 따뜻하게 소통했는지 온도로 보여줘요.\n'
              '답변·사진·일지를 남길수록 온도가 올라가요.',
          targetKey: _tempTabKey,
          tabIndex: _kTemp,
        ),
        AppGuideStep(
          title: '가족 일지',
          body: '오늘의 날씨(기분)와 짧은 글을 남기는 공간이에요.\n'
              '지난 날 일지도 보고 수정할 수 있어요.',
          targetKey: _diaryTabKey,
          tabIndex: _kDiary,
        ),
        const AppGuideStep(
          title: '이제 시작해 볼까요?',
          body: '오늘의 질문에서 오른쪽 위 설정으로\n'
              '가족 정보와 내 역할을 바꿀 수 있어요.\n'
              '가족과 함께 따뜻한 하루를 남겨보세요!',
          tabIndex: _kToday,
        ),
      ];

  Future<void> _loadFamilyProfile() async {
    final profile = await _tokenStorage.readFamilyProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileLoaded = true;
    });
  }

  String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _maybeShowTemperaturePopup() async {
    try {
      if (_previewTempRisePopup) {
        if (!mounted) return;
        await TemperatureRisePopup.show(
          context,
          deltaFromYesterday: 0.8,
          bubbleText: '가족이 따뜻한 하루를 나눴어요!',
        );
        return;
      }

      if (_previewTempDropPopup) {
        if (!mounted) return;
        await TemperatureDropPopup.show(
          context,
          deltaFromYesterday: -0.6,
          bubbleText: '오늘은 조금 조용한 하루였어요.',
        );
        return;
      }

      final shownDate = await _tokenStorage.readTempPopupShownDate();
      final today = _todayKey();
      if (shownDate == today) return;

      var accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;

      FamilyTemperatureResult temp;
      try {
        temp = await _apiClient.fetchFamilyTemperature(accessToken);
      } on ApiException catch (error) {
        if (!error.message.contains('(401)')) return;
        final refreshToken = await _tokenStorage.readRefreshToken();
        final userId = await _tokenStorage.readUserId();
        if (refreshToken == null || userId == null) return;
        final pair = await _apiClient.refresh(refreshToken);
        await _tokenStorage.saveSession(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
          userId: userId,
        );
        temp = await _apiClient.fetchFamilyTemperature(pair.accessToken);
      }

      if (!mounted) return;

      final rose = temp.deltaFromYesterday >= 0.05;
      final dropped = temp.deltaFromYesterday <= -0.05;

      if (rose) {
        await TemperatureRisePopup.show(
          context,
          deltaFromYesterday: temp.deltaFromYesterday,
          bubbleText: temp.bubbleText,
        );
        await _tokenStorage.saveTempPopupShownDate(today);
      } else if (dropped) {
        await TemperatureDropPopup.show(
          context,
          deltaFromYesterday: temp.deltaFromYesterday,
          bubbleText: temp.bubbleText,
        );
        await _tokenStorage.saveTempPopupShownDate(today);
      }
    } catch (_) {
      // Popup is optional UX; never block home.
    }
  }

  void _measureNavBar() {
    final box = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _navBarHeight).abs() > 0.5) {
      setState(() => _navBarHeight = h);
    }
  }

  void _onTabTap(int i) {
    if (i == _index) {
      if (i == _kToday) {
        _todayNavKey.currentState?.popUntil((route) => route.isFirst);
      } else if (i == _kGallery) {
        _galleryNavKey.currentState?.popUntil((route) => route.isFirst);
      } else if (i == _kArchive) {
        _archiveNavKey.currentState?.popUntil((route) => route.isFirst);
      }
      return;
    }
    setState(() => _index = i);
  }

  Future<void> _openTodayAnswersFromTemperature() async {
    setState(() => _index = _kToday);
    _todayNavKey.currentState?.popUntil((route) => route.isFirst);

    try {
      final accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('로그인이 필요합니다.');
      }

      final question = await _apiClient.fetchTodayDailyQuestion(accessToken);
      if (!mounted) return;

      if (!question.isReady || question.dailyQuestionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              question.message ?? '오늘의 질문이 아직 준비되지 않았어요.',
            ),
          ),
        );
        return;
      }

      final familyName = _profile?.familyName ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _todayNavKey.currentState?.push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FamilyAnswersScreen(
                familyName: familyName,
                date: question.date,
                question: question.content ?? '',
                dailyQuestionId: question.dailyQuestionId!,
              );
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(opacity: curved, child: child);
            },
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureNavBar());

    final navClearance =
        (_navBarHeight > 0 ? _navBarHeight : shortest * 0.24) + 8;

    if (!_profileLoaded) {
      return const Scaffold(
        backgroundColor: _cream,
        body: Center(child: CircularProgressIndicator(color: _titleGreen)),
      );
    }

    final familyName = _profile?.familyName ?? '';
    final familyCode = _profile?.familyCode ?? '';
    final myRole = _profile?.myRoleLabel ?? '';
    final isFamilyCreator = _profile?.isFamilyCreator ?? false;

    final pages = [
      Navigator(
        key: _archiveNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FamilyArchiveScreen(
              familyName: familyName,
              bottomNavClearance: navClearance,
            ),
          );
        },
      ),
      Navigator(
        key: _galleryNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const FamilyGalleryScreen(),
          );
        },
      ),
      Navigator(
        key: _todayNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TodayQuestionScreen(
              familyName: familyName,
              familyCode: familyCode,
              myRole: myRole,
              isFamilyCreator: isFamilyCreator,
              onProfileSaved: _loadFamilyProfile,
            ),
          );
        },
      ),
      FamilyTemperatureScreen(
        bottomNavClearance: navClearance,
        onGoToTodayAnswers: _openTodayAnswersFromTemperature,
      ),
      FamilyDiaryScreen(bottomNavClearance: navClearance),
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _cream,
          extendBody: true,
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: Padding(
            key: _navBarKey,
            padding: EdgeInsets.fromLTRB(
              shortest * 0.045,
              0,
              shortest * 0.045,
              bottomInset + size.height * 0.012,
            ),
            child: SizedBox(
              height: shortest * 0.17,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _navBarFill,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _navBarBorder, width: 0.7),
                        boxShadow: const [
                          BoxShadow(
                            color: _navShadow,
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          shortest * 0.01,
                          size.height * 0.011,
                          shortest * 0.01,
                          size.height * 0.009,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: KeyedSubtree(
                                key: _archiveTabKey,
                                child: _SideNavItem(
                                  selected: _index == _kArchive,
                                  label: '기록',
                                  icon: Icons.calendar_month_rounded,
                                  onTap: () => _onTabTap(_kArchive),
                                  shortest: shortest,
                                ),
                              ),
                            ),
                            Expanded(
                              child: KeyedSubtree(
                                key: _galleryTabKey,
                                child: _SideNavItem(
                                  selected: _index == _kGallery,
                                  label: '갤러리',
                                  asset:
                                      'assets/images/navigation/familygallery.png',
                                  onTap: () => _onTabTap(_kGallery),
                                  shortest: shortest,
                                ),
                              ),
                            ),
                            SizedBox(width: shortest * 0.168),
                            Expanded(
                              child: KeyedSubtree(
                                key: _tempTabKey,
                                child: _SideNavItem(
                                  selected: _index == _kTemp,
                                  label: '가족 온도',
                                  asset:
                                      'assets/images/navigation/familyondo.png',
                                  onTap: () => _onTabTap(_kTemp),
                                  shortest: shortest,
                                ),
                              ),
                            ),
                            Expanded(
                              child: KeyedSubtree(
                                key: _diaryTabKey,
                                child: _SideNavItem(
                                  selected: _index == _kDiary,
                                  label: '가족 일지',
                                  asset:
                                      'assets/images/navigation/familydiary.png',
                                  onTap: () => _onTabTap(_kDiary),
                                  shortest: shortest,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -shortest * 0.106,
                    child: KeyedSubtree(
                      key: _todayTabKey,
                      child: _CenterHomeButton(
                        selected: _index == _kToday,
                        size: shortest * 0.292,
                        onTap: () => _onTabTap(_kToday),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showAppGuide)
          Positioned.fill(
            child: AppGuideOverlay(
              steps: _guideSteps,
              onSelectTab: (i) {
                if (!mounted) return;
                setState(() => _index = i);
              },
              onFinished: _finishAppGuide,
            ),
          ),
      ],
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.shortest,
    this.asset,
    this.icon,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final double shortest;
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final iconSize = shortest * 0.098;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: asset != null
                  ? Opacity(
                      opacity: selected ? 1 : 0.78,
                      child: Image.asset(
                        asset!,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                  : Icon(
                      icon,
                      size: iconSize * 0.88,
                      color: selected ? _homeGreenDeep : _navLabel,
                    ),
            ),
            SizedBox(height: shortest * 0.005),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: shortest * 0.024,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _homeGreenDeep : _navLabel,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 중앙 오늘의 질문 — navigation/home_letter.png 에셋.
class _CenterHomeButton extends StatelessWidget {
  const _CenterHomeButton({
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/images/navigation/home_letter.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
