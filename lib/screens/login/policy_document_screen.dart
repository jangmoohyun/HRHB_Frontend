import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_decor.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';

/// 이용약관 / 개인정보처리방침 — the bundled legal text, laid out like the
/// prototype's policy page (ivory card, dashed section rules).
class PolicyDocumentScreen extends StatelessWidget {
  const PolicyDocumentScreen({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  static const termsAsset = 'assets/policy/terms_of_use.txt';
  static const privacyAsset = 'assets/policy/privacy_policy.txt';

  @override
  Widget build(BuildContext context) {
    final inShell = Scaffold.maybeOf(context) != null;
    final body = FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snap) {
        final doc = snap.hasData ? _PolicyDoc.parse(snap.data!) : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
          children: [
            // style-active scale(.96) + brightness(.96), no transition.
            SubHeader(title: title, backScale: .96, backDuration: Duration.zero, backInlineTransition: false),
            if (doc != null)
              HrCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (doc.effective != null) ...[
                      Text('시행일 ${doc.effective}', style: hr(14, color: HaruColors.inkMuted)),
                      const SizedBox(height: 10),
                    ],
                    for (final s in doc.sections) _SectionView(s),
                  ],
                ),
              ),
          ],
        );
      },
    );
    final page = EdgeSwipeBack(child: SafeArea(bottom: false, child: body));
    // Opened from 로그인 (no shell around it) it needs its own canvas.
    return inShell
        ? Material(type: MaterialType.transparency, child: page)
        : Scaffold(backgroundColor: HaruColors.cream, body: page);
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView(this.s);

  final _Section s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashLine(color: HaruColors.fieldBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.heading != null) Text(s.heading!, style: hr(16, color: HaruColors.forest)),
              if (s.body.isNotEmpty) ...[
                if (s.heading != null) const SizedBox(height: 4),
                SelectableText(s.body, style: hr(14.5, height: 1.6)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Section {
  _Section(this.heading, this.body);
  final String? heading;
  String body;
}

class _PolicyDoc {
  _PolicyDoc(this.sections, this.effective);

  final List<_Section> sections;

  /// "2026년 8월 8일" from the 부칙 line.
  final String? effective;

  static final _heading = RegExp(r'^(제\s*\d+\s*조|\d+\.\s|부칙)');

  static _PolicyDoc parse(String raw) {
    final blocks = raw
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    // First block is the document title, already in the header.
    if (blocks.isNotEmpty) blocks.removeAt(0);
    final sections = <_Section>[];
    for (final b in blocks) {
      final lines = b.split('\n');
      if (_heading.hasMatch(lines.first)) {
        sections.add(_Section(lines.first.trim(), lines.skip(1).join('\n').trim()));
      } else if (sections.isEmpty) {
        sections.add(_Section(null, b));
      } else {
        final last = sections.last;
        last.body = last.body.isEmpty ? b : '${last.body}\n\n$b';
      }
    }
    final m = RegExp(r'(\d{4}년\s*\d{1,2}월\s*\d{1,2}일)부터 시행').firstMatch(raw);
    return _PolicyDoc(sections, m?.group(1));
  }
}
