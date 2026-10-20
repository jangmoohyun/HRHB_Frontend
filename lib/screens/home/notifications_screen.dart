import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/family_context.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../album/album_detail_screen.dart';
import '../answers/family_answers_page.dart';
import '../answers/question_ref.dart';
import '../shell/home_shell.dart';

/// 알림 — list, 모두 읽음, 모두 비우기, swipe-free delete (×).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  bool _error = false;
  bool _read = false;

  /// Items sliding out (translateX(-110%), 260ms) before removal.
  final _leaving = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final page = await PendingApi.instance.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _read = page.unreadCount == 0;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _markRead({bool toast = false}) async {
    if (!_read) setState(() => _read = true);
    try {
      await PendingApi.instance.markAllNotificationsRead();
      if (toast && mounted) HaruToast.show(context, '알림을 모두 읽었어요.');
    } catch (_) {
      if (toast && mounted) HaruToast.show(context, '알림을 읽음으로 바꾸지 못했어요.');
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _leaving.add(n.id));
    await Future<void>.delayed(const Duration(milliseconds: 260));
    try {
      await PendingApi.instance.deleteNotification(n.id);
      if (!mounted) return;
      setState(() {
        _items?.removeWhere((x) => x.id == n.id);
        _leaving.remove(n.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _leaving.remove(n.id));
      HaruToast.show(context, '알림을 지우지 못했어요.');
    }
  }

  Future<void> _clear() async {
    final items = _items ?? const [];
    setState(() => _leaving.addAll(items.map((n) => n.id)));
    await Future<void>.delayed(const Duration(milliseconds: 260));
    try {
      await PendingApi.instance.clearNotifications();
      if (!mounted) return;
      setState(() {
        _items = [];
        _leaving.clear();
        _read = true;
      });
      HaruToast.show(context, '알림을 모두 지웠어요.');
    } catch (_) {
      if (!mounted) return;
      setState(_leaving.clear);
      HaruToast.show(context, '알림을 지우지 못했어요.');
    }
  }

  (IconData, Color) _look(AppNotification n) {
    final actor = n.actorUserId == null ? null : FamilyContext.instance.value?.byUserId(n.actorUserId!);
    return switch (n.type) {
      NotificationType.questionArrived => (Symbols.mail_rounded, HaruColors.mint),
      NotificationType.answerPosted => (Symbols.chat_bubble_rounded, actor?.tint ?? HaruColors.orange),
      NotificationType.temperatureChanged => (Symbols.device_thermostat_rounded, HaruColors.yellow),
      NotificationType.diaryPosted => (Symbols.edit_note_rounded, HaruColors.panelGreen),
      NotificationType.albumPhotosAdded => (Symbols.photo_library_rounded, HaruColors.sand),
      NotificationType.unknown => (Symbols.notifications_rounded, HaruColors.mint),
    };
  }

  String _time(DateTime t) {
    final today = dateOnly(DateTime.now());
    final days = today.difference(dateOnly(t)).inDays;
    if (days <= 0) return ampmTime(t);
    if (days == 1) return '어제';
    if (days < 7) return '$days일 전';
    return '${t.month}월 ${t.day}일';
  }

  Future<void> _open(AppNotification n) async {
    _markRead();
    final shell = HomeShellScope.of(context);
    final date = n.targetDate ?? dateOnly(DateTime.now());
    switch (n.type) {
      case NotificationType.questionArrived:
        shell.switchTo(HaruTab.home);
      case NotificationType.answerPosted:
        final q = await _questionFor(date);
        if (!mounted) return;
        if (q == null || !q.isReady) {
          HaruToast.show(context, '질문을 찾지 못했어요.');
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: q)),
        );
      case NotificationType.temperatureChanged:
        shell.switchTo(HaruTab.family);
      case NotificationType.diaryPosted:
        shell.switchTo(HaruTab.diary);
      case NotificationType.albumPhotosAdded:
        final id = n.albumId;
        if (id != null) {
          shell.pushOn(HaruTab.album, AlbumDetailScreen(albumId: id, title: n.preview ?? ''));
        } else {
          shell.switchTo(HaruTab.album);
        }
      case NotificationType.unknown:
        break;
    }
  }

  Future<QuestionRef?> _questionFor(DateTime date) async {
    try {
      final api = ApiClient();
      if (sameDay(date, DateTime.now())) {
        return QuestionRef.fromResult(await AuthedCall.run(api.fetchTodayDailyQuestion));
      }
      final month = await AuthedCall.run(
        (t) => api.fetchMonthDailyQuestions(accessToken: t, year: date.year, month: date.month),
      );
      final hit = month.items.where((i) => sameDay(i.date, date)).firstOrNull;
      return hit == null ? null : QuestionRef.fromResult(hit);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return EdgeSwipeBack(
      child: RefreshIndicator(
        color: HaruColors.forest,
        backgroundColor: HaruColors.ivory,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, kNavClearance),
          children: [
            const SubHeader(title: '알림'),
            if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Center(
                  child: Pressable(
                    onTap: _load,
                    child: Text('알림을 불러오지 못했어요. 눌러서 다시 시도해 주세요.',
                        style: hr(15, color: HaruColors.inkMuted)),
                  ),
                ),
              )
            else if (items != null && items.isEmpty)
              const _Empty()
            else if (items != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Chip(
                    icon: Symbols.done_all_rounded,
                    label: '모두 읽음',
                    color: HaruColors.forest,
                    border: HaruColors.fieldBorder,
                    onTap: () => _markRead(toast: true),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    icon: Symbols.delete_sweep_rounded,
                    label: '모두 비우기',
                    color: HaruColors.danger,
                    border: HaruColors.dangerBorder,
                    onTap: _clear,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // flex column, gap 8, overflow hidden (rows slide out under it)
              ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
                        child: Entrance(
                          kind: EntranceKind.riseIn,
                          duration: const Duration(milliseconds: 450),
                          delay: stagger(i, 50),
                          child: _Row(
                            n: items[i],
                            look: _look(items[i]),
                            time: _time(items[i].createdAt),
                            unread: !_read && !items[i].read,
                            leaving: _leaving.contains(items[i].id),
                            onTap: () => _open(items[i]),
                            onDelete: () => _delete(items[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .94,
      duration: Duration.zero,
      inlineTransition: false,
      child: Container(
        // 30 + 1px border (content-box)
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(HaruRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 3),
            Text(label, style: hr(14.5, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.n,
    required this.look,
    required this.time,
    required this.unread,
    required this.leaving,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification n;
  final (IconData, Color) look;
  final String time;
  final bool unread;
  final bool leaving;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (icon, bg) = look;
    return AnimatedSlide(
      offset: Offset(leaving ? -1.1 : 0, 0),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(.4, 0, 1, 1),
      child: AnimatedOpacity(
        opacity: leaving ? 0 : 1,
        duration: const Duration(milliseconds: 260),
        child: Pressable(
          onTap: onTap,
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(.4, 0, 1, 1),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: HaruColors.ivory,
              border: Border.all(color: HaruColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 22, color: HaruColors.forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(n.message, style: hr(16))),
                          if (unread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: HaruColors.badge, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      if ((n.preview ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hr(14, color: HaruColors.inkMuted),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(time, style: hr(13.5, color: HaruColors.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 32×32 with margin −4px −6px 0 0: takes 26 of the row and
                // sits 4 up, reaching 6 into the card padding.
                SizedBox(
                  width: 26,
                  height: 28,
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    maxWidth: 32,
                    maxHeight: 32,
                    child: Pressable(
                      onTap: onDelete,
                      scale: .88,
                      duration: Duration.zero,
                      inlineTransition: false,
                      semanticLabel: '알림 삭제',
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Symbols.close_rounded, size: 18, color: HaruColors.inkFaint),
                      ),
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
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Entrance(
      child: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Column(
          children: [
            FloatLoop(
              period: const Duration(milliseconds: 2400),
              distance: 6,
              delay: const Duration(milliseconds: 400),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: HaruColors.mint, borderRadius: BorderRadius.circular(22)),
                child: const Icon(Symbols.notifications_off_rounded, size: 36, color: HaruColors.softGreen),
              ),
            ),
            const SizedBox(height: 10),
            Text('새 알림이 없어요', style: hr(18, color: HaruColors.forest)),
            const SizedBox(height: 10),
            Text('가족 소식이 오면 여기에서 알려드릴게요', style: hr(14, color: HaruColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
