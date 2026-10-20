import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/family_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_controls.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../login/auth_scaffold.dart';
import '../login/email_login_screen.dart';
import 'family_done_screens.dart';

const _roles = ['아빠', '엄마', '아들', '딸'];
const _orders = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

/// "나는 우리 가족의?" + "몇째인가요?" (shared by 만들기 and 참여).
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.role,
    required this.order,
    required this.onRole,
    required this.onOrder,
  });

  final String? role;
  final int? order;
  final ValueChanged<String> onRole;
  final ValueChanged<int> onOrder;

  @override
  Widget build(BuildContext context) {
    final needOrder = role == '아들' || role == '딸';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const FieldLabel('나는 우리 가족의?'),
        Row(
          children: [
            for (var i = 0; i < _roles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: ChoiceChipBox(
                  height: 48.8, // 46 + 1.4px border each side
                  label: _roles[i],
                  selected: role == _roles[i],
                  onTap: () => onRole(_roles[i]),
                ),
              ),
            ],
          ],
        ),
        if (needOrder) ...[
          const SizedBox(height: 18),
          const FieldLabel('몇째인가요?'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _orders.length; i++)
                _OrderChip(label: _orders[i], selected: order == i, onTap: () => onOrder(i)),
            ],
          ),
        ],
      ],
    );
  }
}

/// "첫째 …" pill: 38 tall, padding 0 14, text centered; only the press
/// scale (.95) is transitioned, the fill swaps at once.
class _OrderChip extends StatelessWidget {
  const _OrderChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 40.8, // 38 + 1.4px border each side
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? HaruColors.forest : HaruColors.ivory,
          borderRadius: BorderRadius.circular(HaruRadius.full),
          border: Border.all(color: selected ? HaruColors.forest : HaruColors.fieldBorder, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: hr(15, color: selected ? Colors.white : HaruColors.forest)),
          ],
        ),
      ),
    );
  }
}

String? _birthLabel(String? role, int? order) =>
    order == null || role == null ? null : '${_orders[order]} $role';

/// 가족 만들기 — 가족 이름 + 역할.
class FamilyCreateScreen extends StatefulWidget {
  const FamilyCreateScreen({super.key});

  @override
  State<FamilyCreateScreen> createState() => _FamilyCreateScreenState();
}

class _FamilyCreateScreenState extends State<FamilyCreateScreen> {
  final _name = TextEditingController();
  final _service = FamilyService();
  String? _role;
  int? _order;
  bool _busy = false;
  String? _error;

  bool get _needOrder => _role == '아들' || _role == '딸';
  bool get _valid => _name.text.trim().isNotEmpty && _role != null && (!_needOrder || _order != null);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _service.create(
        familyName: _name.text.trim(),
        roleLabel: _role!,
        birthOrderLabel: _needOrder ? _birthLabel(_role, _order) : null,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        flowRoute<void>(FamilyCreatedScreen(familyName: r.familyName, code: r.inviteCode)),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '가족을 만들지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _name.text.trim().isEmpty ? '○○' : _name.text.trim();
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop()),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('우리 가족 이름을\n지어주세요', style: HaruType.headline),
          const SizedBox(height: 20),
          HrCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text('편지에는 이렇게 적혀요', style: hr(13.5, color: HaruColors.inkMuted)),
                const SizedBox(height: 2),
                Text('To. $preview 가족', style: hrHand(24)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          HaruTextField(
            controller: _name,
            placeholder: '예: 하루',
            maxLength: 10,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
          ),
          _RolePicker(
            role: _role,
            order: _order,
            onRole: (r) => setState(() {
              _role = r;
              _order = null;
            }),
            onOrder: (o) => setState(() => _order = o),
          ),
          if (_error != null) FieldError(_error!),
          const SizedBox(height: 28),
          PrimaryButton(label: '가족 만들기', loading: _busy, onPressed: _valid ? _submit : null),
        ],
      ),
    );
  }
}

/// 가족 참여 — 가족 코드 + 역할.
class FamilyJoinScreen extends StatefulWidget {
  const FamilyJoinScreen({super.key});

  @override
  State<FamilyJoinScreen> createState() => _FamilyJoinScreenState();
}

class _FamilyJoinScreenState extends State<FamilyJoinScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _service = FamilyService();
  String? _role;
  int? _order;
  bool _busy = false;
  String? _error;

  /// hrShake 420ms cubic-bezier(.36,.07,.19,.97) on a failed code.
  static const _shakeCurve = Cubic(.36, .07, .19, .97);
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  bool get _needOrder => _role == '아들' || _role == '딸';
  bool get _valid => _code.text.length == 6 && _role != null && (!_needOrder || _order != null);

  @override
  void dispose() {
    _code.dispose();
    _shake.dispose();
    super.dispose();
  }

  String _joinError(Object e) {
    final t = e.toString();
    final status = e is ApiException ? e.statusCode : null;
    if (status == 404 || t.contains('(404)') || t.contains('not found')) {
      return '가족을 찾지 못했어요. 코드를 다시 확인해주세요.';
    }
    if (status == 410 || t.contains('(410)') || t.contains('scheduled for deletion')) {
      return '삭제 예정인 가족에는 참여할 수 없어요.';
    }
    if (status == 409 || t.contains('(409)') || t.contains('already belongs')) {
      return '이미 다른 가족에 참여 중이에요.';
    }
    return '가족에 참여하지 못했어요. 다시 시도해주세요.';
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _service.join(
        inviteCode: _code.text,
        roleLabel: _role!,
        birthOrderLabel: _needOrder ? _birthLabel(_role, _order) : null,
      );
      if (!mounted) return;
      await Navigator.of(context).push(flowRoute<void>(FamilyJoinedScreen(familyName: r.familyName)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _joinError(e));
      _shake.forward(from: 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      back: FlowBackRow(onBack: () => Navigator.of(context).maybePop()),
      builder: (context, minHeight, shift) => FlowForm(
        minHeight: minHeight,
        shift: shift,
        children: [
          const SizedBox(height: 8),
          Text('가족에게 받은\n코드를 입력해주세요', style: HaruType.headline),
          const SizedBox(height: 8),
          Text('영문과 숫자로 된 6자리 코드예요', style: hr(15, color: HaruColors.inkMuted)),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, c) {
              // 0%,100% none · 20%,60% −7px · 40%,80% +7px, the timing
              // function applied per keyframe segment.
              const stops = [0.0, -7.0, 7.0, -7.0, 7.0, 0.0];
              final p = _shake.value * 5;
              final i = p.floor().clamp(0, 4);
              final x = stops[i] + (stops[i + 1] - stops[i]) * _shakeCurve.transform((p - i).clamp(0.0, 1.0));
              return Transform.translate(offset: Offset(x, 0), child: c);
            },
            child: HaruTextField(
              controller: _code,
              placeholder: 'A7K2QM',
              height: 64,
              textAlign: TextAlign.center,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              style: hrHand(30, weight: FontWeight.w400, letterSpacing: 4),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
              ],
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          if (_error != null) FieldError(_error!),
          _RolePicker(
            role: _role,
            order: _order,
            onRole: (r) => setState(() {
              _role = r;
              _order = null;
            }),
            onOrder: (o) => setState(() => _order = o),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: '참여하기', loading: _busy, onPressed: _valid ? _submit : null),
        ],
      ),
    );
  }
}
