import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../album/album_detail_screen.dart';
import '../answers/family_answers_page.dart';
import '../answers/question_ref.dart';
import '../family/temperature_screen.dart';
import '../shell/home_shell.dart';

/// 알림 — list from P6; marked read 1.8s after opening (prototype).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  bool _error = false;
  bool _readAll = false;
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final page = await PendingApi.instance.fetchNotifications();
      if (!mounted) return;
      setState(() => _items = page.items);
      _readTimer?.cancel();
      _readTimer = Timer(const Duration(milliseconds: 1800), () async {
        try {
          await PendingApi.instance.markAllNotificationsRead();
        } catch (_) {}
        if (mounted) setState(() => _readAll = true);
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  (IconData, Color) _look(AppNotification n, int index) => switch (n.type) {
        NotificationType.questionArrived => (LucideIcons.mail, HaruColors.accentGreen),
        NotificationType.answerPosted => (
            LucideIcons.messageCircle,
            index.isEven ? HaruColors.accentPink : HaruColors.accentSky,
          ),
        NotificationType.temperatureChanged => (LucideIcons.thermometerSun, HaruColors.accentOrange),
        NotificationType.diaryPosted => (LucideIcons.notebookPen, HaruColors.accentButter),
        NotificationType.albumPhotosAdded => (LucideIcons.images, HaruColors.accentTeal),
        NotificationType.unknown => (LucideIcons.bell, HaruColors.fillTranslucent),
      };

  Future<void> _open(AppNotification n) async {
    final shell = HomeShellScope.of(context);
    final date = n.targetDate ?? dateOnly(DateTime.now());
    switch (n.type) {
      case NotificationType.questionArrived:
        shell.switchTo(HaruTab.home);
      case NotificationType.answerPosted:
        final q = await _questionFor(date);
        if (!mounted || q == null) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => FamilyAnswersPage(question: q)),
        );
      case NotificationType.temperatureChanged:
        shell.pushOn(HaruTab.family, const TemperatureScreen());
      case NotificationType.diaryPosted:
        openDayOnArchive(context, date);
      case NotificationType.albumPhotosAdded:
        if (n.albumId != null) {
          shell.pushOn(HaruTab.album, AlbumDetailScreen(albumId: n.albumId!, title: ''));
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
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HaruSubHeader(title: '알림', ver2: true),
            Expanded(
              child: _error
                  ? HaruErrorState(onRetry: _load)
                  : items == null
                      ? const Center(child: CircularProgressIndicator(color: HaruColors.primary))
                      : items.isEmpty
                          ? const HaruEmptyState(
                              icon: LucideIcons.bell,
                              title: '아직 받은 알림이 없어요',
                              padding: EdgeInsets.symmetric(vertical: 100, horizontal: 32),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, kTabBarClearance),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (_, i) {
                                final n = items[i];
                                final unread = !n.read && !_readAll;
                                final (icon, tint) = _look(n, i);
                                return HaruRise(
                                  delay: Duration(milliseconds: i * 50),
                                  duration: const Duration(milliseconds: 400),
                                  child: Pressable(
                                    onTap: () => _open(n),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 600),
                                      curve: Curves.ease,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: unread ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: tint,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(icon, size: 20, color: HaruColors.ink),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(n.message, style: haruText(15, height: 1.45)),
                                                const SizedBox(height: 3),
                                                Text(
                                                  notificationTime(n.createdAt),
                                                  style: haruText(12, color: HaruColors.inkSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: unread ? HaruColors.streak : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
