import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlPattern = RegExp(
  r'((?:https?:\/\/|www\.)\S+)',
  caseSensitive: false,
);

final _trailingPunct = RegExp(r'[.,;:!?)\]>]+$');

/// 본문 속 URL을 탭하면 외부 브라우저로 연다.
class LinkableText extends StatefulWidget {
  const LinkableText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<LinkableText> createState() => _LinkableTextState();
}

class _LinkableTextState extends State<LinkableText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LinkableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String raw) async {
    var value = raw.trim();
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없어요.')),
      );
    }
  }

  List<InlineSpan> _buildSpans(TextStyle base, TextStyle link) {
    _disposeRecognizers();
    final text = widget.text;
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      var url = match.group(0)!;
      var trailing = '';
      final punct = _trailingPunct.firstMatch(url);
      if (punct != null) {
        trailing = punct.group(0)!;
        url = url.substring(0, url.length - trailing.length);
      }

      if (url.isNotEmpty) {
        final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: url,
            style: link,
            recognizer: recognizer,
          ),
        );
      }
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing));
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final link = widget.linkStyle ??
        base.copyWith(
          color: const Color(0xFF2F6FED),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF2F6FED),
        );

    if (!_urlPattern.hasMatch(widget.text)) {
      return Text(
        widget.text,
        style: base,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return Text.rich(
      TextSpan(style: base, children: _buildSpans(base, link)),
      textAlign: widget.textAlign ?? TextAlign.start,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
