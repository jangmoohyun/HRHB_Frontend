import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/temperature_drop_popup.dart';
import 'package:hrhb_frontend/widgets/temperature_rise_popup.dart';

import 'family_answers_screen.dart';
import 'family_diary_screen.dart';
import 'family_gallery_screen.dart';
import 'family_temperature_screen.dart';
import 'today_question_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _mutedGrey = Color(0xFF8A8A8A);
const _navShadow = Color(0x1A000000);
const _navBarFill = Color(0xB3E8F0E4);
const _navBarBorder = Color(0x99C5D5C0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _todayNavKey = GlobalKey<NavigatorState>();
  final _galleryNavKey = GlobalKey<NavigatorState>();
  final _navBarKey = GlobalKey();
  final _tokenStorage = TokenStorage();
  final _apiClient = ApiClient();
  double _navBarHeight = 0;

  /// 디자인 확인용. 실제 반영 후 둘 다 false.
  static const _previewTempRisePopup = false;
  static const _previewTempDropPopup = false;

  FamilyProfile? _profile;
  bool _profileLoaded = false;

  static const _tabs = [
    _NavTab(
      label: '오늘의 질문',
      asset: 'assets/images/navigation/todayquestion.png',
    ),
    _NavTab(
      label: '가족 갤러리',
      asset: 'assets/images/navigation/familygallery.png',
    ),
    _NavTab(
      label: '가족 온도',
      asset: 'assets/images/navigation/familyondo.png',
    ),
    _NavTab(
      label: '가족 일지',
      asset: 'assets/images/navigation/familydiary.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureNavBar();
      _maybeShowTemperaturePopup();
    });
  }

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
      // Preview: show mock rise popup immediately (no API needed).
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
    if (i == _index && i == 0) {
      _todayNavKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    if (i == _index && i == 1) {
      _galleryNavKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = i);
  }

  Future<void> _openTodayAnswersFromTemperature() async {
    setState(() => _index = 0);
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

    // 첫 프레임(측정 전)용 fallback — 이후 실측 값으로 교체
    final navClearance = (_navBarHeight > 0 ? _navBarHeight : shortest * 0.22) + 4;

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
      Navigator(
        key: _galleryNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const FamilyGalleryScreen(),
          );
        },
      ),
      FamilyTemperatureScreen(
        bottomNavClearance: navClearance,
        onGoToTodayAnswers: _openTodayAnswersFromTemperature,
      ),
      FamilyDiaryScreen(bottomNavClearance: navClearance),
    ];

    return Scaffold(
      backgroundColor: _cream,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Padding(
        key: _navBarKey,
        padding: EdgeInsets.fromLTRB(
          shortest * 0.05,
          0,
          shortest * 0.05,
          bottomInset + size.height * 0.012,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _navBarFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _navBarBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: _navShadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: shortest * 0.02,
              vertical: size.height * 0.006,
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == _index;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _onTabTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Opacity(
                                opacity: selected ? 1 : 0.55,
                                child: Image.asset(
                                  tab.asset,
                                  width: shortest * 0.115,
                                  height: shortest * 0.115,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (tab.showBadge)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE86A4A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: size.height * 0.004),
                          Text(
                            tab.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: shortest * 0.028,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? _titleGreen : _mutedGrey,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.asset,
    this.showBadge = false,
  });

  final String label;
  final String asset;
  final bool showBadge;
}
