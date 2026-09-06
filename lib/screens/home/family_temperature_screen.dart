import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _tipBg = Color(0xFFF0EAF6);
const _changeBlue = Color(0xFF5B8FD9);
const _bubbleYellow = Color(0xFFFFF1B8);

Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.parse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
  return Color(value);
}

class FamilyTemperatureScreen extends StatefulWidget {
  const FamilyTemperatureScreen({
    super.key,
    this.bottomNavClearance = 0,
    this.onGoToTodayAnswers,
  });

  final double bottomNavClearance;
  final Future<void> Function()? onGoToTodayAnswers;

  @override
  State<FamilyTemperatureScreen> createState() =>
      _FamilyTemperatureScreenState();
}

class _FamilyTemperatureScreenState extends State<FamilyTemperatureScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  bool _loading = true;
  String? _error;
  double _temperature = 36.5;
  double _deltaFromYesterday = 0;
  String _statusLabel = '따뜻해요';
  String _bubbleText = '따뜻한 하루를 보내고 있어요';
  Color _accentColor = const Color(0xFFF09A4A);
  List<_DailyChange> _dailyChanges = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    var accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      return await action(accessToken);
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
      return action(pair.accessToken);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _withAuth(_apiClient.fetchFamilyTemperature);
      if (!mounted) return;
      setState(() {
        _temperature = data.temperature;
        _deltaFromYesterday = data.deltaFromYesterday;
        _statusLabel = data.statusLabel;
        _bubbleText = data.bubbleText;
        _accentColor = _parseHexColor(data.colorHex);
        _dailyChanges = data.recentChanges
            .map((e) => _DailyChange(label: e.label, value: e.delta))
            .toList();
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

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '가족 온도란?',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              color: _titleGreen,
            ),
          ),
          content: const Text(
            '가족이 질문에 답하고 따뜻한 말을 나눌수록 온도가 올라가요.\n'
            '매일 새벽 2시 50분에 전날 참여율·답변 길이·사진 첨부를 보고 '
            '-1.0°C ~ +1.0°C 사이로 변화해요.',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              color: _bodyGrey,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomClearance = widget.bottomNavClearance > 0
        ? widget.bottomNavClearance
        : MediaQuery.paddingOf(context).bottom + shortest * 0.22 + 4;

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
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.02,
                    size.height * 0.004,
                    shortest * 0.02,
                    0,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '우리 가족 온도',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cafe24Oneprettynight',
                                fontSize: shortest * 0.055,
                                color: _titleGreen,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SproutIcon(size: shortest * 0.038),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showInfo(context),
                        icon: Icon(
                          Icons.info_outline_rounded,
                          color: _titleGreen,
                          size: shortest * 0.055,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '가족 간의 따뜻한 마음 온도예요',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.032,
                    color: _mutedGrey,
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _titleGreen),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '온도를 불러오지 못했어요.',
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      color: _bodyGrey,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: _titleGreen,
                              onRefresh: _load,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          size.width * 0.045,
                                          size.height * 0.01,
                                          size.width * 0.045,
                                          bottomClearance,
                                        ),
                                        child: SizedBox(
                                          height: math.max(
                                            constraints.maxHeight -
                                                bottomClearance -
                                                size.height * 0.01,
                                            shortest * 1.35,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: _cardWhite,
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x16000000),
                                                  blurRadius: 16,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                shortest * 0.035,
                                                shortest * 0.025,
                                                shortest * 0.035,
                                                shortest * 0.025,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    flex: 13,
                                                    child: _GaugeBlock(
                                                      temperature:
                                                          _temperature,
                                                      statusLabel:
                                                          _statusLabel,
                                                      bubbleText: _bubbleText,
                                                      deltaFromYesterday:
                                                          _deltaFromYesterday,
                                                      accentColor:
                                                          _accentColor,
                                                      shortest: shortest,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          shortest * 0.018),
                                                  Expanded(
                                                    flex: 6,
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                        shortest * 0.02,
                                                        shortest * 0.018,
                                                        shortest * 0.02,
                                                        shortest * 0.014,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(18),
                                                        border: Border.all(
                                                          color: const Color(
                                                              0xFFE8E2D6),
                                                        ),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color: Color(
                                                                0x0A000000),
                                                            blurRadius: 6,
                                                            offset:
                                                                Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child:
                                                          _ChangeChartSection(
                                                        changes:
                                                            _dailyChanges,
                                                        shortest: shortest,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          shortest * 0.016),
                                                  _TipBanner(
                                                    onTap: widget
                                                        .onGoToTodayAnswers,
                                                  ),
                                                ],
                                              ),
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
    );
  }
}

