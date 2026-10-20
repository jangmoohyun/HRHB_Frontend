import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/tokens.dart';

/// Diary weather. The server stores the legacy emoji values, so this maps
/// between the wire format and the prototype's `WX` table.
enum HaruWeather {
  sun('☀️', '맑음', Symbols.sunny_rounded, Color(0xFFF09A4A), HaruColors.yellow),
  partly('⛅', '구름 조금', Symbols.partly_cloudy_day_rounded, Color(0xFFE8A05A),
      HaruColors.orange),
  cloud('☁️', '흐림', Symbols.cloud_rounded, Color(0xFF5F5F5F), HaruColors.sand),
  rain('🌧️', '비', Symbols.rainy_rounded, Color(0xFF6A9BC8), HaruColors.lavender),
  storm('⛈️', '천둥 번개', Symbols.thunderstorm_rounded, Color(0xFF5B8FD9),
      HaruColors.lavender);

  const HaruWeather(this.wire, this.label, this.icon, this.color, this.bg);

  /// Value sent to / received from `/api/families/me/diary/*`.
  final String wire;
  final String label;
  final IconData icon;

  /// Icon color.
  final Color color;

  /// Tile background.
  final Color bg;

  static HaruWeather? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final w in values) {
      if (w.wire == value || w.name == value) return w;
    }
    // Tolerate emoji with/without the variation selector.
    final stripped = value.replaceAll('️', '');
    for (final w in values) {
      if (w.wire.replaceAll('️', '') == stripped) return w;
    }
    return null;
  }

  /// The prototype's `composite(w)`: average the members' weather on a
  /// sunny = 5 … storm = 1 scale and round back to a weather.
  static HaruWeather? composite(Iterable<HaruWeather?> list) {
    final scores = [
      for (final w in list)
        if (w != null) 5 - w.index,
    ];
    if (scores.isEmpty) return null;
    final avg = (scores.reduce((a, b) => a + b) / scores.length).round();
    return values[5 - avg];
  }
}

/// How a family member is drawn.
///
/// Prototype `MEMBERS`: 아빠 mint · 엄마 orange · 딸 lavender · 아들 yellow,
/// avatars show the role word, and "나" for me. A second member with the same
/// role gets the next free tint.
class MemberLook {
  const MemberLook({
    required this.userId,
    required this.label,
    required this.role,
    required this.tint,
    required this.isMe,
    this.isCreator = false,
  });

  final int userId;

  /// Full label, e.g. "첫째 딸".
  final String label;

  /// Role word, e.g. "딸".
  final String role;
  final Color tint;
  final bool isMe;
  final bool isCreator;

  /// Avatar text: "나" for me, otherwise the role word.
  String get short => isMe ? '나' : role;

  /// Name in answer/diary lists: "아들 (나)" for me.
  String get displayName => isMe ? '$label (나)' : label;

  static String roleFor(String raw) => switch (raw.toUpperCase()) {
        'FATHER' || '아빠' => '아빠',
        'MOTHER' || '엄마' => '엄마',
        'SON' || '아들' => '아들',
        'DAUGHTER' || '딸' => '딸',
        _ => raw,
      };

  static Color baseTint(String role) => switch (role) {
        '아빠' => HaruColors.mint,
        '엄마' => HaruColors.orange,
        '딸' => HaruColors.lavender,
        '아들' => HaruColors.yellow,
        _ => HaruColors.panelGreen,
      };

  /// Builds looks for a whole family so duplicate roles get distinct tints.
  static List<MemberLook> forFamily(
    List<({int userId, String role, String label, bool isMe, bool isCreator})>
        members,
  ) {
    final used = <Color>{};
    final out = <MemberLook>[];
    for (final m in members) {
      final role = roleFor(m.role);
      var tint = baseTint(role);
      if (used.contains(tint)) {
        tint = HaruColors.tints.firstWhere(
          (t) => !used.contains(t),
          orElse: () => HaruColors.sand,
        );
      }
      used.add(tint);
      out.add(MemberLook(
        userId: m.userId,
        label: m.label,
        role: role,
        tint: tint,
        isMe: m.isMe,
        isCreator: m.isCreator,
      ));
    }
    return out;
  }
}
