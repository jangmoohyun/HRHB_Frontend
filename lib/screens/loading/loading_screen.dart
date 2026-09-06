import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/session_bootstrap.dart';
import 'package:hrhb_frontend/services/push_notification_service.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../family/select/family_select_screen.dart';
import '../home/home_shell.dart';
import '../login/login_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF5F5F5F);
const _mutedGrey = Color(0xFF9B9B9B);

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _floatController;
  late final AnimationController _loaderController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _float;

  final SessionBootstrap _sessionBootstrap = SessionBootstrap();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _float = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final startedAt = DateTime.now();
    SessionDestination destination;
    try {
      destination = await _sessionBootstrap.resolve().timeout(
        const Duration(seconds: 12),
      );
    } catch (error, stack) {
      debugPrint('Session bootstrap failed: $error\n$stack');
      destination = SessionDestination.login;
    }

    // Keep splash visible briefly so the transition does not feel abrupt.
    final elapsed = DateTime.now().difference(startedAt);
    const minSplash = Duration(milliseconds: 1200);
    if (elapsed < minSplash) {
      await Future<void>.delayed(minSplash - elapsed);
    }

    if (!mounted) return;
    if (destination != SessionDestination.login) {
      // Fire-and-forget; never block navigation on push registration.
      PushNotificationService.instance.registerCurrentDevice();
    }
    final Widget next = switch (destination) {
      SessionDestination.home => const HomeShell(),
      SessionDestination.familySelect => const FamilySelectScreen(),
      SessionDestination.login => const LoginScreen(),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BranchDecorations(screenSize: size),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.055),
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
                    SizedBox(height: size.height * 0.022),
                    const SproutDivider(),
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, -0.45),
                        child: AnimatedBuilder(
                          animation: _float,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _float.value),
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/images/loading/letter.png',
                            width: shortest * 0.72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: shortest * 0.038,
                          height: 1.4,
                          color: _bodyGrey,
                        ),
                        children: const [
                          TextSpan(text: '오늘도 '),
                          TextSpan(
                            text: '가족의 마음을',
                            style: TextStyle(
                              color: _titleGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' 이어드릴게요.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.012),
                    Text(
                      '따뜻한 하루를 준비하고 있어요...',
                      style: TextStyle(
                        fontSize: shortest * 0.032,
                        color: _mutedGrey,
                      ),
                    ),
                    SizedBox(height: size.height * 0.028),
                    AnimatedBuilder(
                      animation: _loaderController,
                      builder: (context, _) {
                        final step = (_loaderController.value * 3).floor() % 3;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final active = index <= step;
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: shortest * 0.012,
                              ),
                              child: SproutIcon(
                                size: shortest * 0.038,
                                opacity: active ? 1 : 0.35,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    SizedBox(height: size.height * 0.18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
              child: Image.asset(
                asset,
                height: height,
                fit: BoxFit.contain,
              ),
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
              child: Image.asset(
                asset,
                height: height,
                fit: BoxFit.contain,
              ),
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