class _DailyChange {
  const _DailyChange({required this.label, required this.value});

  final String label;
  final double value;
}

class _GaugeBlock extends StatelessWidget {
  const _GaugeBlock({
    required this.temperature,
    required this.statusLabel,
    required this.bubbleText,
    required this.deltaFromYesterday,
    required this.accentColor,
    required this.shortest,
  });

  final double temperature;
  final String statusLabel;
  final String bubbleText;
  final double deltaFromYesterday;
  final Color accentColor;
  final double shortest;

  /// 왼쪽 끝 0°C · 오른쪽 끝 100°C
  double get _progress => (temperature / 100).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final down = deltaFromYesterday < 0;
    final flat = deltaFromYesterday.abs() < 0.05;
    final deltaAbs = deltaFromYesterday.abs().toStringAsFixed(1);
    final gaugeColor = accentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gaugeH = constraints.maxHeight;

        return SizedBox(
          height: gaugeH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 온도계 영역 안에만 배경 (밖으로 나가지 않게 클립)
              Positioned.fill(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/familyondo/ondo_background.png',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.15),
                      ),
                      // 위 페이드
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: gaugeH * 0.1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFFCF6),
                                Color(0x00FFFCF6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 아래 페이드
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: gaugeH * 0.22,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xFFFFFCF6),
                                Color(0x99FFFCF6),
                                Color(0x00FFFCF6),
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 왼쪽 페이드
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: shortest * 0.06,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFFFFCF6),
                                Color(0x00FFFCF6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 오른쪽 페이드
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: shortest * 0.06,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Color(0xFFFFFCF6),
                                Color(0x00FFFCF6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 게이지 아크 + 중앙 수치 (하트보다 아래 레이어)
              Positioned(
                left: shortest * 0.02,
                right: shortest * 0.02,
                top: gaugeH * 0.1,
                bottom: gaugeH * 0.08,
                child: CustomPaint(
                  painter: _TemperatureGaugePainter(progress: _progress),
                  child: Align(
                    alignment: const Alignment(0, -0.22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/familyondo/middle_heart.png',
                          width: shortest * 0.13,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: shortest * 0.004),
                        Text(
                          '${temperature.toStringAsFixed(1)}°C',
                          style: TextStyle(
                            fontFamily: 'FamilyNameDate',
                            fontSize: shortest * 0.125,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -0.5,
                            color: gaugeColor,
                          ),
                        ),
                        SizedBox(height: shortest * 0.01),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: shortest * 0.04,
                            vertical: shortest * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: gaugeColor,
                              width: 1.4,
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontSize: shortest * 0.034,
                              color: gaugeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 해
              Positioned(
                left: shortest * 0.0,
                top: shortest * 0.0,
                child: Image.asset(
                  'assets/images/familyondo/sun.png',
                  width: shortest * 0.15,
                  fit: BoxFit.contain,
                ),
              ),
              // 말풍선
              Positioned(
                right: 0,
                top: shortest * 0.015,
                child: _SpeechBubble(
                  text: bubbleText,
                  maxWidth: shortest * 0.48,
                ),
              ),
              // 보라 하트 — 태양 바로 아래
              Positioned(
                left: shortest * 0.0,
                top: shortest * 0.14,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Image.asset(
                    'assets/images/familyondo/left_heart_1.png',
                    width: shortest * 0.12,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // 분홍 하트 — 왼쪽 하단(더 왼쪽·살짝 위)
              Positioned(
                left: shortest * 0.01,
                top: gaugeH * 0.66,
                child: Image.asset(
                  'assets/images/familyondo/left_heart_2.png',
                  width: shortest * 0.105,
                  fit: BoxFit.contain,
                ),
              ),
              // 분홍 라인 하트 — 오른쪽 하단(빨간 끝 근처)
              Positioned(
                right: shortest * -0.04,
                top: gaugeH * 0.68,
                child: Image.asset(
                  'assets/images/familyondo/right_heart_1.png',
                  width: shortest * 0.27,
                  fit: BoxFit.contain,
                ),
              ),
              // 노란 라인 하트 — 오른쪽 위/중간
              Positioned(
                right: shortest * -0.01,
                top: gaugeH * 0.18,
                child: Image.asset(
                  'assets/images/familyondo/right_heart_2.png',
                  width: shortest * 0.1125,
                  fit: BoxFit.contain,
                ),
              ),
              // 어제 대비 — 게이지 하단 개방부 안쪽(더 위)
              Positioned(
                left: 0,
                right: 0,
                bottom: gaugeH * 0.1,
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.034,
                      color: _bodyGrey,
                    ),
                    children: flat
                        ? const [
                            TextSpan(text: '어제와 비슷해요'),
                          ]
                        : [
                            const TextSpan(text: '어제보다 '),
                            TextSpan(
                              text: '$deltaAbs°C',
                              style: const TextStyle(
                                color: _changeBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: down ? ' 내려갔어요!' : ' 올라갔어요!'),
                          ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: const _BubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: maxWidth * 0.058,
              color: _bodyGrey,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 7),
      const Radius.circular(16),
    );
    final paint = Paint()..color = _bubbleYellow;
    canvas.drawRRect(r, paint);

    final path = Path()
      ..moveTo(size.width * 0.22, size.height - 7)
      ..lineTo(size.width * 0.16, size.height)
      ..lineTo(size.width * 0.34, size.height - 7)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 하단만 열린 원형(~265°) 온도 게이지
class _TemperatureGaugePainter extends CustomPainter {
  _TemperatureGaugePainter({required this.progress});

  final double progress;

  static const _colors = [
    Color(0xFF7EC8F5), // 하늘
    Color(0xFF8FD4C8), // 민트
    Color(0xFFB8E07A), // 연두
    Color(0xFFE8E05A), // 노랑
    Color(0xFFF5C04A), // 골드
    Color(0xFFF09A4A), // 주황
    Color(0xFFE8785A), // 코랄
    Color(0xFFE85A55), // 빨강
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.068;
    final center = Offset(size.width / 2, size.height * 0.52);
    final radius =
        math.min(size.width, size.height) * 0.45 - stroke * 0.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 265° 원 (하단 95° 개방)
    const gap = 95 * math.pi / 180;
    final start = math.pi / 2 + gap / 2;
    final sweep = 2 * math.pi - gap; // 265°

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEDE6D8);
    canvas.drawArc(rect, start, sweep, false, track);

    const segments = 120;
    for (var i = 0; i < segments; i++) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      final mid = (t0 + t1) / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap =
            i == 0 || i == segments - 1 ? StrokeCap.round : StrokeCap.butt
        ..color = _lerpStops(mid)
        ..isAntiAlias = true;
      final a0 = start + sweep * t0;
      final a1 = start + sweep * t1;
      canvas.drawArc(rect, a0, a1 - a0, false, paint);
    }

    final angle = start + sweep * progress;
    final knob = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(knob, stroke * 0.48, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      stroke * 0.48,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x22E05A45),
    );
  }

  Color _lerpStops(double t) {
    final scaled = t.clamp(0.0, 1.0) * (_colors.length - 1);
    final i = scaled.floor().clamp(0, _colors.length - 2);
    final local = scaled - i;
    return Color.lerp(_colors[i], _colors[i + 1], local)!;
  }

  @override
  bool shouldRepaint(covariant _TemperatureGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ChangeChartSection extends StatelessWidget {
  const _ChangeChartSection({
    required this.changes,
    required this.shortest,
  });

  final List<_DailyChange> changes;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '최근 6일간의 온도 변화',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.034,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFE86A7A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(°C)',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: shortest * 0.024,
                color: _mutedGrey,
              ),
            ),
          ],
        ),
        SizedBox(height: shortest * 0.01),
        Expanded(
          child: changes.isEmpty
              ? Center(
                  child: Text(
                    '아직 기록된 온도 변화가 없어요.\n매일 새벽 2:50에 반영돼요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.03,
                      color: _mutedGrey,
                      height: 1.4,
                    ),
                  ),
                )
              : CustomPaint(
                  painter: _ChangeBarChartPainter(
                    changes: changes,
                    screenShortest: shortest,
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
      ],
    );
  }
}

class _ChangeBarChartPainter extends CustomPainter {
  _ChangeBarChartPainter({
    required this.changes,
    required this.screenShortest,
  });

  final List<_DailyChange> changes;
  /// 차트 위젯 높이가 줄어들어도 글자는 화면 기준으로 유지
  final double screenShortest;

  @override
  void paint(Canvas canvas, Size size) {
    const maxAbs = 1.0;
    const slotCount = 6;
    final leftPad = size.width * 0.14;
    final rightPad = size.width * 0.02;
    final topPad = screenShortest * 0.045;
    // Keep room under bars so negative value labels don't cover dates.
    final dateTpReserve = screenShortest * 0.05;
    final bottomPad = screenShortest * 0.095;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final midY = topPad + chartH / 2;
    final colW = chartW / slotCount;

    // Always show 6 columns; fill from the right with newest last.
    final visible = changes.length > slotCount
        ? changes.sublist(changes.length - slotCount)
        : changes;
    final slots = List<_DailyChange?>.filled(slotCount, null);
    final start = slotCount - visible.length;
    for (var i = 0; i < visible.length; i++) {
      slots[start + i] = visible[i];
    }

    final axisStyle = TextStyle(
      fontFamily: 'Cafe24Oneprettynight',
      fontSize: screenShortest * 0.03,
      color: const Color(0xFF5A564E),
      fontWeight: FontWeight.w700,
    );

    void drawYLabel(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: axisStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // 격자: ±1.0, ±0.5 점선 / 0은 실선
    final dashed = Paint()
      ..color = const Color(0xFFD8D2C6)
      ..strokeWidth = 1.1;
    final zeroLine = Paint()
      ..color = const Color(0xFFC8C2B6)
      ..strokeWidth = 1.6;

    for (final entry in [
      (0.0, '1.0'),
      (0.25, '0.5'),
      (0.5, '0'),
      (0.75, '-0.5'),
      (1.0, '-1.0'),
    ]) {
      final y = topPad + chartH * entry.$1;
      drawYLabel(entry.$2, y);
      if (entry.$1 == 0.5) {
        canvas.drawLine(
          Offset(leftPad, y),
          Offset(size.width - rightPad, y),
          zeroLine,
        );
      } else {
        _drawDashedLine(
          canvas,
          Offset(leftPad, y),
          Offset(size.width - rightPad, y),
          dashed,
        );
      }
    }

    for (var i = 0; i < slots.length; i++) {
      final item = slots[i];
      if (item == null) continue;
      final cx = leftPad + colW * (i + 0.5);
      final barHalf = colW * 0.26;
      final h = (item.value.abs() / maxAbs) * (chartH / 2);
      final positive = item.value >= 0;
      final top = positive ? midY - h : midY;
      final bottom = positive ? midY : midY + h;
      final minH = chartH * 0.04;
      final adjTop = positive && h < minH ? midY - minH : top;
      final adjBottom = !positive && h < minH ? midY + minH : bottom;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barHalf, adjTop, cx + barHalf, adjBottom),
        const Radius.circular(10),
      );

      final List<Color> colors;
      final Color valueColor;
      if (positive) {
        colors = const [Color(0xFFF8D34E), Color(0xFFF08A3A)];
        valueColor = const Color(0xFFC45E18);
      } else if ((item.value + 0.3).abs() < 0.05) {
        colors = const [Color(0xFFD0B4F0), Color(0xFF9B72D0)];
        valueColor = const Color(0xFF6B3FA0);
      } else {
        colors = const [Color(0xFFA8CFF5), Color(0xFF5B8FD4)];
        valueColor = const Color(0xFF2F5F9E);
      }

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      final valueTp = TextPainter(
        text: TextSpan(
          text: item.value.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: screenShortest * 0.034,
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final dateTop = size.height - dateTpReserve;
      final valueY = positive
          ? adjTop - valueTp.height - 1
          : math.min(adjBottom + 1, dateTop - valueTp.height - 2);
      valueTp.paint(
        canvas,
        Offset(cx - valueTp.width / 2, valueY),
      );

      final dateTp = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: const Color(0xFF4A4640),
            fontSize: screenShortest * 0.032,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      dateTp.paint(
        canvas,
        Offset(cx - dateTp.width / 2, size.height - dateTp.height),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * math.min(drawn + dash, total);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ChangeBarChartPainter oldDelegate) =>
      oldDelegate.changes != changes ||
      oldDelegate.screenShortest != screenShortest;
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({this.onTap});

  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: shortest * 0.03,
            vertical: shortest * 0.024,
          ),
          decoration: BoxDecoration(
            color: _tipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/familyondo/plant.png',
                width: shortest * 0.11,
                height: shortest * 0.13,
                fit: BoxFit.contain,
              ),
              SizedBox(width: shortest * 0.02),
              Expanded(
                child: Text(
                  '오늘의 질문에 답하면 가족 온도가 올라가요.\n'
                  '오늘의 질문에 답변하러 가볼까요?',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.032,
                    color: _bodyGrey,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            top: size.height * 0.05,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.3,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.07,
            child: Image.asset(
              'assets/images/todayquestionscreen/right_branch1.png',
              width: size.width * 0.32,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
