import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _panelGreen = Color(0xFFEAF3E4);

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _weatherOptions = ['☀️', '⛅', '☁️', '🌧️', '⛈️'];


/// Matches backend `FamilyTemperatureCopy.GAUGE_COLORS` interpolation.
const _gaugeColors = <Color>[
  Color(0xFF7EC8F5),
  Color(0xFF8FD4C8),
  Color(0xFFB8E07A),
  Color(0xFFE8E05A),
  Color(0xFFF5C04A),
  Color(0xFFF09A4A),
  Color(0xFFE8785A),
  Color(0xFFE85A55),
];

Color _temperatureColor(double temperature) {
  final t = (temperature.clamp(0, 100) / 100.0);
  final scaled = t * (_gaugeColors.length - 1);
  final i = scaled.floor().clamp(0, _gaugeColors.length - 2);
  final local = scaled - i;
  return Color.lerp(_gaugeColors[i], _gaugeColors[i + 1], local) ??
      _gaugeColors[i];
}

/// ☀️5 · ⛅4 · ☁️3 · 🌧️2 · ⛈️1 → round average
String _aggregateFamilyWeather(Iterable<String> weathers) {
  const scores = {
    '☀️': 5,
    '⛅': 4,
    '☁️': 3,
    '🌧️': 2,
    '⛈️': 1,
  };
  final values = weathers
      .map((w) => scores[w])
      .whereType<int>()
      .toList(growable: false);
  if (values.isEmpty) return '';
  final avg = values.reduce((a, b) => a + b) / values.length;
  final rounded = avg.round().clamp(1, 5);
  return switch (rounded) {
    5 => '☀️',
    4 => '⛅',
    3 => '☁️',
    2 => '🌧️',
    _ => '⛈️',
  };
}

class _DiaryDay {
  const _DiaryDay({
    required this.date,
    required this.temperature,
    required this.statusLabel,
    required this.familyWeather,
    required this.entries,
  });

  final DateTime date;
  final double temperature;
  final String statusLabel;
  final String familyWeather;
  final List<_DiaryEntry> entries;

  String get dateLabel => '${date.month}.${date.day}';
  String get weekday => _weekdays[date.weekday - 1];
  String get headerLabel => '$dateLabel ($weekday)';
  bool get hasEntries => entries.isNotEmpty;
}

class _DiaryEntry {
  const _DiaryEntry({
    required this.author,
    required this.timeLabel,
    required this.body,
  });

  final String author;
  final String timeLabel;
  final String body;
}

class FamilyDiaryScreen extends StatefulWidget {
  const FamilyDiaryScreen({
    super.key,
    this.bottomNavClearance = 0,
  });

  final double bottomNavClearance;

  @override
  State<FamilyDiaryScreen> createState() => _FamilyDiaryScreenState();
}

class _FamilyDiaryScreenState extends State<FamilyDiaryScreen> {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();

