import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

import 'package:hrhb_frontend/services/media_save_service.dart';
import 'answer_photos_all_screen.dart';
import 'family_answers_screen.dart';
import 'family_calendar_pane.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _pillTrack = Color(0xFFE8F0E4);
const _hairline = Color(0xFFE5E8E0);

enum _ArchiveTab { list, photos, report, calendar }

/// Spring Security returns 403 (Access Denied) for expired/invalid JWT
/// when the anonymous filter is active — not always 401.
bool _needsTokenRefresh(ApiException e) {
  if (e.statusCode == 401 || e.statusCode == 403) return true;
  return e.message.contains('(401)') || e.message.contains('(403)');
}

/// 기록 — 날짜별 / 사진 / 리포트 (기존 나뭇가지 배경 + renewal 기능).
class FamilyArchiveScreen extends StatefulWidget {
  const FamilyArchiveScreen({
    super.key,
    required this.familyName,
    this.bottomNavClearance = 110,
  });

  final String familyName;
  final double bottomNavClearance;

  @override
  State<FamilyArchiveScreen> createState() => _FamilyArchiveScreenState();
}

class _FamilyArchiveScreenState extends State<FamilyArchiveScreen> {
  _ArchiveTab _tab = _ArchiveTab.list;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SideBranches(),
          Positioned(
            left: 0,
            right: 0,
            bottom: -6,
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
                SizedBox(height: size.height * 0.01),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.06),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '기록',
                      style: TextStyle(
                        fontSize: shortest * 0.065,
                        fontWeight: FontWeight.w800,
                        color: _titleGreen,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.012),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.05),
                  child: _PillSegment(
                    selected: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                Expanded(
                  child: IndexedStack(
                    index: _tab.index,
                    children: [
                      _DateListPane(
                        familyName: widget.familyName,
                        bottomPad: widget.bottomNavClearance,
                      ),
                      _PhotosPane(bottomPad: widget.bottomNavClearance),
                      _ReportPane(bottomPad: widget.bottomNavClearance),
                      FamilyCalendarPane(bottomPad: widget.bottomNavClearance),
                    ],
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

class _PillSegment extends StatelessWidget {
  const _PillSegment({required this.selected, required this.onChanged});

  final _ArchiveTab selected;
  final ValueChanged<_ArchiveTab> onChanged;

  static const _items = [
    (_ArchiveTab.list, '날짜별'),
    (_ArchiveTab.photos, '사진'),
    (_ArchiveTab.report, '리포트'),
    (_ArchiveTab.calendar, '캘린더'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _pillTrack,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x99C5D5C0)),
      ),
      child: Row(
        children: [
          for (final (tab, label) in _items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == tab ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: selected == tab
                        ? const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected == tab ? FontWeight.w700 : FontWeight.w500,
                      color: selected == tab ? _titleGreen : _mutedGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 날짜별 ──────────────────────────────────────────────────────────────────

class _DateRow {
  const _DateRow({
    required this.date,
    required this.question,
    required this.dailyQuestionId,
    required this.answeredCount,
    required this.memberCount,
    this.weather,
    this.delta,
  });

  final DateTime date;
  final String question;
  final int dailyQuestionId;
  final int answeredCount;
  final int memberCount;
  final String? weather;
  final double? delta;
}

class _DateListPane extends StatefulWidget {
  const _DateListPane({
    required this.familyName,
    required this.bottomPad,
  });

  final String familyName;
  final double bottomPad;

  @override
  State<_DateListPane> createState() => _DateListPaneState();
}

class _DateListPaneState extends State<_DateListPane> {
  final _api = ApiClient();
  final _tokens = TokenStorage();
  final _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  late int _year = _today.year;
  late int _month = _today.month;
  List<_DateRow>? _rows;
  String? _error;
  bool _loading = true;

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
      final y = _year;
      final m = _month;
      final questions = await _withAuth(
        (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m),
      );
      final family = await _withAuth(_api.fetchMyFamily);
      final memberCount = family.members.length;
      DiaryCalendarResult? calendar;
      FamilyTemperatureResult? temp;
      try {
        calendar = await _withAuth(
          (t) => _api.fetchDiaryCalendar(accessToken: t, year: y, month: m),
        );
      } catch (_) {}
      try {
        temp = await _withAuth(_api.fetchFamilyTemperature);
      } catch (_) {}

      final weatherByDay = <String, String?>{};
      for (final d in calendar?.days ?? const <DiaryCalendarDayResult>[]) {
        weatherByDay[_ymd(d.date)] = d.familyWeather;
      }
      final deltaByDay = <String, double>{};
      for (final c in temp?.recentChanges ?? const <FamilyTemperatureChangeResult>[]) {
        deltaByDay[_ymd(c.date)] = c.delta;
      }

      final ready = questions.items
          .where((q) => q.isReady && q.dailyQuestionId != null)
          .where((q) {
            final d = DateTime(q.date.year, q.date.month, q.date.day);
            return !d.isAfter(_today);
          })
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // Answer counts for visible days (parallel, capped).
      final counts = await Future.wait(
        ready.map((q) async {
          try {
            final list = await _withAuth(
              (t) => _api.fetchDailyAnswers(
                accessToken: t,
                dailyQuestionId: q.dailyQuestionId!,
              ),
            );
            return list.answers.length;
          } catch (_) {
            return 0;
          }
        }),
      );

      final rows = <_DateRow>[
        for (var i = 0; i < ready.length; i++)
          _DateRow(
            date: DateTime(
              ready[i].date.year,
              ready[i].date.month,
              ready[i].date.day,
            ),
            question: ready[i].content ?? '',
            dailyQuestionId: ready[i].dailyQuestionId!,
            answeredCount: counts[i],
            memberCount: memberCount,
            weather: weatherByDay[_ymd(ready[i].date)],
            delta: deltaByDay[_ymd(ready[i].date)],
          ),
      ];

      if (!mounted || y != _year || m != _month) return;
      setState(() {
        _rows = rows;
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

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(2024),
      lastDate: DateTime(_today.year, _today.month, 1),
      helpText: '연·월 선택',
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _titleGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _year = picked.year;
      _month = picked.month;
    });
    await _load();
  }

  void _openDay(_DateRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyAnswersScreen(
          familyName: widget.familyName,
          date: row.date,
          question: row.question,
          dailyQuestionId: row.dailyQuestionId,
        ),
      ),
    );
  }

  String _dow(DateTime d) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _titleGreen,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPad),
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickMonth,
                  child: Row(
                    children: [
                      Text(
                        '$_year년 $_month월',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _titleGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: _titleGreen),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  '질문 · 일지 · 온도',
                  style: TextStyle(fontSize: 12, color: _mutedGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: _titleGreen)),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if ((_rows ?? const []).isEmpty)
            const _EmptyNote('이 달에는 도착한 질문이 없어요')
          else
            Container(
              decoration: BoxDecoration(
                color: _cardWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x99C5D5C0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _rows!.length; i++)
                    _dateTile(_rows![i], first: i == 0),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateTile(_DateRow row, {required bool first}) {
    final isToday = row.date == _today;
    final d = row.delta;
    final deltaText = d == null
        ? ''
        : '${d > 0 ? '+' : d < 0 ? '−' : '±'}${d.abs().toStringAsFixed(1)}°';
    final deltaColor = d == null || d == 0
        ? _mutedGrey
        : d > 0
            ? const Color(0xFF2F8F4E)
            : const Color(0xFFC45C3E);

    return InkWell(
      onTap: () => _openDay(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: first ? Colors.transparent : _hairline),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    '${row.date.day}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _bodyGrey,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    isToday ? '오늘' : _dow(row.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday ? _titleGreen : _mutedGrey,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _bodyGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${row.answeredCount}/${row.memberCount}',
                        style: const TextStyle(fontSize: 12, color: _mutedGrey),
                      ),
                      if (row.weather != null && row.weather!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          row.weather!,
                          style: const TextStyle(fontSize: 12, color: _softGreen),
                        ),
                      ],
                      if (deltaText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          deltaText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: deltaColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _mutedGrey, size: 20),
          ],
        ),
      ),
    );
  }
}


