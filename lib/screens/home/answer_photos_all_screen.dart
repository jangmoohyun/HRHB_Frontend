import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/media_save_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);

class AnswerPhotoItem {
  const AnswerPhotoItem({
    required this.answerId,
    required this.imageUrl,
    required this.date,
    required this.author,
    required this.question,
  });

  final int answerId;
  final String imageUrl;
  final DateTime date;
  final String author;
  final String question;

  String get dateLabel =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  Object get heroTag => 'answer-photo-$answerId-$dateLabel-$author';
}

class AnswerPhotosAllScreen extends StatefulWidget {
  const AnswerPhotosAllScreen({super.key});

  @override
  State<AnswerPhotosAllScreen> createState() => _AnswerPhotosAllScreenState();
}

class _AnswerPhotosAllScreenState extends State<AnswerPhotosAllScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();
  final _mediaSave = const MediaSaveService();

  static const _pageSize = 21;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  String? _error;
  bool _selecting = false;
  bool _busyAction = false;
  List<AnswerPhotoItem> _items = const [];
  final Set<int> _selectedAnswerIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
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

  AnswerPhotoItem _map(GalleryAnswerPhotoResult item) {
    return AnswerPhotoItem(
      answerId: item.answerId,
      imageUrl: item.imageUrl,
      date: item.date,
      author: item.authorLabel,
      question: item.questionContent,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingMore = false;
    });
    try {
      final page = await _withAuth(
        (token) => _apiClient.fetchGalleryAnswerPhotos(
          accessToken: token,
          page: 0,
          size: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items.map(_map).toList();
        _nextPage = 1;
        _hasMore = page.hasMore;
        _selectedAnswerIds.clear();
        _selecting = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading || _selecting) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _withAuth(
        (token) => _apiClient.fetchGalleryAnswerPhotos(
          accessToken: token,
          page: _nextPage,
          size: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items.map(_map)];
        _nextPage = page.page + 1;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.maxScrollExtent <= 0) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
      _loadMore();
    }
    return false;
  }

  void _enterSelectMode() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택할 사진이 없어요.')),
      );
      return;
    }
    setState(() {
      _selecting = true;
      _selectedAnswerIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedAnswerIds.clear();
    });
  }

  void _toggleSelected(int answerId) {
    setState(() {
      if (_selectedAnswerIds.contains(answerId)) {
        _selectedAnswerIds.remove(answerId);
      } else {
        _selectedAnswerIds.add(answerId);
      }
    });
  }

  Future<void> _saveSelected() async {
    if (_selectedAnswerIds.isEmpty || _busyAction) return;
    final urls = _items
        .where((p) => _selectedAnswerIds.contains(p.answerId))
        .map((p) => p.imageUrl)
        .toList();
    setState(() => _busyAction = true);
    try {
      await _mediaSave.saveImageUrls(urls);
      if (!mounted) return;
      _exitSelectMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${urls.length}장의 사진을 저장했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 저장하지 못했어요.')),
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final items = _items;

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
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.02),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 88),
                          child: Text(
                            _selecting
                                ? '${_selectedAnswerIds.length}장 선택'
                                : '답변 사진 모아보기',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontSize: shortest * 0.05,
                              color: _titleGreen,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _selecting
                                  ? _exitSelectMode
                                  : () => Navigator.of(context).maybePop(),
                              icon: Icon(
                                _selecting
                                    ? Icons.close_rounded
                                    : Icons.arrow_back_ios_new_rounded,
                                color: _titleGreen,
                                size: 20,
                              ),
                            ),
                            const Spacer(),
                            if (!_selecting)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: _titleGreen,
                                ),
                                color: _cream,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'select') _enterSelectMode();
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'select',
                                    child: Text(
                                      '선택',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        color: _titleGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _titleGreen),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '사진을 불러오지 못했어요.',
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      fontSize: shortest * 0.038,
                                      color: _mutedGrey,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              ),
                            )
                          : items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(bottom: bottomPad + 40),
                                    child: Text(
                                      '아직 저장된 답변 사진이 없어요.',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        fontSize: shortest * 0.038,
                                        color: _mutedGrey,
                                      ),
                                    ),
                                  ),
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: _onScroll,
                                  child: RefreshIndicator(
                                    color: _titleGreen,
                                    onRefresh: _load,
                                    child: GridView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        size.width * 0.04,
                                        size.height * 0.004,
                                        size.width * 0.04,
                                        bottomPad +
                                            (_selecting
                                                ? size.height * 0.14
                                                : size.height * 0.12),
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: shortest * 0.025,
                                        mainAxisSpacing: shortest * 0.035,
                                        childAspectRatio: 0.72,
                                      ),
                                      itemCount:
                                          items.length + (_loadingMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index >= items.length) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: _titleGreen,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        final item = items[index];
                                        return _PhotoCell(
                                          items: items,
                                          index: index,
                                          shortest: shortest,
                                          selecting: _selecting,
                                          selected: _selectedAnswerIds
                                              .contains(item.answerId),
                                          onToggle: () =>
                                              _toggleSelected(item.answerId),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
          ),
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    size.width * 0.06,
                    12,
                    size.width * 0.06,
                    12 + bottomPad * 0.2,
                  ),
                  color: _cream.withValues(alpha: 0.96),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busyAction || _selectedAnswerIds.isEmpty
                          ? null
                          : _saveSelected,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _titleGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _titleGreen.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.items,
    required this.index,
    required this.shortest,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final List<AnswerPhotoItem> items;
  final int index;
  final double shortest;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  AnswerPhotoItem get item => items[index];

  void _openDetail(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnswerPhotoDetailScreen(
            items: items,
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
    return GestureDetector(
      onTap: () {
        if (selecting) {
          onToggle();
        } else {
          _openDetail(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: item.heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE8E0D4),
                        child: Icon(Icons.image_outlined, color: _softGreen),
                      ),
                    ),
                  ),
                ),
                if (selecting)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected ? _titleGreen : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? _titleGreen : _mutedGrey,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: shortest * 0.015),
          Text(
            item.dateLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: shortest * 0.026,
              color: _mutedGrey,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.author,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'FamilyNameDate',
              fontSize: shortest * 0.032,
              color: _titleGreen,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}