  late DateTime _month;
  DateTime? _selectedDate;
  List<_DiaryDay> _days = const [];
  List<_WeatherMember> _weatherMembers = const [];
  List<_DiaryEntry> _selectedEntries = const [];
  double _selectedTemperature = 36.5;
  String _selectedStatusLabel = '';
  bool _loadingCalendar = true;
  bool _loadingDay = false;
  bool _mineHasEntryToday = false;
  String? _myWeatherToday;
  String? _myContentToday;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _tokenStorage.readFamilyMembers();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _weatherMembers = cached
            .map((m) => _WeatherMember(label: m.roleLabel, weather: ''))
            .toList();
      });
    }
    await Future.wait([
      _refreshTodayMineStatus(),
      _loadCalendar(selectLatest: true),
    ]);
  }

  Future<T> _withAuthRetry<T>(Future<T> Function(String accessToken) action) async {
    var accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      return await action(accessToken);
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

  Future<void> _refreshTodayMineStatus() async {
    try {
      final day = await _withAuthRetry(
        (token) => _apiClient.fetchDiaryDay(
          accessToken: token,
          date: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _mineHasEntryToday = day.myEntry != null;
        _myWeatherToday = day.myEntry?.weather;
        _myContentToday = day.myEntry?.content;
      });
    } catch (_) {}
  }

  Future<void> _loadCalendar({required bool selectLatest}) async {
    setState(() {
      _loadingCalendar = true;
      _error = null;
    });
    try {
      final result = await _withAuthRetry(
        (token) => _apiClient.fetchDiaryCalendar(
          accessToken: token,
          year: _month.year,
          month: _month.month,
        ),
      );
      if (!mounted) return;
      final days = result.days
          .where((d) => d.entryCount > 0)
          .map(
            (d) => _DiaryDay(
              date: d.date,
              temperature: d.temperature,
              statusLabel: d.statusLabel,
              familyWeather: d.familyWeather,
              entries: const [],
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      DateTime? nextSelected = _selectedDate;
      if (selectLatest ||
          nextSelected == null ||
          nextSelected.year != _month.year ||
          nextSelected.month != _month.month ||
          !days.any((d) => _sameDay(d.date, nextSelected!))) {
        nextSelected = days.isEmpty ? null : days.first.date;
      }

      setState(() {
        _days = days;
        _selectedDate = nextSelected;
        _loadingCalendar = false;
      });
      await _loadDay(nextSelected ?? DateTime.now());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingCalendar = false;
      });
    }
  }

  Future<void> _loadDay(DateTime date) async {
    setState(() {
      _loadingDay = true;
      _error = null;
    });
    try {
      final day = await _withAuthRetry(
        (token) => _apiClient.fetchDiaryDay(accessToken: token, date: date),
      );
      if (!mounted) return;
      final entries = day.entries
          .map(
            (e) => _DiaryEntry(
              author: e.roleLabel,
              timeLabel: _formatTime(e.createdAt),
              body: e.content,
            ),
          )
          .toList();
      final isToday = _sameDay(date, DateTime.now());
      final familyWeather = _aggregateFamilyWeather(
        day.members.map((m) => m.weather ?? ''),
      );
      setState(() {
        _selectedTemperature = day.temperature;
        _selectedStatusLabel = day.statusLabel;
        _selectedEntries = entries;
        _weatherMembers = day.members
            .map(
              (m) => _WeatherMember(
                label: m.roleLabel,
                weather: m.weather ?? '',
              ),
            )
            .toList();
        _days = [
          for (final d in _days)
            if (_sameDay(d.date, date))
              _DiaryDay(
                date: d.date,
                temperature: day.temperature,
                statusLabel: day.statusLabel,
                familyWeather: familyWeather,
                entries: entries,
              )
            else
              d,
        ];
        if (isToday) {
          _mineHasEntryToday = day.myEntry != null;
          _myWeatherToday = day.myEntry?.weather;
          _myContentToday = day.myEntry?.content;
        }
        _loadingDay = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingDay = false;
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    final isAm = local.hour < 12;
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${isAm ? '오전' : '오후'} $hour12:$minute';
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    await _loadCalendar(selectLatest: true);
  }

  _DiaryDay get _displayDay {
    final date = _selectedDate ?? DateTime.now();
    final matched = _days.where((d) => _sameDay(d.date, date)).toList();
    if (matched.isNotEmpty) {
      final base = matched.first;
      return _DiaryDay(
        date: base.date,
        temperature: _selectedTemperature,
        statusLabel:
            _selectedStatusLabel.isNotEmpty ? _selectedStatusLabel : base.statusLabel,
        familyWeather: base.familyWeather,
        entries: _selectedEntries,
      );
    }
    return _DiaryDay(
      date: date,
      temperature: _selectedTemperature,
      statusLabel: _selectedStatusLabel.isNotEmpty ? _selectedStatusLabel : '따뜻해요',
      familyWeather: _aggregateFamilyWeather(
        _weatherMembers.map((m) => m.weather),
      ),
      entries: _selectedEntries,
    );
  }

  Future<void> _openWriteModal() async {
    final today = DateTime.now();
    final result = await showModalBottomSheet<_DiaryWriteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiaryWriteSheet(
        initialContent: _myContentToday ?? '',
        initialWeather: _myWeatherToday ?? '',
        isEdit: _mineHasEntryToday,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final saved = await _withAuthRetry(
        (token) => _apiClient.upsertTodayDiary(
          accessToken: token,
          content: result.content,
          weather: result.weather,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mineHasEntryToday ? '일지를 수정했어요.' : '오늘의 일지를 저장했어요.'),
        ),
      );
      if (_month.year != today.year || _month.month != today.month) {
        setState(() => _month = DateTime(today.year, today.month));
      }
      setState(() {
        _selectedDate = DateTime(today.year, today.month, today.day);
        _mineHasEntryToday = saved.myEntry != null;
        _myWeatherToday = saved.myEntry?.weather;
        _myContentToday = saved.myEntry?.content;
      });
      await _loadCalendar(selectLatest: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomClearance = widget.bottomNavClearance > 0
        ? widget.bottomNavClearance
        : MediaQuery.paddingOf(context).bottom + shortest * 0.22 + 4;
    final day = _displayDay;
    final ctaLabel =
        _mineHasEntryToday ? '오늘의 일지 수정하기' : '오늘의 일지 작성하기';

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
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.02,
                    size.height * 0.004,
                    shortest * 0.02,
                    0,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '우리 가족 일지',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cafe24Oneprettynight',
                                fontSize: shortest * 0.055,
                                color: _titleGreen,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SproutIcon(size: shortest * 0.038),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Text(
                  '우리 가족의 하루와 변화를 기록해요',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.032,
                    color: _mutedGrey,
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: shortest * 0.05),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: shortest * 0.026,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      size.width * 0.04,
                      size.height * 0.012,
                      size.width * 0.04,
                      bottomClearance,
                    ),
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: size.width * 0.26,
                                child: _DateSidebar(
                                  month: _month,
                                  days: _days,
                                  selectedDate: _selectedDate,
                                  loading: _loadingCalendar,
                                  onSelectDate: (date) {
                                    setState(() => _selectedDate = date);
                                    _loadDay(date);
                                  },
                                  onPrevMonth: () => _shiftMonth(-1),
                                  onNextMonth: () => _shiftMonth(1),
                                  shortest: shortest,
                                ),
                              ),
                              Container(
                                width: 1,
                                color: const Color(0xFFE6E0D4),
                              ),
                              Expanded(
                                child: _DiaryDetailPane(
                                  day: day,
                                  shortest: shortest,
                                  members: _weatherMembers,
                                  loading: _loadingDay,
                                  ctaLabel: ctaLabel,
                                  onWrite: _openWriteModal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _WeatherMember {
  const _WeatherMember({required this.label, required this.weather});
  final String label;
  final String weather;
}

class _DiaryWriteResult {
  const _DiaryWriteResult({required this.content, required this.weather});
  final String content;
  final String weather;
}

class _DiaryWriteSheet extends StatefulWidget {
  const _DiaryWriteSheet({
    required this.initialContent,
    required this.initialWeather,
    required this.isEdit,
  });

  final String initialContent;
  final String initialWeather;
  final bool isEdit;

  @override
  State<_DiaryWriteSheet> createState() => _DiaryWriteSheetState();
}

class _DiaryWriteSheetState extends State<_DiaryWriteSheet> {
  late final TextEditingController _controller;
  late String _weather;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _weather = widget.initialWeather.isNotEmpty
        ? widget.initialWeather
        : _weatherOptions.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일지 내용을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop(
      _DiaryWriteResult(content: text, weather: _weather),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          shortest * 0.03,
          0,
          shortest * 0.03,
          shortest * 0.03,
        ),
        padding: EdgeInsets.fromLTRB(
          shortest * 0.045,
          shortest * 0.035,
          shortest * 0.045,
          shortest * 0.035,
        ),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD9D0C0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEdit ? '오늘의 일지 수정하기' : '오늘의 일지 작성하기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.042,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: shortest * 0.03),
              Text(
                '오늘의 날씨',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.03,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: shortest * 0.015),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final option in _weatherOptions)
                    Material(
                      color: _weather == option
                          ? _panelGreen
                          : const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() => _weather = option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: shortest * 0.1,
                          height: shortest * 0.1,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _weather == option
                                  ? _titleGreen
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(fontSize: shortest * 0.048),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: shortest * 0.03),
              Text(
                '오늘의 일지',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.03,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: shortest * 0.015),
              TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 4,
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.034,
                  color: _bodyGrey,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: '오늘 가족과 나눈 하루를 적어 보세요.',
                  hintStyle: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.03,
                    color: _mutedGrey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.all(shortest * 0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0DACF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0DACF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _softGreen, width: 1.4),
                  ),
                ),
              ),
              SizedBox(height: shortest * 0.035),
              Material(
                color: const Color(0xFFE3EFD8),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _saving ? null : _submit,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: shortest * 0.03),
                    child: Text(
                      '저장하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: shortest * 0.034,
                        color: _titleGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSidebar extends StatelessWidget {
  const _DateSidebar({
    required this.month,
    required this.days,
    required this.selectedDate,
    required this.loading,
    required this.onSelectDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.shortest,
  });

  final DateTime month;
  final List<_DiaryDay> days;
  final DateTime? selectedDate;
  final bool loading;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F6EF),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shortest * 0.008,
              shortest * 0.028,
              shortest * 0.008,
              shortest * 0.012,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onPrevMonth,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _titleGreen,
                      size: shortest * 0.062,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${month.year}.${month.month.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.038,
                      color: _titleGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onNextMonth,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: _titleGreen,
                      size: shortest * 0.062,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: _titleGreen),
                  )
                : days.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(shortest * 0.02),
                          child: Text(
                            '이 달에\n저장된 일지가\n없어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontSize: shortest * 0.03,
                              color: _mutedGrey,
                              height: 1.35,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          shortest * 0.004,
                          shortest * 0.01,
                          shortest * 0.004,
                          shortest * 0.02,
                        ),
                        itemCount: days.length,
                        itemBuilder: (context, i) {
                          final day = days[i];
                          final isSelected = selectedDate != null &&
                              day.date.year == selectedDate!.year &&
                              day.date.month == selectedDate!.month &&
                              day.date.day == selectedDate!.day;
                          final tempColor = _temperatureColor(day.temperature);
                          final tempLabel =
                              '${day.temperature.toStringAsFixed(1)}°C';

                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Material(
                                  color: isSelected
                                      ? _panelGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => onSelectDate(day.date),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: shortest * 0.01,
                                        vertical: shortest * 0.022,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${day.date.month}/${day.date.day}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Cafe24Oneprettynight',
                                              fontSize: shortest * 0.034,
                                              color: isSelected
                                                  ? _titleGreen
                                                  : _mutedGrey,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: shortest * 0.008),
                                          Text(
                                            day.familyWeather.isEmpty
                                                ? '·'
                                                : day.familyWeather,
                                            style: TextStyle(
                                              fontSize: day.familyWeather.isEmpty
                                                  ? shortest * 0.034
                                                  : shortest * 0.046,
                                              color: _mutedGrey,
                                              height: 1,
                                            ),
                                          ),
                                          SizedBox(height: shortest * 0.008),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: const Color(0xFFE0DACF),
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x14000000),
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: shortest * 0.018,
                                                vertical: shortest * 0.008,
                                              ),
                                              child: Text(
                                                tempLabel,
                                                style: TextStyle(
                                                  fontFamily: 'FamilyNameDate',
                                                  fontSize: shortest * 0.036,
                                                  color: tempColor,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (i != days.length - 1)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: shortest * 0.008,
                                    horizontal: shortest * 0.004,
                                  ),
                                  child: CustomPaint(
                                    painter: const _DashedDividerPainter(),
                                    child: const SizedBox(
                                      width: double.infinity,
                                      height: 1,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DiaryDetailPane extends StatelessWidget {
  const _DiaryDetailPane({
    required this.day,
    required this.shortest,
    required this.members,
    required this.loading,
    required this.ctaLabel,
    required this.onWrite,
  });

  final _DiaryDay day;
  final double shortest;
  final List<_WeatherMember> members;
  final bool loading;
  final String ctaLabel;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: _titleGreen),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.04,
                    shortest * 0.035,
                    shortest * 0.04,
                    shortest * 0.02,
                  ),
                  children: [
                    Text(
                      day.headerLabel,
                      style: TextStyle(
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: shortest * 0.048,
                        color: _titleGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: shortest * 0.025),
                                    _FamilyWeatherSection(
                                      temperature: day.temperature,
                                      familyWeather: day.familyWeather,
                                      members: members,
                                      shortest: shortest,
                                    ),
                    SizedBox(height: shortest * 0.03),
                    Row(
                      children: [
                        SproutIcon(size: shortest * 0.035),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '오늘 우리 가족의 하루는 어땠나요?',
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontSize: shortest * 0.032,
                              color: _titleGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: shortest * 0.025),
                    if (day.hasEntries)
                      for (final entry in day.entries) ...[
                        _EntryCard(entry: entry, shortest: shortest),
                        SizedBox(height: shortest * 0.022),
                      ]
                    else
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: shortest * 0.06),
                        child: Text(
                          '아직 작성된 일지가 없어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.034,
                            color: _mutedGrey,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            shortest * 0.04,
            0,
            shortest * 0.04,
            shortest * 0.03,
          ),
          child: Material(
            color: const Color(0xFFE3EFD8),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onWrite,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: shortest * 0.034),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: _titleGreen,
                      size: shortest * 0.04,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ctaLabel,
                      style: TextStyle(
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: shortest * 0.034,
                        color: _titleGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FamilyWeatherSection extends StatelessWidget {
  const _FamilyWeatherSection({
    required this.temperature,
    required this.familyWeather,
    required this.members,
    required this.shortest,
  });

  final double temperature;
  final String familyWeather;
  final List<_WeatherMember> members;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    final tempColor = _temperatureColor(temperature);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              shortest * 0.025,
              shortest * 0.03,
              shortest * 0.025,
              0,
            ),
            child: Column(
              children: [
                Text(
                  '오늘의 가족 날씨',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.032,
                    color: _titleGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: shortest * 0.022),
                Text(
                  familyWeather.isEmpty ? '—' : familyWeather,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: familyWeather.isEmpty
                        ? shortest * 0.04
                        : shortest * 0.07,
                    color: _mutedGrey,
                    height: 1,
                  ),
                ),
                SizedBox(height: shortest * 0.018),
                Text(
                  '${temperature.toStringAsFixed(1)}°C',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'FamilyNameDate',
                    fontSize: shortest * 0.072,
                    color: tempColor,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: shortest * 0.028),
          if (members.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                shortest * 0.025,
                0,
                shortest * 0.025,
                shortest * 0.028,
              ),
              child: Text(
                '가족 구성원 정보를 불러오는 중…',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.026,
                  color: _mutedGrey,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final sidePad = shortest * 0.025;
                final gap = shortest * 0.015;
                final minCell = shortest * 0.16;
                final contentWidth = constraints.maxWidth - sidePad * 2;
                final fitTwo = (contentWidth - gap) / 2;
                final cellWidth = members.length <= 2
                    ? (contentWidth - gap * (members.length - 1)) /
                        members.length
                    : (fitTwo < minCell ? minCell : fitTwo) * 0.75;

                return Padding(
                  padding: EdgeInsets.only(bottom: shortest * 0.028),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    physics: members.length <= 2
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePad),
                      child: Row(
                        children: [
                          for (var i = 0; i < members.length; i++) ...[
                            if (i > 0) SizedBox(width: gap),
                            SizedBox(
                              width: cellWidth,
                              child: _MemberWeatherCell(
                                member: members[i].label,
                                selected: members[i].weather,
                                shortest: shortest,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MemberWeatherCell extends StatelessWidget {
  const _MemberWeatherCell({
    required this.member,
    required this.selected,
    required this.shortest,
  });

  final String member;
  final String selected;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          member,
          style: TextStyle(
            fontFamily: 'FamilyNameDate',
            fontSize: shortest * 0.028,
            color: _bodyGrey,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: shortest * 0.01),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: shortest * 0.028),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0DACF)),
          ),
          child: Text(
            selected.isEmpty ? '＋' : selected,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: selected.isEmpty ? shortest * 0.04 : shortest * 0.048,
              color: selected.isEmpty ? _mutedGrey : null,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.shortest,
  });

  final _DiaryEntry entry;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(shortest * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E2D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.author,
                style: TextStyle(
                  fontFamily: 'FamilyNameDate',
                  fontSize: shortest * 0.032,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                entry.timeLabel,
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.024,
                  color: _mutedGrey,
                ),
              ),
            ],
          ),
          SizedBox(height: shortest * 0.018),
          Text(
            entry.body,
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: shortest * 0.034,
              color: _bodyGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  const _DashedDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD5CFC2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dash = 4.0;
    const gap = 3.0;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            top: size.height * 0.05,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.3,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.07,
            child: Image.asset(
              'assets/images/todayquestionscreen/right_branch1.png',
              width: size.width * 0.32,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
