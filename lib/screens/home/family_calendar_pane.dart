import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _ink = Color(0xFF2F3A2C);
const _hairline = Color(0xFFE5E8E0);
const _pillTrack = Color(0xFFE8F0E4);

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

class _Category {
  const _Category(this.id, this.label, this.color);
  final String id;
  final String label;
  final Color color;
}

const _categories = <_Category>[
  _Category('FAMILY', '가족', Color(0xFF5C8F5A)),
  _Category('SCHOOL', '학교', Color(0xFF4A7AB5)),
  _Category('MEDICAL', '병원', Color(0xFFC45C6A)),
  _Category('TRAVEL', '여행', Color(0xFFD4A24C)),
  _Category('BIRTHDAY', '생일', Color(0xFFB07AC8)),
  _Category('OTHER', '기타', Color(0xFF7A8570)),
];

_Category _catOf(String id) =>
    _categories.firstWhere((c) => c.id == id, orElse: () => _categories.last);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

String _hmLabel(String? wire) {
  if (wire == null || wire.isEmpty) return '';
  final parts = wire.split(':');
  if (parts.length < 2) return wire;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final isAm = h < 12;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${isAm ? '오전' : '오후'} $h12:$m';
}

bool _needsTokenRefresh(ApiException e) {
  if (e.statusCode == 401 || e.statusCode == 403) return true;
  return e.message.contains('(401)') || e.message.contains('(403)');
}

String _remindLabel(int? minutes) {
  return switch (minutes) {
    null => '없음',
    0 => '시작 시각',
    10 => '10분 전',
    30 => '30분 전',
    60 => '1시간 전',
    1440 => '하루 전',
    _ => '$minutes분 전',
  };
}

/// 기록 > 캘린더 — 가족 공유 일정 (월 보기 · 당일 목록 · 생성/수정/삭제).
class FamilyCalendarPane extends StatefulWidget {
  const FamilyCalendarPane({super.key, required this.bottomPad});

  final double bottomPad;

  @override
  State<FamilyCalendarPane> createState() => _FamilyCalendarPaneState();
}

class _FamilyCalendarPaneState extends State<FamilyCalendarPane> {
  final _api = ApiClient();
  final _tokens = TokenStorage();

