import 'package:flutter/material.dart';

import 'package:hrhb_frontend/widgets/auth_branch_background.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const cream = Color(0xFFFDFBF0);
const titleGreen = Color(0xFF3A6A3F);
const bodyGrey = Color(0xFF5F5F5F);
const mutedGrey = Color(0xFF8F8F8F);
const buttonGreen = Color(0xFF3CB371);
const cardBg = Color(0xFFFFFCF3);

/// Login-style shell without the center letter — used by email signup/login.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboard > 0;

    return Scaffold(
      backgroundColor: cream,
      // Let Scaffold shrink for the keyboard — do NOT also pad by keyboard height.
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AuthBranchBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.04),
                  child: Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: titleGreen,
                            size: 20,
                          ),
                        )
                      else
                        SizedBox(width: shortest * 0.12),
                      const Spacer(),
                    ],
                  ),
                ),
                // Collapse brand block while typing so the form stays visible.
                if (!keyboardOpen)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                    child: Column(
                      children: [
                        Text(
                          '하루한번',
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.09,
                            height: 1.05,
                            color: titleGreen,
                          ),
                        ),
                        SizedBox(height: size.height * 0.01),
                        Text(
                          '가족을 잇는 감성 커뮤니케이션',
                          style: TextStyle(
                            fontSize: shortest * 0.032,
                            height: 1.3,
                            letterSpacing: -0.3,
                            color: mutedGrey,
                          ),
                        ),
                        SizedBox(height: size.height * 0.016),
                        const SproutDivider(),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    // No free scroll when keyboard is closed; allow scroll
                    // only so the confirm button stays reachable while typing.
                    physics: keyboardOpen
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      shortest * 0.08,
                      keyboardOpen ? size.height * 0.012 : size.height * 0.02,
                      shortest * 0.08,
                      size.height * 0.03,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.055,
                            color: titleGreen,
                          ),
                        ),
                        SizedBox(height: size.height * 0.01),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: shortest * 0.032,
                            height: 1.4,
                            color: mutedGrey,
                          ),
                        ),
                        SizedBox(height: size.height * 0.022),
                        child,
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

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final TextAlign textAlign;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      textAlign: textAlign,
      autofillHints: autofillHints,
      // Keep room for the confirm button under the focused field.
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: TextStyle(
        fontSize: shortest * 0.04,
        color: bodyGrey,
        letterSpacing: maxLength == 6 ? 6 : 0,
      ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: cardBg,
        hintText: hintText,
        hintStyle: const TextStyle(color: mutedGrey, letterSpacing: 0),
        contentPadding: EdgeInsets.symmetric(
          horizontal: shortest * 0.04,
          vertical: shortest * 0.04,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E4D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: buttonGreen, width: 1.4),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    return SizedBox(
      height: size.height * 0.056,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: buttonGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: buttonGreen.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: shortest * 0.04,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
