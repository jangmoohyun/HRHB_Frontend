import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import 'answer_photos_all_screen.dart';
import 'family_album_detail_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _cardWhite = Color(0xFFFFFCF6);
const _albumBtn = Color(0xFFE8F0E4);

class FamilyGalleryScreen extends StatefulWidget {
  const FamilyGalleryScreen({super.key});

  @override
  State<FamilyGalleryScreen> createState() => _FamilyGalleryScreenState();
}

class _FamilyGalleryScreenState extends State<FamilyGalleryScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  static const _albumPageSize = 10;

  bool _loading = true;
  String? _error;
  int _answerTotalCount = 0;
  List<AnswerPhotoItem> _answerPreview = const [];
  List<FamilyAlbumResult> _albums = const [];
  int _albumsNextPage = 0;
  bool _albumsHasMore = false;
  bool _albumsLoadingMore = false;

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

  AnswerPhotoItem _mapAnswer(GalleryAnswerPhotoResult item) {
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
      _albumsLoadingMore = false;
    });
    try {
      final preview = await _withAuth(
        (token) => _apiClient.fetchGalleryAnswerPhotos(
          accessToken: token,
          page: 0,
          size: 3,
        ),
      );
      final albumPage = await _withAuth(
        (token) => _apiClient.fetchFamilyAlbums(
          token,
          page: 0,
          size: _albumPageSize,
        ),
      );

      if (!mounted) return;
      setState(() {
        _answerTotalCount = preview.totalCount;
        _answerPreview = preview.items.map(_mapAnswer).toList();
        _albums = albumPage.albums;
        _albumsNextPage = 1;
        _albumsHasMore = albumPage.hasMore;
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

  Future<void> _loadMoreAlbums() async {
    if (!_albumsHasMore || _albumsLoadingMore || _loading) return;
    setState(() => _albumsLoadingMore = true);
    try {
      final albumPage = await _withAuth(
        (token) => _apiClient.fetchFamilyAlbums(
          token,
          page: _albumsNextPage,
          size: _albumPageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _albums = [..._albums, ...albumPage.albums];
        _albumsNextPage = albumPage.page + 1;
        _albumsHasMore = albumPage.hasMore;
        _albumsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _albumsLoadingMore = false);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) return false;
    if (metrics.pixels >= metrics.maxScrollExtent - 160) {
      _loadMoreAlbums();
    }
    return false;
  }

  Future<void> _createAlbum(String name) async {
    try {
      final created = await _withAuth(
        (token) => _apiClient.createFamilyAlbum(
          accessToken: token,
          name: name,
        ),
      );
      if (!mounted) return;
      setState(() {
        _albums = [created, ..._albums];
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FamilyAlbumDetailScreen(
            albumId: created.albumId,
            title: created.title,
          ),
        ),
      );
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = error.code == 'ALBUM_NAME_DUPLICATE' ||
              error.statusCode == 409
          ? '이미 같은 이름의 앨범이 있어요.'
          : '앨범을 만들지 못했어요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앨범을 만들지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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
                _BrandHeader(shortest: shortest),
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
                                  const Text(
                                    '갤러리를 불러오지 못했어요.',
                                    style: TextStyle(
                                      fontFamily: 'Cafe24Oneprettynight',
                                      color: _bodyGrey,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: _titleGreen,
                              onRefresh: _load,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _onScrollNotification,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    size.width * 0.05,
                                    size.height * 0.018,
                                    size.width * 0.05,
                                    bottomPad + shortest * 0.15,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _AnswerPhotosSection(
                                        photos: _answerPreview,
                                        totalCount: _answerTotalCount,
                                        shortest: shortest,
                                      ),
                                      SizedBox(height: size.height * 0.028),
                                      _FamilyAlbumsSection(
                                        albums: _albums,
                                        shortest: shortest,
                                        loadingMore: _albumsLoadingMore,
                                        hasMore: _albumsHasMore,
                                        onCreateAlbum: _createAlbum,
                                        onAlbumTap: (album) async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  FamilyAlbumDetailScreen(
                                                albumId: album.albumId,
                                                title: album.title,
                                              ),
                                            ),
                                          );
                                          if (mounted) await _load();
                                        },
                                      ),
                                    ],
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.shortest});

  final double shortest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '하루 한번',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.07,
            color: _titleGreen,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        SproutIcon(size: shortest * 0.045),
      ],
    );
  }
}

class _AnswerPhotosSection extends StatelessWidget {
  const _AnswerPhotosSection({
    required this.photos,
    required this.totalCount,
    required this.shortest,
  });

  final List<AnswerPhotoItem> photos;
  final int totalCount;
  final double shortest;

