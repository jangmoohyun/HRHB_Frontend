import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'question_ref.dart';

/// 16 답변 작성 — pops `true` after a successful save.
class WriteAnswerPage extends StatefulWidget {
  const WriteAnswerPage({
    super.key,
    required this.question,
    this.initialContent,
    this.initialImageUrl,
  });

  final QuestionRef question;
  final String? initialContent;
  final String? initialImageUrl;

  @override
  State<WriteAnswerPage> createState() => _WriteAnswerPageState();
}

class _WriteAnswerPageState extends State<WriteAnswerPage> {
  static const _maxLength = 500;

  final _api = ApiClient();
  final _picker = ImagePicker();
  late final _controller = TextEditingController(text: widget.initialContent ?? '');

  bool _saving = false;
  XFile? _picked;
  late final String? _existingUrl = widget.initialImageUrl;
  bool _removeExisting = false;

  bool get _hasExisting =>
      _existingUrl != null && _existingUrl.isNotEmpty && !_removeExisting;
  bool get _hasPhoto => _picked != null || _hasExisting;
  bool get _canSave => _controller.text.trim().isNotEmpty && !_saving;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/jpeg' || mime == 'image/webp') {
      return mime!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Copies the picked file into the temp dir so it survives the picker's
  /// cleanup (unchanged from v1).
  Future<XFile> _copyLocally(XFile file) async {
    final contentType = _contentTypeFor(file);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('사진을 읽을 수 없어요.');
    final dest = File(
      '${Directory.systemTemp.path}/answer_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
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
      if (!mounted) return;
      HaruToast.show(
        context,
        '사진을 불러오지 못했어요. 다른 사진을 골라 주세요.',
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );
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

  Future<void> _save() async {
    final id = widget.question.dailyQuestionId;
    final text = _controller.text.trim();
    if (id == null || text.isEmpty || _saving) return;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    try {
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
      if (!mounted) return;
      HomeShellScope.maybeOf(context)?.notifyDataChanged();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      HaruToast.show(
        context,
        _errorMessage(error),
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final dateLabel = '${q.isToday ? '오늘 · ' : ''}${fullDate(q.date)}';
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: HaruColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const HaruSubHeader(title: '답변 작성'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, kTabBarClearance),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLabel, style: haruText(13, color: HaruColors.dsInkFaint)),
                          const SizedBox(height: 6),
                          Text(
                            q.content,
                            style: haruText(
                              22,
                              weight: FontWeight.w700,
                              height: 1.35,
                              letterSpacing: -0.3,
                              color: HaruColors.dsInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('나의 답변', style: HaruType.fieldLabel),
                    const SizedBox(height: 6),
                    HaruTextField(
                      controller: _controller,
                      hint: '천천히 떠올려 보세요.',
                      maxLength: _maxLength,
                      maxLines: 7,
                      minLines: 7,
                      height: null,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_controller.text.characters.length} / $_maxLength',
                        style: haruText(13, color: HaruColors.dsInkFaint),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text.rich(
                      TextSpan(
                        text: '사진 ',
                        style: HaruType.fieldLabel,
                        children: [
                          TextSpan(
                            text: '(선택)',
                            style: haruText(14, color: HaruColors.dsInkFaint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!_hasPhoto) ...[
                      Pressable(
                        onTap: _pickPhoto,
                        scale: 0.98,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: HaruColors.surface,
                            border: Border.all(color: HaruColors.hairline),
                            borderRadius: BorderRadius.circular(HaruRadius.md),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.imagePlus, size: 20, color: HaruColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '사진 첨부하기',
                                style: haruText(15, weight: FontWeight.w500, color: HaruColors.dsInk),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'JPEG · PNG · WebP 이미지 1장을 첨부할 수 있어요.',
                        style: haruText(13, color: HaruColors.dsInkFaint),
                      ),
                    ] else
                      SizedBox(
                        height: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(HaruRadius.md),
                              child: _picked != null
                                  ? Image.file(File(_picked!.path), fit: BoxFit.cover)
                                  : Image.network(_existingUrl!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: HaruIconButton(
                                icon: LucideIcons.x,
                                label: '사진 빼기',
                                variant: HaruIconButtonVariant.surface,
                                size: 32,
                                onPressed: _removePhoto,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    HaruButton(
                      label: _saving ? '저장하고 있어요…' : '답변 저장하기',
                      size: HaruButtonSize.lg,
                      fullWidth: true,
                      onPressed: _canSave ? _save : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
