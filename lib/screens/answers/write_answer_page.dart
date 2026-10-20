import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../home/home_sheets.dart';
import '../shell/home_shell.dart';
import 'family_answers_page.dart';
import 'question_ref.dart';

/// 답장 쓰기 / 답장 고치기. On save the letter flies off with hearts and
/// the page is replaced by 가족 답장.
class WriteAnswerPage extends StatefulWidget {
  const WriteAnswerPage({
    super.key,
    required this.question,
    this.initialContent,
    this.initialImageUrl,
    this.replaceWithAnswers = true,
  });

  final QuestionRef question;
  final String? initialContent;
  final String? initialImageUrl;

  /// From 홈 the page is replaced by 가족 답장 (prototype). When 가족 답장
  /// itself opened it, just pop `true` so that page reloads in place.
  final bool replaceWithAnswers;

  @override
  State<WriteAnswerPage> createState() => _WriteAnswerPageState();
}

class _WriteAnswerPageState extends State<WriteAnswerPage> {
  static const _maxLength = 500;

  final _api = ApiClient();
  final _picker = ImagePicker();
  late final _controller = TextEditingController(text: widget.initialContent ?? '');

  bool _saving = false;
  bool _sending = false;
  XFile? _picked;
  late final String? _existingUrl = widget.initialImageUrl;
  bool _removeExisting = false;

