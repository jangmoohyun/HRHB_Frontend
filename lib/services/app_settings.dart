import 'package:flutter/foundation.dart';

import 'package:hrhb_frontend/services/token_storage.dart';

/// 앱 표시 설정 (기기 단위, 로그아웃 후에도 유지).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final TokenStorage _tokens = TokenStorage();

  bool _loaded = false;
  bool _largeText = false;

  bool get loaded => _loaded;
  bool get largeText => _largeText;

  /// 큰 글씨 ON일 때 배율 (시스템 글자 크기 위에 곱함).
  static const double largeTextFactor = 1.22;

  double get textScaleFactor => _largeText ? largeTextFactor : 1.0;

  Future<void> load() async {
    try {
      _largeText = await _tokens.readLargeTextEnabled();
    } catch (_) {
      _largeText = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLargeText(bool enabled) async {
    if (_largeText == enabled) return;
    _largeText = enabled;
    notifyListeners();
    try {
      await _tokens.saveLargeTextEnabled(enabled);
    } catch (_) {}
  }
}