// ── 사진 ────────────────────────────────────────────────────────────────────

class _PhotosPane extends StatefulWidget {
  const _PhotosPane({required this.bottomPad});
  final double bottomPad;

  @override
  State<_PhotosPane> createState() => _PhotosPaneState();
}

class _PhotosPaneState extends State<_PhotosPane> {
  final _api = ApiClient();
  final _tokens = TokenStorage();
  final _mediaSave = const MediaSaveService();
  static const _pageSize = 21;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  int _total = 0;
  String? _error;
  List<AnswerPhotoItem> _items = const [];
  bool _selecting = false;
  bool _busy = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
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

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _nextPage = 0;
        _items = const [];
        _selecting = false;
        _selected.clear();
      });
    } else {
      if (_loadingMore || !_hasMore || _selecting) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await _withAuth(
        (t) => _api.fetchGalleryAnswerPhotos(
          accessToken: t,
          page: _nextPage,
          size: _pageSize,
        ),
      );
      final mapped = page.items
          .map(
            (e) => AnswerPhotoItem(
              answerId: e.answerId,
              imageUrl: e.imageUrl,
              date: e.date,
              author: e.authorLabel,
              question: e.questionContent,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _items = reset ? mapped : [..._items, ...mapped];
        _total = page.totalCount;
        _hasMore = page.hasMore;
        _nextPage = page.page + 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _enterSelect() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택할 사진이 없어요.')),
      );
      return;
    }
    setState(() {
      _selecting = true;
      _selected.clear();
    });
  }

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _saveSelected() async {
    if (_selected.isEmpty || _busy) return;
    final urls = _items
        .where((p) => _selected.contains(p.answerId))
        .map((p) => p.imageUrl)
        .toList();
    setState(() => _busy = true);
    try {
      await _mediaSave.saveImageUrls(urls);
      if (!mounted) return;
      _exitSelect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${urls.length}장의 사진을 저장했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 저장하지 못했어요.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDetail(int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnswerPhotoDetailScreen(
            items: _items,
            initialIndex: index,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _titleGreen));
    }
    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: () => _load(reset: true));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_selecting && n.metrics.extentAfter < 400) {
          _load(reset: false);
        }
        return false;
      },
      child: RefreshIndicator(
        color: _titleGreen,
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPad),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selecting
                        ? '${_selected.length}장 선택'
                        : '답변에 첨부된 사진 $_total장',
                    style: const TextStyle(fontSize: 14, color: _mutedGrey),
                  ),
                ),
                if (_selecting)
                  TextButton(
                    onPressed:
                        _busy || _selected.isEmpty ? null : _saveSelected,
                    child: Text(
                      _busy ? '저장 중…' : '저장',
                      style: TextStyle(
                        color: _selected.isEmpty
                            ? _mutedGrey
                            : _titleGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: _selecting ? _exitSelect : _enterSelect,
                  child: Text(
                    _selecting ? '취소' : '선택',
                    style: const TextStyle(
                      color: _titleGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const _EmptyNote('아직 답변에 첨부된 사진이 없어요')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length + (_loadingMore ? 1 : 0),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _titleGreen,
                        ),
                      ),
                    );
                  }
                  final item = _items[i];
                  final selected = _selected.contains(item.answerId);
                  return GestureDetector(
                    onTap: () {
                      if (_selecting) {
                        _toggle(item.answerId);
                      } else {
                        _openDetail(i);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) =>
                                Container(
                              color: _pillTrack,
                              child: const Icon(
                                Icons.broken_image,
                                color: _mutedGrey,
                              ),
                            ),
                          ),
                        ),
                        if (_selecting)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? _titleGreen
                                    : Colors.white.withValues(alpha: 0.9),
                                border: Border.all(
                                  color:
                                      selected ? _titleGreen : _mutedGrey,
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── 리포트 (renewal 레이아웃) ────────────────────────────────────────────────

enum _ReportMode { week, month }

class _ReportPane extends StatefulWidget {
  const _ReportPane({required this.bottomPad});
  final double bottomPad;

  @override
  State<_ReportPane> createState() => _ReportPaneState();
}

class _ReportPaneState extends State<_ReportPane> {
  final _api = ApiClient();
  final _tokens = TokenStorage();
  _ReportMode _mode = _ReportMode.week;
  bool _loading = true;
  String? _error;

  int _rate = 0;
  int? _prevRate;
  int _memberCount = 1;
  List<FamilyMemberResult> _members = const [];
  /// week: memberId -> 7 days (null = future)
  Map<int, List<bool?>> _weekMatrix = {};
  List<({DateTime date, int? count})> _monthDays = const [];
  List<({DateTime date, String? familyWeather})> _monthWeatherDays = const [];
  WeeklyTitleResult? _weeklyTitles;

  DateTime get _today => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  DateTime get _monday {
    final t = _today;
    return t.subtract(Duration(days: t.weekday - 1));
  }

  /// Nicknames scored from previous Mon–Sun (awarded Monday 03:10).
  DateTime get _titleWeekStart => _monday.subtract(const Duration(days: 7));

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
      List<FamilyMemberResult> members;
      try {
        final family = await _withAuth(_api.fetchMyFamily);
        members = family.members;
        await _tokens.saveFamilyMembers(members);
      } on ApiException {
        // Spring Security often returns 403 (not 401) for expired JWT.
        // Fall back to cached members so the report can still render.
        final cached = await _tokens.readFamilyMembers();
        if (cached.isEmpty) rethrow;
        members = cached;
      }
      final memberCount = members.isEmpty ? 1 : members.length;

      if (_mode == _ReportMode.week) {
        await _loadWeek(members, memberCount);
      } else {
        await _loadMonth(members, memberCount);
      }

      WeeklyTitleResult? titles;
      if (_mode == _ReportMode.week) {
        try {
          titles = await _withAuth(
            (token) => _api.fetchWeeklyTitles(
              accessToken: token,
              weekStart: _titleWeekStart,
            ),
          );
        } catch (_) {
          titles = null;
        }
      }
      if (!mounted) return;
      setState(() => _weeklyTitles = titles);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<TodayDailyQuestionResult>> _questionsAround(
    DateTime start,
    DateTime end,
  ) async {
    final months = <({int y, int m})>{
      (y: start.year, m: start.month),
      (y: end.year, m: end.month),
    };
    final all = <TodayDailyQuestionResult>[];
    for (final mm in months) {
      final r = await _withAuth(
        (t) => _api.fetchMonthDailyQuestions(
          accessToken: t,
          year: mm.y,
          month: mm.m,
        ),
      );
      all.addAll(r.items);
    }
    return all
        .where((q) => q.isReady && q.dailyQuestionId != null)
        .toList();
  }

  Future<void> _loadWeek(
    List<FamilyMemberResult> members,
    int memberCount,
  ) async {
    final start = _monday;
    final end = start.add(const Duration(days: 6));
    final prevStart = start.subtract(const Duration(days: 7));
    final all = await _questionsAround(prevStart, end);

    final matrix = <int, List<bool?>>{
      for (final m in members) m.userId: List<bool?>.filled(7, null),
    };

    var pastSlots = 0;
    var answeredSlots = 0;

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final future = day.isAfter(_today);
      for (final m in members) {
        matrix[m.userId]![i] = future ? null : false;
      }
      if (future) continue;

      final match = all.where((q) {
        final d = DateTime(q.date.year, q.date.month, q.date.day);
        return d == day;
      });
      if (match.isEmpty) continue;

      pastSlots += memberCount;
      try {
        final list = await _withAuth(
          (t) => _api.fetchDailyAnswers(
            accessToken: t,
            dailyQuestionId: match.first.dailyQuestionId!,
          ),
        );
        answeredSlots += list.answers.length;
        for (final a in list.answers) {
          matrix[a.userId]?[i] = true;
        }
      } catch (_) {}
    }

    // Previous week rate
    int? prevRate;
    var prevPast = 0;
    var prevAns = 0;
    for (var i = 0; i < 7; i++) {
      final day = prevStart.add(Duration(days: i));
      final match = all.where((q) {
        final d = DateTime(q.date.year, q.date.month, q.date.day);
        return d == day;
      });
      if (match.isEmpty) continue;
      prevPast += memberCount;
      try {
        final list = await _withAuth(
          (t) => _api.fetchDailyAnswers(
            accessToken: t,
            dailyQuestionId: match.first.dailyQuestionId!,
          ),
        );
        prevAns += list.answers.length;
      } catch (_) {}
    }
    if (prevPast > 0) {
      prevRate = ((prevAns / prevPast) * 100).round();
    }

    if (!mounted) return;
    setState(() {
      _members = members;
      _memberCount = memberCount;
      _weekMatrix = matrix;
      _rate = pastSlots == 0 ? 0 : ((answeredSlots / pastSlots) * 100).round();
      _prevRate = prevRate;
      _monthDays = const [];
      _monthWeatherDays = const [];
      _loading = false;
    });
  }

  Future<void> _loadMonth(
    List<FamilyMemberResult> members,
    int memberCount,
  ) async {
    final y = _today.year;
    final m = _today.month;
    final last = DateTime(y, m + 1, 0).day;

    final monthQs = await _withAuth(
      (t) => _api.fetchMonthDailyQuestions(accessToken: t, year: y, month: m),
    );
    final byDay = <int, TodayDailyQuestionResult>{};
    for (final q in monthQs.items) {
      if (!q.isReady || q.dailyQuestionId == null) continue;
      byDay[q.date.day] = q;
    }

    var pastSlots = 0;
    var answeredSlots = 0;
    final dayCounts = <({DateTime date, int? count})>[];

    for (var day = 1; day <= last; day++) {
      final date = DateTime(y, m, day);
      if (date.isAfter(_today)) {
        dayCounts.add((date: date, count: null));
        continue;
      }
      final q = byDay[day];
      if (q == null) {
        dayCounts.add((date: date, count: 0));
        continue;
      }
      pastSlots += memberCount;
      try {
        final list = await _withAuth(
          (t) => _api.fetchDailyAnswers(
            accessToken: t,
            dailyQuestionId: q.dailyQuestionId!,
          ),
        );
        answeredSlots += list.answers.length;
        dayCounts.add((date: date, count: list.answers.length));
      } catch (_) {
        dayCounts.add((date: date, count: 0));
      }
    }

    int? prevRate;
    final prev = DateTime(y, m - 1, 1);
    try {
      final prevQs = await _withAuth(
        (t) => _api.fetchMonthDailyQuestions(
          accessToken: t,
          year: prev.year,
          month: prev.month,
        ),
      );
      final ready = prevQs.items
          .where((q) => q.isReady && q.dailyQuestionId != null)
          .toList();
      var pSlots = 0;
      var pAns = 0;
      for (final q in ready.take(10)) {
        pSlots += memberCount;
        try {
          final list = await _withAuth(
            (t) => _api.fetchDailyAnswers(
              accessToken: t,
              dailyQuestionId: q.dailyQuestionId!,
            ),
          );
          pAns += list.answers.length;
        } catch (_) {}
      }
      if (pSlots > 0) prevRate = ((pAns / pSlots) * 100).round();
    } catch (_) {}

    DiaryCalendarResult? calendar;
    try {
      calendar = await _withAuth(
        (t) => _api.fetchDiaryCalendar(accessToken: t, year: y, month: m),
      );
    } catch (_) {
      calendar = null;
    }

    final weatherByDay = <int, String>{};
    for (final d in calendar?.days ?? const <DiaryCalendarDayResult>[]) {
      if (d.familyWeather.isNotEmpty) {
        weatherByDay[d.date.day] = d.familyWeather;
      }
    }

    final weatherDays = <({DateTime date, String? familyWeather})>[
      for (var day = 1; day <= last; day++)
        (
          date: DateTime(y, m, day),
          familyWeather: DateTime(y, m, day).isAfter(_today)
              ? null
              : weatherByDay[day],
        ),
    ];

    if (!mounted) return;
    setState(() {
      _members = members;
      _memberCount = memberCount;
      _monthDays = dayCounts;
      _monthWeatherDays = weatherDays;
      _rate = pastSlots == 0 ? 0 : ((answeredSlots / pastSlots) * 100).round();
      _prevRate = prevRate;
      _weekMatrix = {};
      _loading = false;
    });
  }

  String _diffText(int rate, int? prev, String than) {
    if (prev == null) return '';
    final d = rate - prev;
    return '$than ${d.abs()}%p ${d >= 0 ? '올랐어요' : '내렸어요'}';
  }

  @override
  Widget build(BuildContext context) {
    final isWeek = _mode == _ReportMode.week;
    final end = _monday.add(const Duration(days: 6));
    final period = isWeek
        ? '${_monday.month}.${_monday.day} – ${end.month}.${end.day}'
        : '${_today.year}년 ${_today.month}월';

    return RefreshIndicator(
      color: _titleGreen,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPad),
        children: [
          Row(
            children: [
              SizedBox(
                width: 150,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _pillTrack,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      for (final (mode, label) in [
                        (_ReportMode.week, '주간'),
                        (_ReportMode.month, '월간'),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_mode == mode) return;
                              setState(() => _mode = mode);
                              _load();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _mode == mode
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: _mode == mode
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _mode == mode
                                      ? _titleGreen
                                      : _mutedGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                period,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _mutedGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: _titleGreen)),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...[
            _ReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWeek
                        ? '이번 주 답변율 $_rate%'
                        : '${_today.month}월 답변율 $_rate%',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _bodyGrey,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWeek
                        ? _diffText(_rate, _prevRate, '지난주보다')
                        : [
                            _diffText(_rate, _prevRate, '지난달보다'),
                            '칸 색은 답변 성실도, 가운데는 가족 날씨예요',
                          ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 13, color: _mutedGrey),
                  ),
                  const SizedBox(height: 16),
                  if (isWeek)
                    _WeekMatrix(members: _members, matrix: _weekMatrix)
                  else
                    _MonthCombinedCalendar(
                      year: _today.year,
                      month: _today.month,
                      memberCount: _memberCount,
                      answerDays: _monthDays,
                      weatherDays: _monthWeatherDays,
                    ),
                ],
              ),
            ),
            if (isWeek) ...[
              const SizedBox(height: 12),
              _WeeklyTitlesCard(titles: _weeklyTitles),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeekMatrix extends StatelessWidget {
  const _WeekMatrix({required this.members, required this.matrix});

  final List<FamilyMemberResult> members;
  final Map<int, List<bool?>> matrix;

  static const _dow = ['월', '화', '수', '목', '금', '토', '일'];

  String _short(FamilyMemberResult m) {
    final label = m.roleLabel;
    if (label.length <= 2) return label;
    if (label.contains('할아버지')) return '할아';
    if (label.contains('할머니')) return '할머';
    if (label.contains('아빠')) return '아빠';
    if (label.contains('엄마')) return '엄마';
    if (label.contains('아들')) return '아들';
    if (label.contains('딸')) return '딸';
    return label.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 36),
            for (final d in _dow) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: _mutedGrey),
                ),
              ),
            ],
          ],
        ),
        for (final m in members) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  _short(m),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _mutedGrey,
                  ),
                ),
              ),
              for (var i = 0; i < 7; i++) ...[
                const SizedBox(width: 6),
                Expanded(child: _cell(matrix[m.userId]?[i])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(bool? answered) {
    if (answered == null) {
      return CustomPaint(
        painter: _DashedRRectPainter(),
        child: const SizedBox(height: 28),
      );
    }
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: answered ? _titleGreen : const Color(0xFFE8EDE4),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8C5B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(7),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonthCombinedCalendar extends StatelessWidget {
  const _MonthCombinedCalendar({
    required this.year,
    required this.month,
    required this.memberCount,
    required this.answerDays,
    required this.weatherDays,
  });

  final int year;
  final int month;
  final int memberCount;
  final List<({DateTime date, int? count})> answerDays;
  final List<({DateTime date, String? familyWeather})> weatherDays;

  static const _heatmap = [
    Color(0xFFE8EDE4),
    Color(0xFFC5D9BE),
    Color(0xFF9FBF95),
    Color(0xFF6F9A66),
    Color(0xFF3A6A3F),
  ];

  static const _weatherLegend = [
    ('☀️', '맑음'),
    ('⛅', '구름'),
    ('☁️', '흐림'),
    ('🌧️', '비'),
    ('⛈️', '번개'),
  ];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final lead = first.weekday - 1;
    final countByDay = {for (final d in answerDays) d.date.day: d.count};
    final weatherByDay = {
      for (final d in weatherDays) d.date.day: d.familyWeather,
    };
    final last = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(height: 52),
      for (var day = 1; day <= last; day++)
        _dayCell(
          day: day,
          count: countByDay[day],
          weather: weatherByDay[day],
          isFuture: DateTime(year, month, day).isAfter(todayOnly),
        ),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  const ['월', '화', '수', '목', '금', '토', '일'][i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: _mutedGrey),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, c) {
            final w = (c.maxWidth - 6 * 6) / 7;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cell in cells) SizedBox(width: w, child: cell),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              '답변',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _mutedGrey,
              ),
            ),
            const SizedBox(width: 6),
            const Text('적음', style: TextStyle(fontSize: 11, color: _mutedGrey)),
            for (final c in _heatmap) ...[
              const SizedBox(width: 3),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
            const SizedBox(width: 3),
            const Text('많음', style: TextStyle(fontSize: 11, color: _mutedGrey)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              '날씨',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _mutedGrey,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (emoji, label) in _weatherLegend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _mutedGrey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dayCell({
    required int day,
    required int? count,
    required String? weather,
    required bool isFuture,
  }) {
    final emoji = _normalizeWeatherEmoji(weather);
    final members = memberCount == 0 ? 4 : memberCount;
    final level = count == null
        ? null
        : (count / members * 4).round().clamp(0, 4);
    final bg = isFuture
        ? const Color(0xFFF7F8F4)
        : (level == null ? _heatmap[0] : _heatmap[level]);
    final dayColor = isFuture
        ? _bodyGrey.withValues(alpha: 0.28)
        : (level != null && level >= 3 ? Colors.white : _mutedGrey);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFuture
              ? const Color(0xFFE5E8E0)
              : (level != null && level >= 2
                  ? const Color(0xFFB5CDB0)
                  : const Color(0xFFE5E8E0)),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 3,
            left: 0,
            right: 0,
            child: Text(
              '$day',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: dayColor,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isFuture ? '' : (emoji ?? '·'),
                style: TextStyle(
                  fontSize: emoji == null ? 12 : 18,
                  color: level != null && level >= 3
                      ? Colors.white.withValues(alpha: 0.92)
                      : _mutedGrey,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _normalizeWeatherEmoji(String? weather) {
    if (weather == null || weather.isEmpty) return null;
    const known = ['☀️', '⛅', '☁️', '🌧️', '⛈️'];
    for (final e in known) {
      if (weather == e) return e;
      if (weather.replaceAll('️', '') == e.replaceAll('️', '')) return e;
    }
    return weather;
  }
}

class _WeeklyTitlesCard extends StatelessWidget {
  const _WeeklyTitlesCard({required this.titles});

  final WeeklyTitleResult? titles;

  /// 실제 집계 전이거나 비어 있을 때 레이아웃 확인용 목데이터.
  static const _useMockWhenEmpty = true;

  static const _columnTints = [
    Color(0xFFEAF3E6),
    Color(0xFFF7ECE6),
    Color(0xFFE8F1F4),
    Color(0xFFF3EAF5),
  ];

  static String _emojiFor(String code) {
    return switch (code) {
      'ANSWER_KING' => '🏆',
      'STEADY_KING' => '🌿',
      'PHOTOGRAPHER' => '📷',
      'FIRST_RESPONDER' => '⚡',
      'LONG_WRITER' => '💌',
      'DIARY_KING' => '📖',
      'DAY_COLLECTOR' => '🧺',
      'STORYTELLER' => '💬',
      'CHEER_KING' => '👏',
      _ => '✨',
    };
  }

  static String? _profileAssetFor(String role) {
    return switch (role) {
      'GRANDFATHER' => 'assets/images/profile/grandfather.png',
      'GRANDMOTHER' => 'assets/images/profile/grandmother.png',
      'FATHER' => 'assets/images/profile/father.png',
      'MOTHER' => 'assets/images/profile/mother.png',
      'SON' => 'assets/images/profile/son.png',
      'DAUGHTER' => 'assets/images/profile/daughter.png',
      _ => null,
    };
  }

  static String _shortRole(WeeklyTitleMemberResult m) {
    final label = m.roleLabel;
    if (label.contains('할아버지')) return '할아버지';
    if (label.contains('할머니')) return '할머니';
    if (label.contains('아빠')) return '아빠';
    if (label.contains('엄마')) return '엄마';
    if (label.contains('아들')) return '아들';
    if (label.contains('딸')) return '딸';
    return label;
  }

  static List<WeeklyTitleMemberResult> get _mockMembers => const [
        WeeklyTitleMemberResult(
          userId: 1,
          role: 'FATHER',
          titles: [
            WeeklyTitleItemResult(titleCode: 'ANSWER_KING', titleName: '답변왕'),
            WeeklyTitleItemResult(
              titleCode: 'PHOTOGRAPHER',
              titleName: '포토그래퍼',
            ),
          ],
        ),
        WeeklyTitleMemberResult(
          userId: 2,
          role: 'MOTHER',
          titles: [
            WeeklyTitleItemResult(titleCode: 'STEADY_KING', titleName: '꾸준왕'),
          ],
        ),
        WeeklyTitleMemberResult(
          userId: 3,
          role: 'SON',
          birthOrder: 1,
          titles: [
            WeeklyTitleItemResult(
              titleCode: 'LONG_WRITER',
              titleName: '장문왕',
            ),
            WeeklyTitleItemResult(titleCode: 'CHEER_KING', titleName: '응원왕'),
          ],
        ),
        WeeklyTitleMemberResult(
          userId: 4,
          role: 'DAUGHTER',
          birthOrder: 1,
          titles: [
            WeeklyTitleItemResult(
              titleCode: 'STORYTELLER',
              titleName: '이야기꾼',
            ),
          ],
        ),
        WeeklyTitleMemberResult(
          userId: 5,
          role: 'GRANDFATHER',
          titles: [
            WeeklyTitleItemResult(titleCode: 'DIARY_KING', titleName: '일기왕'),
          ],
        ),
        WeeklyTitleMemberResult(
          userId: 6,
          role: 'GRANDMOTHER',
          titles: [
            WeeklyTitleItemResult(
              titleCode: 'DAY_COLLECTOR',
              titleName: '하루수집가',
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final realMembers = titles?.members ?? const <WeeklyTitleMemberResult>[];
    final ready = titles?.ready ?? false;
    final showMock = _useMockWhenEmpty && (!ready || realMembers.isEmpty);
    final members = showMock ? _mockMembers : realMembers;

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '이번 주 우리 가족의 별명 ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F3A2C),
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(text: '🌿', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (showMock)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '미리보기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _titleGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '각자의 방식으로 함께한 이번 주예요.',
            style: TextStyle(fontSize: 13, color: _mutedGrey, height: 1.35),
          ),
          const SizedBox(height: 2),
          const Text(
            '매주 월요일, 지난주 기록으로 업데이트돼요',
            style: TextStyle(fontSize: 12, color: Color(0xFFA3A99C)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final m = members[i];
                return _NicknameMemberColumn(
                  roleLabel: _shortRole(m),
                  profileAsset: _profileAssetFor(m.role),
                  titles: m.titles,
                  tint: _columnTints[i % _columnTints.length],
                  emojiFor: _emojiFor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NicknameMemberColumn extends StatelessWidget {
  const _NicknameMemberColumn({
    required this.roleLabel,
    required this.profileAsset,
    required this.titles,
    required this.tint,
    required this.emojiFor,
  });

  final String roleLabel;
  final String? profileAsset;
  final List<WeeklyTitleItemResult> titles;
  final Color tint;
  final String Function(String code) emojiFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x22000000),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: profileAsset == null
                    ? const Icon(Icons.person_rounded, color: _softGreen)
                    : Image.asset(
                        profileAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person_rounded, color: _softGreen),
                      ),
              ),
              Positioned(
                top: -6,
                right: -2,
                child: Text(
                  '✦',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE8B84A).withValues(alpha: 0.95),
                    height: 1,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: -8,
                child: Text(
                  '✧',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFE8B84A).withValues(alpha: 0.8),
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            roleLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2F3A2C),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < titles.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _NicknamePill(
                      emoji: emojiFor(titles[i].titleCode),
                      label: titles[i].titleName,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NicknamePill extends StatelessWidget {
  const _NicknamePill({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E3D0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _titleGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x99C5D5C0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _cardWhite.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _mutedGrey, fontSize: 14),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _bodyGrey)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도', style: TextStyle(color: _titleGreen)),
          ),
        ],
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
