import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/family_service.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

import '../login/auth_scaffold.dart';
import 'family_done_screens.dart';

const _roles = ['아빠', '엄마', '아들', '딸'];
const _orders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

/// 09 가족 생성 / 11 가족 참여 (same form, prototype `obForm`).
class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({super.key, required this.joining});

  final bool joining;

  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends State<FamilyFormScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _service = FamilyService();
  String? _role;
  int? _birth; // index into _orders
  bool _submitting = false;
  String? _error;

  bool get _needBirth => _role == '아들' || _role == '딸';

  bool get _invalid =>
      _role == null ||
      (_needBirth && _birth == null) ||
      (widget.joining ? _code.text.isEmpty : _name.text.trim().isEmpty);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final i = await showHaruPicker(
      context,
      title: '나는 우리 가족의?',
      options: _roles,
      selected: _role == null ? null : _roles.indexOf(_role!),
    );
    if (i == null) return;
    setState(() {
      final next = _roles[i];
      if (next == '아들' || next == '딸') {
        // Keep the birth order when switching between 아들 and 딸.
        if (!_needBirth) _birth = null;
      } else {
        _birth = null;
      }
      _role = next;
      _error = null;
    });
  }

  Future<void> _pickBirth() async {
    final role = _role;
    if (role == null) return;
    final i = await showHaruPicker(
      context,
      title: '몇째 $role인가요?',
      options: [for (final o in _orders) '$o $role'],
      selected: _birth,
    );
    if (i != null) setState(() => _birth = i);
  }

  String? get _birthLabel => _birth == null ? null : '${_orders[_birth!]} $_role';

  String _joinError(Object e) {
    final t = e.toString();
    final status = e is ApiException ? e.statusCode : null;
    if (status == 404 || t.contains('(404)') || t.contains('not found')) {
      return '가족 코드를 찾을 수 없어요.';
    }
    if (status == 410 || t.contains('(410)') || t.contains('scheduled for deletion')) {
      return '삭제 예정인 가족에는 참여할 수 없어요.';
    }
    if (status == 409 || t.contains('(409)') || t.contains('already belongs')) {
      return '이미 다른 가족에 참여 중이에요.';
    }
    return '가족에 참여하지 못했어요. 다시 시도해 주세요.';
  }

  Future<void> _submit() async {
    if (_invalid || _submitting) return;
    if (widget.joining && _code.text.length != 6) {
      setState(() => _error = '초대 코드 6자리를 확인해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final r = widget.joining
          ? await _service.join(inviteCode: _code.text, roleLabel: _role!, birthOrderLabel: _birthLabel)
          : await _service.create(
              familyName: _name.text.trim(),
              roleLabel: _role!,
              birthOrderLabel: _birthLabel,
            );
      if (!mounted) return;
      final role = FamilyMemberResult.labelFor(role: r.role, birthOrder: r.birthOrder);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.joining
              ? FamilyJoinedScreen(familyName: r.familyName, roleLabel: role)
              : FamilyCreatedScreen(familyName: r.familyName, code: r.inviteCode),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.joining ? _joinError(e) : '가족을 만들지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: widget.joining ? '가족 참여하기' : '새 가족 만들기',
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      gap: 20,
      children: [
        if (widget.joining)
          HaruTextField(
            label: '초대 코드',
            controller: _code,
            hint: 'A7K2QM',
            height: 56,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 6,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              TextInputFormatter.withFunction(
                (_, v) => v.copyWith(text: v.text.toUpperCase()),
              ),
            ],
            helper: '영문은 자동으로 대문자로 바뀌어요.',
            onChanged: (_) => setState(() => _error = null),
          )
        else
          HaruTextField(
            label: '가족 이름',
            controller: _name,
            hint: '예: 행복한 우리집',
            onChanged: (_) => setState(() {}),
          ),
        HaruSelectField(
          label: '나의 역할',
          value: _role,
          placeholder: '역할을 선택해 주세요',
          trailingIcon: LucideIcons.chevronDown,
          onTap: _pickRole,
        ),
        if (_needBirth)
          HaruSelectField(
            label: '출생 순서',
            value: _birthLabel,
            placeholder: '몇째인지 선택해 주세요',
            trailingIcon: LucideIcons.chevronDown,
            onTap: _pickBirth,
          ),
        if (_error != null) HaruFieldError(_error!, icon: LucideIcons.circleAlert),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: HaruButton(
            label: widget.joining ? '참여하기' : '가족 만들기',
            size: HaruButtonSize.lg,
            fullWidth: true,
            loading: _submitting,
            onPressed: _invalid ? null : _submit,
          ),
        ),
      ],
    );
  }
}
