import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/media_save_service.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';

import '../shell/home_shell.dart';

/// Pages through `/gallery/answer-photos` (21 per page) as [PhotoItem]s.
class AnswerPhotoFeed {
  final _api = ApiClient();
  final items = <PhotoItem>[];
  int total = 0;
  int _next = 0;
  bool hasMore = true;
  bool _busy = false;

  static String _dot(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> reset() async {
    items.clear();
    _next = 0;
    hasMore = true;
    await more();
  }

  Future<void> more() async {
    if (_busy || !hasMore) return;
    _busy = true;
    try {
      final page = await AuthedCall.run(
        (t) => _api.fetchGalleryAnswerPhotos(accessToken: t, page: _next, size: 21),
      );
      total = page.totalCount;
      for (final p in page.items) {
        final label = p.birthOrder == null
            ? MemberLook.shortFor(p.role)
            : FamilyMemberResult.labelFor(role: p.role, birthOrder: p.birthOrder);
        items.add(PhotoItem(
          url: p.imageUrl,
          date: _dot(p.date),
          who: label,
          caption: p.questionContent,
          fallbackTint: HaruColors.tints[items.length % HaruColors.tints.length],
        ));
      }
      hasMore = page.hasMore;
      _next++;
    } finally {
      _busy = false;
    }
  }
}

Future<void> saveToDevice(BuildContext context, List<String> urls) async {
  try {
    await const MediaSaveService().saveImageUrls(urls);
    if (!context.mounted) return;
    HaruToast.show(
      context,
      urls.length == 1 ? '사진을 기기에 저장했어요' : '${urls.length}장을 기기에 저장했어요',
      icon: LucideIcons.download,
    );
  } catch (e) {
    if (!context.mounted) return;
    HaruToast.show(
      context,
      e is StateError ? e.message : '사진을 저장하지 못했어요',
      icon: LucideIcons.circleAlert,
      iconColor: HaruColors.statusAttention,
    );
  }
}

/// 18 답변 사진 (선택 모드 포함).
class AnswerPhotosScreen extends StatefulWidget {
  const AnswerPhotosScreen({super.key, this.startSelecting = false});

  final bool startSelecting;

  @override
  State<AnswerPhotosScreen> createState() => _AnswerPhotosScreenState();
}

class _AnswerPhotosScreenState extends State<AnswerPhotosScreen> {
  final _feed = AnswerPhotoFeed();
  late bool _selecting = widget.startSelecting;
  final _sel = <int>{};
  bool _loading = true;
  bool _error = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await _feed.reset();
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _more() async {
    try {
      await _feed.more();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _tap(int i) {
    if (_selecting) {
      setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));
      return;
    }
    PhotoViewerPage.open(
      context,
      items: _feed.items,
      index: i,
      onSave: (item) => saveToDevice(context, [item.url]),
    );
  }

  Future<void> _saveSelected() async {
    setState(() => _saving = true);
    await saveToDevice(context, [for (final i in _sel) _feed.items[i].url]);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _selecting = false;
      _sel.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                HaruSubHeader(
                  title: '답변 사진',
                  trailing: [
                    HaruButton(
                      label: _selecting ? '취소' : '선택',
                      variant: HaruButtonVariant.ghost,
                      size: HaruButtonSize.sm,
                      onPressed: () => setState(() {
                        _selecting = !_selecting;
                        _sel.clear();
                      }),
                    ),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: HaruColors.primary))
                      : _error
                          ? HaruErrorState(onRetry: _load)
                          : _feed.items.isEmpty
                              ? const HaruEmptyState(
                                  icon: LucideIcons.images,
                                  title: '아직 답변에 첨부된 사진이 없어요',
                                  tint: HaruColors.accentSky,
                                  padding: EdgeInsets.symmetric(vertical: 120, horizontal: 32),
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n.metrics.extentAfter < 400) _more();
                                    return false;
                                  },
                                  child: ListView(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      kTabBarClearance + (_selecting ? 80 : 0),
                                    ),
                                    children: [
                                      PhotoGrid(
                                        items: _feed.items,
                                        onTap: _tap,
                                        selecting: _selecting,
                                        selected: _sel,
                                        captions: true,
                                        gap: 8,
                                        radius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                ),
              ],
            ),
            if (_selecting)
              Positioned(
                left: 12,
                right: 12,
                bottom: 92,
                child: SelectionBar(count: _sel.length, busy: _saving, onSave: _saveSelected),
              ),
          ],
        ),
      ),
    );
  }
}
