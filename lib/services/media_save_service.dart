import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class MediaSaveService {
  const MediaSaveService();

  Future<void> saveImageUrls(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw StateError('사진 저장 권한이 필요해요.');
      }
    }

    for (final url in imageUrls) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('사진을 받지 못했어요.');
      }
      await Gal.putImageBytes(response.bodyBytes);
    }
  }
}
