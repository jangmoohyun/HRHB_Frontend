import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/expandable_letter_paper.dart';

import 'write_answer_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _buttonGreen = Color(0xFF2F8F4E);
const _bodyGrey = Color(0xFF4A4A4A);
const _dashGreen = Color(0xFF7FA87A);

class FamilyAnswer {
  const FamilyAnswer({
    required this.role,
    required this.text,
    this.imageUrl,
    this.isMe = false,
  });

  final String role;
  final String text;
  final String? imageUrl;
  final bool isMe;
}

class FamilyAnswersScreen extends StatefulWidget {
  const FamilyAnswersScreen({
    super.key,
    required this.familyName,
    required this.date,
    required this.question,
    required this.dailyQuestionId,
  });

  final String familyName;
  final DateTime date;
  final String question;
  final int dailyQuestionId;

  @override
  State<FamilyAnswersScreen> createState() => _FamilyAnswersScreenState();
}

class _FamilyAnswersScreenState extends State<FamilyAnswersScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  bool _loading = true;
  String? _error;
  List<FamilyAnswer> _answers = const [];
  String? _myAnswerText;
  String? _myImageUrl;

  String get _monthDay => '${widget.date.month}/${widget.date.day}';

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var accessToken = await _tokenStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('로그인이 필요합니다.');
      }

      late final DailyAnswerListResult result;
      try {
        result = await _apiClient.fetchDailyAnswers(
          accessToken: accessToken,
          dailyQuestionId: widget.dailyQuestionId,
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
        result = await _apiClient.fetchDailyAnswers(
          accessToken: pair.accessToken,
          dailyQuestionId: widget.dailyQuestionId,
        );
      }

      if (!mounted) return;
      String? myText;
      String? myImageUrl;
      final mapped = result.answers.map((item) {
        if (item.isMe) {
          myText = item.content;
          myImageUrl = item.imageUrl;
        }
        return FamilyAnswer(
          role: item.roleLabel,
          text: item.content,
          imageUrl: item.imageUrl,
          isMe: item.isMe,
        );
      }).toList();

      setState(() {
        _answers = mapped;
        _myAnswerText = myText;
        _myImageUrl = myImageUrl;
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

  Future<void> _openWriteAnswer() async {
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WriteAnswerScreen(
            familyName: widget.familyName,
            question: widget.question,
            date: widget.date,
            dailyQuestionId: widget.dailyQuestionId,
            initialContent: _myAnswerText,
            initialImageUrl: _myImageUrl,
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
    if (saved == true && mounted) {
      await _loadAnswers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final letterWidth = size.width * 0.88;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    final letter = ExpandableLetterPaper(
      width: letterWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'To. ${widget.familyName} 가족',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'FamilyNameDate',
              fontSize: shortest * 0.072,
              color: _titleGreen,
              height: 1.1,
            ),
          ),
          SizedBox(height: size.height * 0.01),
          SizedBox(
            height: shortest * 0.06,
            child: Row(
              children: [
                Expanded(
                  child: Image.asset(
                    'assets/images/todayquestionscreen/redline2.png',
                    height: 22,
                    fit: BoxFit.fill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Image.asset(
                    'assets/images/todayquestionscreen/redheart.png',
                    width: shortest * 0.042,
                    height: shortest * 0.042,
                    fit: BoxFit.contain,
                  ),
                ),
                Expanded(
                  child: Image.asset(
                    'assets/images/todayquestionscreen/redline2.png',
                    height: 22,
                    fit: BoxFit.fill,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: size.height * 0.008),
          Column(
            children: [
              Text(
                _monthDay,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'FamilyNameDate',
                  fontSize: shortest * 0.075,
                  color: _titleGreen,
                  height: 0.95,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Image.asset(
                  'assets/images/todayquestionscreen/dateunderline.png',
                  width: shortest * 0.22,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.01),
          Text(
            widget.question,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Question',
              fontSize: shortest * 0.072,
              height: 1.35,
              color: _bodyGrey,
            ),
          ),
          SizedBox(height: size.height * 0.016),
          const _AnswerDivider(),
          SizedBox(height: size.height * 0.016),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: _titleGreen),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Text(
                    '답변을 불러오지 못했어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      color: _bodyGrey,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadAnswers,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          else if (_answers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '아직 작성된 답변이 없어요.\n먼저 답변을 남겨볼까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  color: _bodyGrey,
                  height: 1.4,
                ),
              ),
            )
          else
            for (var i = 0; i < _answers.length; i++) ...[
              if (i > 0) SizedBox(height: size.height * 0.018),
              _AnswerRow(answer: _answers[i], shortest: shortest),
            ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SideBranches(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.04),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _titleGreen,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/todayquestionscreen/greenheart1.png',
                              width: 14,
                              height: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '답변 보기',
                              style: TextStyle(
                                fontFamily: 'Cafe24Oneprettynight',
                                fontSize: shortest * 0.055,
                                color: _titleGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/images/todayquestionscreen/greenheart1.png',
                              width: 14,
                              height: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      size.width * 0.06,
                      size.height * 0.01,
                      size.width * 0.06,
                      bottomPad + shortest * 0.15,
                    ),
                    child: Column(
                      children: [
                        Center(child: letter),
                        SizedBox(height: size.height * 0.022),
                        SizedBox(
                          width: letterWidth * 0.72,
                          height: size.height * 0.056,
                          child: FilledButton(
                            onPressed: _loading ? null : _openWriteAnswer,
                            style: FilledButton.styleFrom(
                              backgroundColor: _buttonGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _buttonGreen.withValues(alpha: 0.45),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _myAnswerText == null ? '답변하기' : '답변 수정',
                              style: TextStyle(
                                fontFamily: 'Cafe24Oneprettynight',
                                fontSize: shortest * 0.045,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
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
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answer, required this.shortest});

  final FamilyAnswer answer;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    final photoUrl = answer.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          answer.role,
          style: TextStyle(
            fontFamily: 'FamilyNameDate',
            fontSize: shortest * 0.042,
            color: _titleGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer.text,
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.042,
            height: 1.35,
            color: _bodyGrey,
          ),
        ),
        if (photoUrl != null) ...[
          SizedBox(height: shortest * 0.025),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: const Color(0xFFE8E0D4),
              child: Image.network(
                photoUrl,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _titleGreen,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: _dashGreen,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerDivider extends StatelessWidget {
  const _AnswerDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _DashedLine(color: _dashGreen),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Image.asset(
            'assets/images/todayquestionscreen/greenheart2.png',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
        ),
        const Expanded(
          child: _DashedLine(color: _dashGreen),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashPainter(color: color),
        size: const Size(double.infinity, 1),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
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
