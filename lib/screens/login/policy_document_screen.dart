import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';

/// 03 약관 / 개인정보 처리방침 — bundled text documents.
class PolicyDocumentScreen extends StatelessWidget {
  const PolicyDocumentScreen({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  static const termsAsset = 'assets/policy/terms_of_use.txt';
  static const privacyAsset = 'assets/policy/privacy_policy.txt';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            HaruSubHeader(title: title),
            Expanded(
              child: FutureBuilder<String>(
                future: rootBundle.loadString(assetPath),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: HaruColors.primary));
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      HaruOutlineCard(
                        child: SelectableText(
                          snap.data!.trim(),
                          style: haruText(14, height: 1.7, color: HaruColors.dsInkSecondary),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