class AnswerPhotoDetailScreen extends StatefulWidget {
  const AnswerPhotoDetailScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<AnswerPhotoItem> items;
  final int initialIndex;

  @override
  State<AnswerPhotoDetailScreen> createState() =>
      _AnswerPhotoDetailScreenState();
}

class _AnswerPhotoDetailScreenState extends State<AnswerPhotoDetailScreen> {
  late final PageController _pageController;
  final _mediaSave = const MediaSaveService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadPhoto(AnswerPhotoItem item) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _mediaSave.saveImageUrls([item.imageUrl]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진이 저장되었어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진을 저장하지 못했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Hero(
                              tag: item.heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(
                                      color: Color(0xFFE8E0D4),
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: _softGreen,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.22),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  onPressed: () => _downloadPhoto(item),
                                  tooltip: '사진 저장',
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    Icons.download_rounded,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: size.height * 0.02),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            shortest * 0.045,
                            shortest * 0.04,
                            shortest * 0.045,
                            shortest * 0.045,
                          ),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.author,
                                    style: TextStyle(
                                      fontFamily: 'FamilyNameDate',
                                      fontSize: shortest * 0.045,
                                      color: _titleGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    item.dateLabel,
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      fontSize: shortest * 0.034,
                                      color: _mutedGrey,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: shortest * 0.03),
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: shortest * 0.04,
                                    color: _softGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '그날의 질문',
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      fontSize: shortest * 0.034,
                                      color: _titleGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: shortest * 0.015),
                              Text(
                                item.question,
                                style: TextStyle(
                                  fontFamily: 'Question',
                                  fontSize: shortest * 0.04,
                                  height: 1.4,
                                  color: _bodyGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
            top: size.height * 0.1,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.3,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.12,
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