  bool get _editing => (widget.initialContent ?? '').isNotEmpty;
  bool get _hasExisting => _existingUrl != null && _existingUrl.isNotEmpty && !_removeExisting;
  bool get _hasPhoto => _picked != null || _hasExisting;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/jpeg' || mime == 'image/webp') return mime!;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Copies the picked file into the temp dir so it survives the picker's
  /// cleanup.
  Future<XFile> _copyLocally(XFile file) async {
    final contentType = _contentTypeFor(file);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('사진을 읽을 수 없어요.');
    final dest = File('${Directory.systemTemp.path}/answer_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await dest.writeAsBytes(bytes, flush: true);
    return XFile(dest.path, mimeType: contentType, name: dest.uri.pathSegments.last);
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    try {
      final local = await _copyLocally(file);
      if (!mounted) return;
      setState(() {
        _picked = local;
        _removeExisting = false;
      });
    } catch (_) {
      if (mounted) HaruToast.show(context, '사진을 불러오지 못했어요. 다른 사진을 골라 주세요.');
    }
  }

  void _removePhoto() {
    setState(() {
      _picked = null;
      if (_existingUrl != null && _existingUrl.isNotEmpty) _removeExisting = true;
    });
  }

  String _errorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Unsupported contentType') ||
        text.contains('사진을 읽을 수 없어요') ||
        text.contains('PathNotFound') ||
        text.contains('No such file')) {
      return '이 사진은 올릴 수 없어요. JPEG나 PNG로 다시 골라 주세요.';
    }
    if (text.contains('S3 upload failed') ||
        text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Timeout')) {
      return '사진을 올리지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.';
    }
    if (error is NotSignedInException || text.contains('(401)')) {
      return '로그인이 만료됐어요. 다시 로그인한 뒤 저장해 주세요.';
    }
    return '저장하지 못했어요. 다시 시도해 주세요.';
  }

  Future<void> _upload(int id, String text) async {
    String? key;
    final picked = _picked;
    if (picked != null) {
      final contentType = _contentTypeFor(picked);
      final bytes = await picked.readAsBytes();
      key = await AuthedCall.run((token) async {
        final url = await _api.createAnswerPhotoUploadUrl(
          accessToken: token,
          dailyQuestionId: id,
          contentType: contentType,
        );
        await _api.uploadBytesToPresignedUrl(
          uploadUrl: url.uploadUrl,
          bytes: bytes,
          contentType: url.contentType,
        );
        return url.imageKey;
      });
    }
    await AuthedCall.run((token) => _api.saveDailyAnswer(
          accessToken: token,
          dailyQuestionId: id,
          content: text,
          imageKey: key,
          removeImage: key == null && _removeExisting,
        ));
  }

  Future<void> _save() async {
    final id = widget.question.dailyQuestionId;
    final text = _controller.text.trim();
    if (id == null || text.isEmpty || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _sending = true;
    });
    final hearts = _showHearts();
    try {
      // The letter flies off (≥560ms) while the answer uploads.
      await Future.wait([
        _upload(id, text),
        Future<void>.delayed(const Duration(milliseconds: 560)),
      ]);
    } catch (error) {
      if (!mounted) return;
      hearts?.remove();
      setState(() {
        _saving = false;
        _sending = false;
      });
      HaruToast.show(context, _errorMessage(error));
      return;
    }
    if (!mounted) return;
    HomeShellScope.maybeOf(context)?.notifyDataChanged();
    final nav = Navigator.of(context);
    if (!widget.replaceWithAnswers) {
      nav.pop(true);
      return;
    }
    nav.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: widget.question)),
    );
    afterAnswerSaved(nav.context, firstAnswer: !_editing, isToday: widget.question.isToday);
  }

  /// `heartsOn` (sending || justSent): the hearts stay up for 2600ms from the
  /// tap, so they keep rising over 가족 답장 after the page is replaced.
  OverlayEntry? _showHearts() {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box == null || !box.hasSize || overlay == null) return null;
    final origin = box.localToGlobal(Offset.zero);
    final width = box.size.width;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: origin.dx,
        width: width,
        top: origin.dy + 600,
        child: const _SendHearts(),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(milliseconds: 2600), () {
      if (entry.mounted) entry.remove();
    });
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final family = FamilyContext.instance.value?.name ?? '우리';
    final len = _controller.text.characters.length;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return EdgeSwipeBack(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnimatedOpacity(
          // opacity 380ms ease, 100ms delay
          opacity: _sending ? 0 : 1,
          duration: const Duration(milliseconds: 480),
          curve: const Interval(100 / 480, 1, curve: Curves.ease),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 480),
            curve: const Cubic(.5, 0, .75, 0),
            transformAlignment: const Alignment(0, -0.4), // 50% 30%
            transform: _sending
                ? (Matrix4.translationValues(0, -60, 0)
                    .multiplied(Matrix4.rotationZ(-2 * math.pi / 180))
                    .multiplied(Matrix4.diagonal3Values(.82, .82, 1)))
                : Matrix4.identity(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, kNavClearance + inset),
              children: [
                SubHeader(title: _editing ? '답장 고치기' : '답장 쓰기'),
                HrCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('To. $family 가족 · ${q.date.month}/${q.date.day}', style: hrHand(18)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 56, 12),
                            child: Text(q.content, style: hrQuestion(21, height: 1.42)),
                          ),
                          const HeartDivider(),
                        ],
                      ),
                      // Absolutely positioned, so it paints above the text.
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Opacity(
                          opacity: .9,
                          child: Image.asset(HaruImages.todayStamp, width: 54),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text('나의 답변', style: hr(16, color: HaruColors.forest))),
                      Text('$len/$_maxLength', style: hr(14.5, color: HaruColors.inkMuted)),
                    ],
                  ),
                ),
                HaruTextArea(
                  controller: _controller,
                  placeholder: '가족에게 하고 싶은 이야기를 편하게 적어 주세요.',
                  minHeight: 200,
                  maxLength: _maxLength,
                  fontSize: 17,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  onChanged: (_) => setState(() {}),
                  // right/bottom 12 from the wrapper; the overlay sits
                  // inside the 1.4px border. sprout.png keeps its ratio.
                  overlay: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(10.6),
                      child: Opacity(opacity: .55, child: Image.asset(HaruImages.sprout, width: 34)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
                  child: Text('사진 첨부 (선택)', style: hr(16, color: HaruColors.forest)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _hasPhoto ? _photoTile() : _addPhotoTile(),
                ),
                const SizedBox(height: 22),
                // HTML collapses the label's double spaces. Only an empty
                // draft disables it; a second tap while sending is ignored.
                PrimaryButton(
                  label: '♥ 답변 저장하기 ♥',
                  onPressed: _controller.text.trim().isEmpty ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addPhotoTile() {
    return Pressable(
      onTap: _pickPhoto,
      semanticLabel: '사진 추가',
      child: DashedBox(
        color: HaruColors.softGreen,
        radius: 14,
        strokeWidth: 1.4,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: HaruColors.ivory, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.add_photo_alternate_rounded, size: 28, color: HaruColors.softGreen),
              const SizedBox(height: 4),
              Text('사진 추가', style: hr(14.5, color: HaruColors.forest)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoTile() {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _picked != null
                  ? Image.file(File(_picked!.path), fit: BoxFit.cover)
                  : Image.network(
                      _existingUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: HaruColors.orange,
                        child: Icon(Symbols.image_rounded, size: 30, color: HaruColors.orangeInk),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Pressable(
              onTap: _removePhoto,
              semanticLabel: '사진 빼기',
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: HaruColors.ink, shape: BoxShape.circle),
                child: const Icon(Symbols.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six hearts rising from y=600 (prototype `sendHearts`).
class _SendHearts extends StatelessWidget {
  const _SendHearts();

  static const _hearts = [
    (38.0, 22.0, Color(0xFFE08A8A), 0),
    (46.0, 16.0, Color(0xFF2F8F4E), 80),
    (54.0, 26.0, Color(0xFFE08A8A), 40),
    (62.0, 18.0, Color(0xFF7FA87A), 120),
    (50.0, 30.0, Color(0xFFE08A8A), 160),
    (42.0, 14.0, Color(0xFFF09A4A), 200),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (x, size, color, delay) in _hearts)
                Positioned(
                  left: c.maxWidth * x / 100,
                  bottom: 0,
                  child: _RisingHeart(size: size, color: color, delay: delay),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// hrRise 1.1s: fade in by 18%, drift up 40px, fade out.
class _RisingHeart extends StatelessWidget {
  const _RisingHeart({required this.size, required this.color, required this.delay});

  final double size;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = 1100 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1),
      builder: (_, t, c) {
        // cubic-bezier(.33,1,.68,1) per keyframe segment.
        const e = HaruMotion.out;
        final op = t < .18 ? e.transform(t / .18) : 1 - e.transform((t - .18) / .82);
        return Opacity(
          opacity: op.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, 6 - 40 * e.transform(t)), child: c),
        );
      },
      child: Text('♥', style: hr(size, color: color)),
    );
  }
}
