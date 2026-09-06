import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF5F5F5F);

class PolicyDocumentScreen extends StatefulWidget {
  const PolicyDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  static const termsAsset = 'assets/policy/terms_of_use.txt';
  static const privacyAsset = 'assets/policy/privacy_policy.txt';

  @override
  State<PolicyDocumentScreen> createState() => _PolicyDocumentScreenState();
}

class _PolicyDocumentScreenState extends State<PolicyDocumentScreen> {
  late final Future<String> _bodyFuture;

  @override
  void initState() {
    super.initState();
    _bodyFuture = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        foregroundColor: _titleGreen,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: _titleGreen,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _bodyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _titleGreen),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                '문서를 불러오지 못했습니다.',
                style: TextStyle(color: _bodyGrey),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(
                color: _bodyGrey,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          );
        },
      ),
    );
  }
}
