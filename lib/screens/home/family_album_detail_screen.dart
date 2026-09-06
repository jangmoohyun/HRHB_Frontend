import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/media_save_service.dart';
import 'package:hrhb_frontend/services/token_storage.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _softGreen = Color(0xFF7FA87A);
const _mutedGrey = Color(0xFF8A8A8A);

class AlbumPhotoItem {
  const AlbumPhotoItem({
    required this.photoId,
    required this.imageUrl,
    required this.savedAt,
  });

  final int photoId;
  final String imageUrl;
  final DateTime savedAt;

  String get dateLabel =>
      '${savedAt.year}.${savedAt.month.toString().padLeft(2, '0')}.${savedAt.day.toString().padLeft(2, '0')}';

  Object get heroTag => 'album-photo-$photoId-$imageUrl-$dateLabel';
}

class FamilyAlbumDetailScreen extends StatefulWidget {
  const FamilyAlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.title,
  });

  final int albumId;
  final String title;

  @override
  State<FamilyAlbumDetailScreen> createState() =>
      _FamilyAlbumDetailScreenState();
}

class _FamilyAlbumDetailScreenState extends State<FamilyAlbumDetailScreen> {
  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();
  final _picker = ImagePicker();
  final _mediaSave = const MediaSaveService();

  static const _maxUploadCount = 20;
  static const _pageSize = 21;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  bool _uploading = false;
  bool _selecting = false;
  bool _busyAction = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  String? _error;
  late String _title;
  List<AlbumPhotoItem> _photos = const [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _title = widget.title;
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

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/jpeg' || mime == 'image/webp') {
      return mime!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickAndUploadPhotos() async {
    if (_uploading) return;
    final files = await _picker.pickMultiImage(limit: _maxUploadCount);
    if (files.isEmpty || !mounted) return;

    final selected = files.take(_maxUploadCount).toList();
    if (files.length > _maxUploadCount && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('한 번에 최대 20장까지 올릴 수 있어요.')),
      );
    }

    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = selected.length;
    });

    try {
      final imageKeys = <String>[];
      for (final file in selected) {
        final contentType = _contentTypeFor(file);
        final bytes = await file.readAsBytes();
        final key = await _withAuth((token) async {
          final upload = await _apiClient.createAlbumPhotoUploadUrl(
            accessToken: token,
            albumId: widget.albumId,
            contentType: contentType,
          );
          await _apiClient.uploadBytesToPresignedUrl(
            uploadUrl: upload.uploadUrl,
            bytes: bytes,
            contentType: upload.contentType,
          );
          return upload.imageKey;
        });
        imageKeys.add(key);
        if (!mounted) return;
        setState(() => _uploadDone = imageKeys.length);
      }

      await _withAuth(
        (token) => _apiClient.addAlbumPhotos(
          accessToken: token,
          albumId: widget.albumId,
          imageKeys: imageKeys,
        ),
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imageKeys.length}장의 사진을 올렸어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 올리지 못했어요.')),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingMore = false;
    });
    try {
      final detail = await _withAuth(
        (token) => _apiClient.fetchFamilyAlbumDetail(
          accessToken: token,
          albumId: widget.albumId,
          page: 0,
          size: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _title = detail.title;
        _photos = detail.photos
            .map(
              (p) => AlbumPhotoItem(
                photoId: p.photoId,
                imageUrl: p.imageUrl,
                savedAt: p.savedAt,
              ),
            )
            .toList();
        _nextPage = 1;
        _hasMore = detail.hasMore;
        _selectedIds.clear();
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
    if (!_hasMore || _loadingMore || _loading || _selecting || _uploading) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final detail = await _withAuth(
        (token) => _apiClient.fetchFamilyAlbumDetail(
          accessToken: token,
          albumId: widget.albumId,
          page: _nextPage,
          size: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _photos = [
          ..._photos,
          ...detail.photos.map(
            (p) => AlbumPhotoItem(
              photoId: p.photoId,
              imageUrl: p.imageUrl,
              savedAt: p.savedAt,
            ),
          ),
        ];
        _nextPage = detail.page + 1;
        _hasMore = detail.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.maxScrollExtent <= 0) return false;
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 160) {
      _loadMore();
    }
    return false;
  }

  Future<void> _renameAlbum() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameAlbumDialog(initialName: _title),
    );
    if (name == null || name.isEmpty || name == _title) return;

    try {
      final updated = await _withAuth(
        (token) => _apiClient.renameFamilyAlbum(
          accessToken: token,
          albumId: widget.albumId,
          name: name,
        ),
      );
      if (!mounted) return;
      setState(() => _title = updated.title);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앨범 이름을 바꿨어요.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = error.code == 'ALBUM_NAME_DUPLICATE' ||
              error.statusCode == 409
          ? '이미 같은 이름의 앨범이 있어요.'
          : '이름을 바꾸지 못했어요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 바꾸지 못했어요.')),
      );
    }
  }

  Future<void> _deleteAlbum() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '앨범을 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: _titleGreen,
          ),
        ),
        content: const Text(
          '앨범 안 사진도 함께 삭제돼요.',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: Color(0xFF4A4A4A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                color: _mutedGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                color: Color(0xFFC45C5C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _withAuth(
        (token) => _apiClient.deleteFamilyAlbum(
          accessToken: token,
          albumId: widget.albumId,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앨범을 삭제하지 못했어요.')),
      );
    }
  }

  void _enterSelectMode() {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택할 사진이 없어요.')),
      );
      return;
    }
    setState(() {
      _selecting = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(int photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId);
      } else {
        _selectedIds.add(photoId);
      }
    });
  }

  Future<void> _saveSelected() async {
    if (_selectedIds.isEmpty || _busyAction) return;
    final urls = _photos
        .where((p) => _selectedIds.contains(p.photoId))
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _busyAction) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '선택한 사진을 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: _titleGreen,
          ),
        ),
        content: Text(
          '${_selectedIds.length}장이 앨범에서 삭제돼요.',
          style: const TextStyle(
            fontFamily: 'Cafe24Oneprettynight',
            color: Color(0xFF4A4A4A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                color: _mutedGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                color: Color(0xFFC45C5C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyAction = true);
    try {
      final ids = _selectedIds.toList();
      await _withAuth(
        (token) => _apiClient.deleteAlbumPhotos(
          accessToken: token,
          albumId: widget.albumId,
          photoIds: ids,
        ),
      );
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((p) => !ids.contains(p.photoId)).toList();
        _selecting = false;
        _selectedIds.clear();
        _busyAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length}장의 사진을 삭제했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 삭제하지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final items = _photos;

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
                          padding: const EdgeInsets.symmetric(horizontal: 96),
                          child: Text(
                            _selecting
                                ? '${_selectedIds.length}장 선택'
                                : _title,
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
                            if (!_selecting && !_loading && _error == null)
                              IconButton(
                                onPressed:
                                    _uploading ? null : _pickAndUploadPhotos,
                                tooltip: '사진 추가',
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color:
                                      _uploading ? _mutedGrey : _titleGreen,
                                ),
                              ),
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
                                  if (value == 'select') {
                                    _enterSelectMode();
                                  } else if (value == 'rename') {
                                    _renameAlbum();
                                  } else if (value == 'delete') {
                                    _deleteAlbum();
                                  }
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
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(
                                      '이름 변경',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        color: _titleGreen,
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      '앨범 삭제',
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        color: Color(0xFFC45C5C),
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
                                    '앨범을 불러오지 못했어요.',
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
                                      '아직 사진이 없어요',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Cafe24Oneprettynight',
                                        fontSize: shortest * 0.038,
                                        color: _mutedGrey,
                                      ),
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  color: _titleGreen,
                                  onRefresh: _load,
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification: _onScrollNotification,
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
                                        mainAxisSpacing: shortest * 0.03,
                                        childAspectRatio: 0.82,
                                      ),
                                      itemCount: items.length +
                                          (_loadingMore ? 1 : 0),
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
                                        return _AlbumPhotoCell(
                                          items: items,
                                          index: index,
                                          shortest: shortest,
                                          selecting: _selecting,
                                          selected: _selectedIds
                                              .contains(item.photoId),
                                          onToggle: () =>
                                              _toggleSelected(item.photoId),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busyAction || _selectedIds.isEmpty
                              ? null
                              : _saveSelected,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _titleGreen,
                            side: const BorderSide(color: _titleGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busyAction || _selectedIds.isEmpty
                              ? null
                              : _deleteSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC45C5C),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFC45C5C).withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              fontFamily: 'Cafe24Oneprettynight',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_uploading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: _titleGreen),
                        const SizedBox(height: 16),
                        Text(
                          '사진 올리는 중 $_uploadDone / $_uploadTotal',
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.038,
                            color: _titleGreen,
                          ),
                        ),
                      ],
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