  @override
  Widget build(BuildContext context) {
    final thumb = shortest * 0.22;

    return Container(
      padding: EdgeInsets.fromLTRB(
        shortest * 0.04,
        shortest * 0.04,
        shortest * 0.04,
        shortest * 0.045,
      ),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '답변 사진 모아보기',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.045,
                    color: _titleGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AnswerPhotosAllScreen(),
                    ),
                  );
                },
                child: Text(
                  '전체 보기 >',
                  style: TextStyle(
                    fontFamily: 'Cafe24Oneprettynight',
                    fontSize: shortest * 0.032,
                    color: _softGreen,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: shortest * 0.012),
          Text(
            '가족이 질문에 남긴 사진을 한눈에 볼 수 있어요',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: shortest * 0.03,
              color: _mutedGrey,
            ),
          ),
          SizedBox(height: shortest * 0.03),
          if (photos.isEmpty)
            Text(
              '아직 저장된 답변 사진이 없어요.',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: shortest * 0.034,
                color: _mutedGrey,
              ),
            )
          else
            SizedBox(
              height: thumb,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => SizedBox(width: shortest * 0.025),
                itemBuilder: (context, index) {
                  return _AnswerPhotoThumb(
                    url: photos[index].imageUrl,
                    size: thumb,
                    badge: index == 0 ? '$totalCount장' : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerPhotoThumb extends StatelessWidget {
  const _AnswerPhotoThumb({
    required this.url,
    required this.size,
    this.badge,
  });

  final String url;
  final double size;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE8E0D4),
                child: Icon(Icons.image_outlined, color: _softGreen),
              ),
            ),
            if (badge != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: size * 0.16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FamilyAlbumsSection extends StatelessWidget {
  const _FamilyAlbumsSection({
    required this.albums,
    required this.shortest,
    required this.loadingMore,
    required this.hasMore,
    required this.onCreateAlbum,
    required this.onAlbumTap,
  });

  final List<FamilyAlbumResult> albums;
  final double shortest;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function(String name) onCreateAlbum;
  final Future<void> Function(FamilyAlbumResult album) onAlbumTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/public/sprout.png',
              width: shortest * 0.05,
              height: shortest * 0.05,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '우리 가족 앨범',
                style: TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: shortest * 0.048,
                  color: _titleGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Material(
              color: _albumBtn,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () async {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => const _CreateAlbumDialog(),
                  );
                  if (name == null || name.isEmpty) return;
                  await onCreateAlbum(name);
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: shortest * 0.028,
                    vertical: shortest * 0.016,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: _titleGreen,
                        size: shortest * 0.04,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '새 앨범',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: shortest * 0.032,
                          color: _titleGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: shortest * 0.01),
        Text(
          '가족 이벤트별로 사진을 모아 저장할 수 있어요',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.03,
            color: _mutedGrey,
          ),
        ),
        SizedBox(height: shortest * 0.03),
        if (albums.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: shortest * 0.03),
            child: Text(
              '아직 만든 앨범이 없어요.',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: shortest * 0.034,
                color: _mutedGrey,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = shortest * 0.03;
              final cardW = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final album in albums)
                    SizedBox(
                      width: cardW,
                      child: _AlbumCard(
                        album: album,
                        shortest: shortest,
                        onTap: () => onAlbumTap(album),
                      ),
                    ),
                ],
              );
            },
          ),
        if (loadingMore)
          Padding(
            padding: EdgeInsets.only(top: shortest * 0.04),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _titleGreen,
                ),
              ),
            ),
          )
        else if (!hasMore && albums.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: shortest * 0.03),
            child: Text(
              '모든 앨범을 불러왔어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: shortest * 0.03,
                color: _mutedGrey,
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateAlbumDialog extends StatefulWidget {
  const _CreateAlbumDialog();

  @override
  State<_CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<_CreateAlbumDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;

    return AlertDialog(
      backgroundColor: _cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        '새 앨범 만들기',
        style: TextStyle(
          fontFamily: 'Cafe24Oneprettynight',
          fontSize: shortest * 0.045,
          color: _titleGreen,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirm(),
        style: TextStyle(
          fontFamily: 'Cafe24Oneprettynight',
          fontSize: shortest * 0.038,
          color: _bodyGrey,
        ),
        decoration: InputDecoration(
          hintText: '앨범 이름을 입력해주세요',
          hintStyle: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            fontSize: shortest * 0.034,
            color: _mutedGrey,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD5D0C4)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _softGreen, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '취소',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              color: _mutedGrey,
            ),
          ),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text(
            '확인',
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              color: _titleGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.shortest,
    required this.onTap,
  });

  final FamilyAlbumResult album;
  final double shortest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = album.coverUrl;
    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE8E0D4),
                        child:
                            Icon(Icons.image_outlined, color: _softGreen),
                      ),
                    )
                  else
                    const ColoredBox(
                      color: Color(0xFFE8E0D4),
                      child: Icon(Icons.photo_album_outlined,
                          color: _softGreen, size: 36),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _titleGreen.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${album.count}',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: shortest * 0.028,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                shortest * 0.03,
                shortest * 0.025,
                shortest * 0.03,
                shortest * 0.03,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.034,
                      color: _bodyGrey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.dateLabel,
                    style: TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: shortest * 0.028,
                      color: _mutedGrey,
                    ),
                  ),
                ],
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
            top: size.height * 0.08,
            child: Image.asset(
              'assets/images/todayquestionscreen/left_branch1.png',
              width: size.width * 0.3,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -size.width * 0.1,
            top: size.height * 0.1,
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
