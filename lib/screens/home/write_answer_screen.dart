import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/expandable_letter_paper.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _buttonGreen = Color(0xFF2F8F4E);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _fieldFill = Color(0xFFFFFCF6);
const _fieldBorder = Color(0xFFC5D9B8);
const _photoBtn = Color(0xFFF3EFE3);

class WriteAnswerScreen extends StatefulWidget {
  const WriteAnswerScreen({
    super.key,
    required this.familyName,
    required this.question,
    required this.dailyQuestionId,
    this.date,
    this.initialContent,
    this.initialImageUrl,
  });

  final String familyName;
  final String question;
  final int dailyQuestionId;
  final DateTime? date;
  final String? initialContent;
  final String? initialImageUrl;

  @override
  State<WriteAnswerScreen> createState() => _WriteAnswerScreenState();
}

class _WriteAnswerScreenState extends State<WriteAnswerScreen> {
  static const _maxLength = 500;

  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();
  final _picker = ImagePicker();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  XFile? _pickedFile;
  String? _existingImageUrl;
  bool _removeExisting = false;

  bool get _hasPhoto =>
      _pickedFile != null ||
      (_existingImageUrl != null &&
          _existingImageUrl!.isNotEmpty &&
          !_removeExisting);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialContent?.trim();
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
    }
    _existingImageUrl = widget.initialImageUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<String> _requireAccessToken() async {
    var accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    return accessToken;
  }

  Future<String> _withAuthRetry(Future<String> Function(String token) action) async {
    try {
      final token = await _requireAccessToken();
      return await action(token);
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

  Future<XFile> _copyPickedFileLocally(XFile file) async {
    final contentType = _contentTypeFor(file);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('사진을 읽을 수 없어요. 다른 사진을 선택해주세요.');
    }
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
      final local = await _copyPickedFileLocally(file);
      if (!mounted) return;
      setState(() {
        _pickedFile = local;
        _removeExisting = false;
      });
    } catch (error) {
      debugPrint('pick photo failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 다른 사진을 선택해주세요.')),
      );
    }
  }

  void _clearPhoto() {
    setState(() {
      _pickedFile = null;
      if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        _removeExisting = true;
      }
    });
  }

  String _saveErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Unsupported contentType') ||
        text.contains('사진을 읽을 수 없어요') ||
        text.contains('PathNotFound') ||
        text.contains('No such file')) {
      return '이 사진은 올릴 수 없어요. JPEG/PNG로 다시 선택해주세요.';
    }
    if (text.contains('S3 upload failed') ||
        text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Timeout')) {
      return '사진 업로드에 실패했어요. 네트워크 확인 후 다시 시도해주세요.';
    }
    if (text.contains('(401)') || text.contains('로그인이 필요합니다')) {
      return '로그인이 만료됐어요. 다시 로그인한 뒤 저장해주세요.';
    }
    return '저장에 실패했어요. 다시 시도해주세요.';
  }

  Future<void> _onSave() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답변을 입력해주세요.')),
      );
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    FocusScope.of(context).unfocus();

    try {
      String? uploadedKey;
      if (_pickedFile != null) {
        final contentType = _contentTypeFor(_pickedFile!);
        final bytes = await _pickedFile!.readAsBytes();
        final upload = await _withAuthRetry((token) async {
          final url = await _apiClient.createAnswerPhotoUploadUrl(
            accessToken: token,
            dailyQuestionId: widget.dailyQuestionId,
            contentType: contentType,
          );
          await _apiClient.uploadBytesToPresignedUrl(
            uploadUrl: url.uploadUrl,
            bytes: bytes,
            contentType: url.contentType,
          );
          return url.imageKey;
        });
        uploadedKey = upload;
      }

      await _withAuthRetry((token) async {
        await _apiClient.saveDailyAnswer(
          accessToken: token,
          dailyQuestionId: widget.dailyQuestionId,
          content: text,
          imageKey: uploadedKey,
          removeImage: uploadedKey == null && _removeExisting,
        );
        return token;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답변이 저장되었어요.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('save daily answer failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saveErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final letterWidth = size.width * 0.88;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
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
                _Header(shortest: shortest),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      size.width * 0.05,
                      size.height * 0.008,
                      size.width * 0.05,
                      bottomPad + shortest * 0.15,
                    ),
                    child: Column(
                      children: [
                        _ToBanner(
                          date: widget.date ?? DateTime.now(),
                          shortest: shortest,
                        ),
                        SizedBox(height: size.height * 0.014),
                        ExpandableLetterPaper(
                          width: letterWidth,
                          padding: EdgeInsets.fromLTRB(
                            letterWidth * 0.12,
                            letterWidth * 0.08,
                            letterWidth * 0.08,
                            letterWidth * 0.1,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionLabel(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: '오늘의 질문',
                                shortest: shortest,
                              ),
                              SizedBox(height: size.height * 0.01),
                              Text(
                                widget.question,
                                style: TextStyle(
                                  fontFamily: 'Question',
                                  fontSize: shortest * 0.042,
                                  height: 1.4,
                                  color: _bodyGrey,
                                ),
                              ),
                              SizedBox(height: size.height * 0.016),
                              const _HeartDivider(),
                              SizedBox(height: size.height * 0.016),
                              _SectionLabel(
                                icon: Icons.eco_outlined,
                                label: '나의 답변',
                                shortest: shortest,
                              ),
                              SizedBox(height: size.height * 0.01),
                              _AnswerField(
                                controller: _controller,
                                focusNode: _focus,
                                maxLength: _maxLength,
                                shortest: shortest,
                                onChanged: (_) => setState(() {}),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${_controller.text.characters.length}/$_maxLength',
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      fontSize: shortest * 0.032,
                                      color: _softGreen,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: size.height * 0.016),
                              _SectionLabel(
                                icon: Icons.photo_outlined,
                                label: '사진 첨부 (선택)',
                                shortest: shortest,
                              ),
                              SizedBox(height: size.height * 0.01),
                              if (_hasPhoto) ...[
                                _PhotoPreview(
                                  shortest: shortest,
                                  filePath: _pickedFile?.path,
                                  networkUrl: _pickedFile == null
                                      ? _existingImageUrl
                                      : null,
                                  onRemove: _clearPhoto,
                                  onChange: _pickPhoto,
                                ),
                              ] else
                                _PhotoAttachButton(
                                  shortest: shortest,
                                  onTap: _pickPhoto,
                                ),
                              SizedBox(height: size.height * 0.008),
                              Text(
                                _hasPhoto
                                    ? '사진을 바꾸거나 제거할 수 있어요.'
                                    : 'JPEG / PNG / WEBP 이미지를 첨부할 수 있어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cafe24Oneprettynight',
                                  fontSize: shortest * 0.028,
                                  color: _mutedGrey,
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              SizedBox(
                                width: double.infinity,
                                height: size.height * 0.056,
                                child: FilledButton(
                                  onPressed: _saving ? null : _onSave,
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
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          '♥  답변 저장하기  ♥',
                                          style: TextStyle(
                                            fontFamily: 'Cafe24Oneprettynight',
                                            fontSize: shortest * 0.042,
                                            fontWeight: FontWeight.w700,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.shortest,
  });

  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: shortest * 0.02),
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
                  '답변 작성하기',
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
    );
  }
}

class _ToBanner extends StatelessWidget {
  const _ToBanner({
    required this.date,
    required this.shortest,
  });

  final DateTime date;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    final width = shortest * 0.52;
    final height = shortest * 0.16;

    return SizedBox(
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
            padding: EdgeInsets.only(top: height * 0.08),
            child: Text(
              '${date.month}/${date.day}',
              style: TextStyle(
                fontFamily: 'FamilyNameDate',
                fontSize: height * 0.36,
                color: _titleGreen,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.shortest,
  });

  final IconData icon;
  final String label;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: shortest * 0.045, color: _softGreen),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.038,
            color: _titleGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeartDivider extends StatelessWidget {
  const _HeartDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _DashedLine()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Image.asset(
            'assets/images/todayquestionscreen/greenheart2.png',
            width: 16,
            height: 16,
          ),
        ),
        const Expanded(child: _DashedLine()),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashPainter(color: _softGreen),
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

class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.shortest,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final double shortest;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          maxLines: 6,
          minLines: 5,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.04,
            height: 1.4,
            color: _bodyGrey,
          ),
          cursorColor: _titleGreen,
          decoration: InputDecoration(
            counterText: '',
            hintText: '답변을 입력해주세요...',
            hintStyle: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: shortest * 0.038,
              color: _mutedGrey,
            ),
            filled: true,
            fillColor: _fieldFill,
            contentPadding: EdgeInsets.fromLTRB(
              shortest * 0.04,
              size.height * 0.018,
              shortest * 0.04,
              size.height * 0.04,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _fieldBorder, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _softGreen, width: 1.6),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 8,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/images/public/sprout.png',
                width: shortest * 0.09,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.shortest,
    required this.onRemove,
    required this.onChange,
    this.filePath,
    this.networkUrl,
  });

  final double shortest;
  final String? filePath;
  final String? networkUrl;
  final VoidCallback onRemove;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath != null && filePath!.isNotEmpty;
    final hasNetwork = networkUrl != null && networkUrl!.isNotEmpty;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: _photoBtn,
            child: hasFile
                ? Image.file(
                    File(filePath!),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) =>
                        const _PhotoFallback(),
                  )
                : hasNetwork
                    ? Image.network(
                        networkUrl!,
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
                        errorBuilder: (_, error, stackTrace) =>
                            const _PhotoFallback(),
                      )
                    : const _PhotoFallback(),
          ),
        ),
        SizedBox(height: shortest * 0.02),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onChange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _titleGreen,
                  side: const BorderSide(color: _fieldBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '사진 바꾸기',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.034,
                  ),
                ),
              ),
            ),
            SizedBox(width: shortest * 0.02),
            Expanded(
              child: OutlinedButton(
                onPressed: onRemove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45757),
                  side: const BorderSide(color: Color(0xFFE0C4C4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '사진 제거',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.034,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      width: double.infinity,
      child: Center(
        child: Icon(Icons.image_outlined, color: _softGreen, size: 40),
      ),
    );
  }
}

class _PhotoAttachButton extends StatelessWidget {
  const _PhotoAttachButton({
    required this.shortest,
    required this.onTap,
  });

  final double shortest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _photoBtn,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: shortest * 0.035),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  color: _buttonGreen, size: shortest * 0.05),
              const SizedBox(width: 8),
              Text(
                '사진 첨부하기',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.038,
                  color: _titleGreen,
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