  final _today = _dateOnly(DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  List<CalendarEventResult> _events = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    var access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      return await action(access);
    } on ApiException catch (e) {
      if (!_needsTokenRefresh(e)) rethrow;
      final refresh = await _tokens.readRefreshToken();
      final userId = await _tokens.readUserId();
      if (refresh == null || userId == null) rethrow;
      final pair = await _api.refresh(refresh);
      await _tokens.saveSession(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: userId,
      );
      return action(pair.accessToken);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _withAuth(
        (t) => _api.fetchCalendarEvents(
          accessToken: t,
          year: _month.year,
          month: _month.month,
        ),
      );
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_month.year, _month.month + delta);
    setState(() {
      _month = next;
      final last = DateTime(next.year, next.month + 1, 0).day;
      final day = _selected.day.clamp(1, last);
      _selected = DateTime(next.year, next.month, day);
    });
    await _load();
  }

  List<CalendarEventResult> _eventsOn(DateTime day) {
    final d = _dateOnly(day);
    return _events.where((e) {
      final s = _dateOnly(e.startDate);
      final end = _dateOnly(e.endDate);
      return !d.isBefore(s) && !d.isAfter(end);
    }).toList();
  }

  Future<void> _openEditor({CalendarEventResult? existing, DateTime? day}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventEditorSheet(
        initial: existing,
        defaultDay: day ?? _selected,
        onSave: (body, {int? eventId}) async {
          if (eventId == null) {
            await _withAuth(
              (t) => _api.createCalendarEvent(accessToken: t, body: body),
            );
          } else {
            await _withAuth(
              (t) => _api.updateCalendarEvent(
                accessToken: t,
                eventId: eventId,
                body: body,
              ),
            );
          }
        },
        onDelete: existing == null
            ? null
            : () async {
                await _withAuth(
                  (t) => _api.deleteCalendarEvent(
                    accessToken: t,
                    eventId: existing.id,
                  ),
                );
              },
      ),
    );
    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? '일정을 등록했어요' : '일정을 저장했어요',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _events.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mutedGrey, fontSize: 13),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('다시 시도', style: TextStyle(color: _titleGreen)),
              ),
            ],
          ),
        ),
      );
    }

    final dayEvents = _eventsOn(_selected);

    return Stack(
      children: [
        RefreshIndicator(
          color: _titleGreen,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPad + 88),
            children: [
              _monthHeader(),
              const SizedBox(height: 8),
              _weekdayRow(),
              const SizedBox(height: 4),
              if (_loading && _events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: _titleGreen),
                  ),
                )
              else
                _monthGrid(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selected.month}월 ${_selected.day}일 ${_weekdays[_selected.weekday % 7]}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _titleGreen,
                      ),
                    ),
                  ),
                  Text(
                    '${dayEvents.length}개',
                    style: const TextStyle(fontSize: 13, color: _mutedGrey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (dayEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: _pillTrack.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '이 날 일정이 없어요\n+ 버튼으로 가족을 초대해 보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _mutedGrey,
                      height: 1.45,
                    ),
                  ),
                )
              else
                for (final e in dayEvents) ...[
                  _EventCard(
                    event: e,
                    onTap: () => _openEditor(existing: e),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              _legend(),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: widget.bottomPad + 12,
          child: FloatingActionButton(
            heroTag: 'family-calendar-fab',
            backgroundColor: _titleGreen,
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: () => _openEditor(day: _selected),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _shiftMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded, color: _ink),
        ),
        Expanded(
          child: Text(
            '${_month.year}년 ${_month.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _shiftMonth(1),
          icon: const Icon(Icons.chevron_right_rounded, color: _ink),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _month = DateTime(_today.year, _today.month);
              _selected = _today;
            });
            _load();
          },
          child: const Text(
            '오늘',
            style: TextStyle(
              color: _titleGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekdayRow() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Text(
              _weekdays[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: i == 0
                    ? const Color(0xFFC45C6A)
                    : (i == 6 ? const Color(0xFF4A7AB5) : _mutedGrey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Sunday-start offset
    final lead = first.weekday % 7;
    final cells = lead + daysInMonth;
    final rows = ((cells + 6) ~/ 7);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _dayCell(r * 7 + c, lead, daysInMonth)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(int index, int lead, int daysInMonth) {
    final dayNum = index - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 52);
    }
    final date = DateTime(_month.year, _month.month, dayNum);
    final selected = _sameDay(date, _selected);
    final isToday = _sameDay(date, _today);
    final events = _eventsOn(date);
    final dots = events.take(3).map((e) => _catOf(e.category).color).toList();

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      onLongPress: () => _openEditor(day: date),
      child: SizedBox(
        height: 52,
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? _titleGreen
                    : (isToday ? _pillTrack : Colors.transparent),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (date.weekday == DateTime.sunday
                          ? const Color(0xFFC45C6A)
                          : _ink),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in dots)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (events.length > 3)
                  const Text(
                    '+',
                    style: TextStyle(fontSize: 8, color: _mutedGrey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final c in _categories)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                c.label,
                style: const TextStyle(fontSize: 11, color: _mutedGrey),
              ),
            ],
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final CalendarEventResult event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = _catOf(event.category);
    final multi = !_sameDay(event.startDate, event.endDate);
    final timeLabel = event.allDay
        ? (multi
            ? '${event.startDate.month}/${event.startDate.day} – ${event.endDate.month}/${event.endDate.day} · 종일'
            : '종일')
        : '${_hmLabel(event.startTime)} – ${_hmLabel(event.endTime)}';
    final people = event.participants.isEmpty
        ? event.createdByLabel
        : event.participants.map((p) => p.roleLabel).join(', ');

    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: cat.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeLabel · ${cat.label}',
                      style: const TextStyle(fontSize: 12, color: _mutedGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '참여 $people',
                      style: const TextStyle(fontSize: 12, color: _bodyGrey),
                    ),
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${event.location}',
                        style: const TextStyle(fontSize: 12, color: _bodyGrey),
                      ),
                    ],
                  ],
                ),
              ),
              if (event.remindMinutes != null)
                const Icon(Icons.notifications_none, size: 16, color: _softGreen),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.initial,
    required this.defaultDay,
    required this.onSave,
    this.onDelete,
  });

  final CalendarEventResult? initial;
  final DateTime defaultDay;
  final Future<void> Function(Map<String, dynamic> body, {int? eventId}) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _tokens = TokenStorage();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _location;
  late bool _allDay;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _category;
  int? _remindMinutes;
  bool _saving = false;
  List<FamilyMemberResult> _members = const [];
  final Set<int> _participantIds = {};

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    // 기본은 세부 시간 설정 ON (끄면 종일)
    _allDay = e?.allDay ?? false;
    _startDate = e?.startDate ?? widget.defaultDay;
    _endDate = e?.endDate ?? widget.defaultDay;
    _startTime = _parseTime(e?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = _parseTime(e?.endTime) ?? const TimeOfDay(hour: 10, minute: 0);
    _category = e?.category ?? 'FAMILY';
    _remindMinutes = e?.remindMinutes;
    if (e != null) {
      _participantIds.addAll(e.participants.map((p) => p.userId));
    }
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final cached = await _tokens.readFamilyMembers();
    if (!mounted) return;
    setState(() {
      _members = cached;
      if (_participantIds.isEmpty && cached.isNotEmpty) {
        // 새 일정: 전원 참여 기본
        _participantIds.addAll(cached.map((m) => m.userId));
      }
    });
  }

  TimeOfDay? _parseTime(String? wire) {
    if (wire == null || wire.isEmpty) return null;
    final parts = wire.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _titleGreen,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked.isBefore(_startDate) ? _startDate : picked;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = start ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _titleGreen),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해 주세요.')),
      );
      return;
    }
    if (_participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참여 인원을 한 명 이상 선택해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'category': _category,
        'location':
            _location.text.trim().isEmpty ? null : _location.text.trim(),
        'allDay': _allDay,
        'startDate': _ymd(_startDate),
        'endDate': _ymd(_endDate),
        'startTime': _allDay ? null : _hm(_startTime),
        'endTime': _allDay ? null : _hm(_endTime),
        'remindMinutes': _remindMinutes,
        'participantUserIds': _participantIds.toList(),
      };
      await widget.onSave(body, eventId: widget.initial?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했어요.\n$e')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제할까요? 가족 모두에게서 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || widget.onDelete == null) return;
    setState(() => _saving = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제에 실패했어요.\n$e')),
      );
    }
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final isEdit = widget.initial != null;
    // 기존처럼 화면 중상단에 두고, 높이만 줄임 (~62%).
    final available =
        media.size.height - keyboard - media.padding.top - 32;
    final sheetH = (media.size.height * 0.62).clamp(280.0, available);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: GestureDetector(
        onTap: _unfocus,
        behavior: HitTestBehavior.opaque,
        child: Align(
          // bottom에 붙이면 작아질수록 아래로 처져 보임 → 중앙 유지
          alignment: const Alignment(0, -0.15),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: sheetH,
            decoration: BoxDecoration(
              color: _cardWhite,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          _unfocus();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '닫기',
                          style: TextStyle(color: _mutedGrey),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isEdit ? '일정 수정' : '새 일정',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _titleGreen,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                _unfocus();
                                _submit();
                              },
                        child: Text(
                          _saving ? '저장 중' : '저장',
                          style: const TextStyle(
                            color: _titleGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _hairline),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _title,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) => _unfocus(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                          decoration: const InputDecoration(
                            hintText: '일정 제목',
                            border: InputBorder.none,
                          ),
                        ),
                        const Divider(color: _hairline),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '세부 시간 설정',
                            style: TextStyle(fontSize: 15),
                          ),
                          value: !_allDay,
                          activeTrackColor:
                              _titleGreen.withValues(alpha: 0.45),
                          activeThumbColor: _titleGreen,
                          onChanged: (v) {
                            _unfocus();
                            setState(() => _allDay = !v);
                          },
                        ),
                        _rowTile(
                          '시작',
                          _ymd(_startDate),
                          () {
                            _unfocus();
                            _pickDate(start: true);
                          },
                        ),
                        if (!_allDay)
                          _rowTile(
                            '시작 시간',
                            _startTime.format(context),
                            () {
                              _unfocus();
                              _pickTime(start: true);
                            },
                          ),
                        _rowTile(
                          '종료',
                          _ymd(_endDate),
                          () {
                            _unfocus();
                            _pickDate(start: false);
                          },
                        ),
                        if (!_allDay)
                          _rowTile(
                            '종료 시간',
                            _endTime.format(context),
                            () {
                              _unfocus();
                              _pickTime(start: false);
                            },
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          '카테고리',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _titleGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in _categories)
                              ChoiceChip(
                                label: Text(c.label),
                                selected: _category == c.id,
                                selectedColor:
                                    c.color.withValues(alpha: 0.25),
                                onSelected: (_) {
                                  _unfocus();
                                  setState(() => _category = c.id);
                                },
                                labelStyle: TextStyle(
                                  color: _category == c.id
                                      ? c.color
                                      : _bodyGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _location,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) => _unfocus(),
                          decoration: const InputDecoration(
                            labelText: '장소 (선택)',
                            prefixIcon:
                                Icon(Icons.place_outlined, size: 20),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _desc,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) => _unfocus(),
                          onEditingComplete: _unfocus,
                          decoration: const InputDecoration(
                            labelText: '메모 (선택)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '참여 인원',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _titleGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_members.isEmpty)
                          const Text(
                            '가족 구성원을 불러오는 중…',
                            style: TextStyle(fontSize: 12, color: _mutedGrey),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in _members)
                                FilterChip(
                                  label: Text(m.roleLabel),
                                  selected: _participantIds.contains(m.userId),
                                  selectedColor:
                                      _titleGreen.withValues(alpha: 0.18),
                                  checkmarkColor: _titleGreen,
                                  onSelected: (selected) {
                                    _unfocus();
                                    setState(() {
                                      if (selected) {
                                        _participantIds.add(m.userId);
                                      } else {
                                        _participantIds.remove(m.userId);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          key: ValueKey('remind-$_remindMinutes'),
                          initialValue: _remindMinutes,
                          decoration: const InputDecoration(
                            labelText: '알림 (참여 인원에게 발송)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('없음'),
                            ),
                            DropdownMenuItem(
                              value: 0,
                              child: Text('시작 시각'),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text('10분 전'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30분 전'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('1시간 전'),
                            ),
                            DropdownMenuItem(
                              value: 1440,
                              child: Text('하루 전'),
                            ),
                          ],
                          onChanged: (v) {
                            _unfocus();
                            setState(() => _remindMinutes = v);
                          },
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: _saving ? null : _delete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                            child: const Text('일정 삭제'),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _remindMinutes == null
                              ? '알림 없음 · 일정은 가족 캘린더에 공유돼요'
                              : '알림: ${_remindLabel(_remindMinutes)} · 선택한 참여 인원에게 푸시',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mutedGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowTile(String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14, color: _mutedGrey)),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      onTap: onTap,
    );
  }
}