class _AlbumPhotoCell extends StatelessWidget {
  const _AlbumPhotoCell({
    required this.items,
    required this.index,
    required this.shortest,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final List<AlbumPhotoItem> items;
  final int index;
  final double shortest;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  AlbumPhotoItem get item => items[index];

  void _openDetail(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AlbumPhotoDetailScreen(
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
                        child:
                            Icon(Icons.image_outlined, color: _softGreen),
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
          SizedBox(height: shortest * 0.01),
          Text(
            item.dateLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cafe24Oneprettynight',
              fontSize: shortest * 0.024,
              color: const Color(0xFF5A5A5A),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumPhotoDetailScreen extends StatefulWidget {
  const AlbumPhotoDetailScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<AlbumPhotoItem> items;
  final int initialIndex;

  @override
  State<AlbumPhotoDetailScreen> createState() => _AlbumPhotoDetailScreenState();
}

class _AlbumPhotoDetailScreenState extends State<AlbumPhotoDetailScreen> {
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

  Future<void> _downloadPhoto(AlbumPhotoItem item) async {
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
                    padding:
                        EdgeInsets.symmetric(horizontal: size.width * 0.06),
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
                        SizedBox(height: size.height * 0.016),
                        Text(
                          item.dateLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.034,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.5,
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

class _RenameAlbumDialog extends StatefulWidget {
  const _RenameAlbumDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameAlbumDialog> createState() => _RenameAlbumDialogState();
}

class _RenameAlbumDialogState extends State<_RenameAlbumDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

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
        '이름 변경',
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
          color: const Color(0xFF4A4A4A),
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
