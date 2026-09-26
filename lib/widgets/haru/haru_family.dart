import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// Diary weather. The server stores the legacy emoji values, so this maps
/// between the wire format and the VER2 icon tiles
/// (맑음 butter · 구름 조금 orange · 흐림 teal · 비 sky · 천둥번개 purple).
enum HaruWeather {
  sun('☀️', '맑음', LucideIcons.sun, HaruColors.accentButter),
  partly('⛅', '구름 조금', LucideIcons.cloudSun, HaruColors.accentOrange),
  cloud('☁️', '흐림', LucideIcons.cloud, HaruColors.accentTeal),
  rain('🌧️', '비', LucideIcons.cloudRain, HaruColors.accentSky),
  storm('⛈️', '천둥번개', LucideIcons.cloudLightning, HaruColors.accentPurple);

  const HaruWeather(this.wire, this.label, this.icon, this.tint);

  /// Value sent to / received from `/api/families/me/diary/*`.
  final String wire;
  final String label;
  final IconData icon;
  final Color tint;

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

  /// Most frequent weather — the prototype's `modeW` for the family composite.
  static HaruWeather? mode(Iterable<HaruWeather?> list) {
    final counts = <HaruWeather, int>{};
    for (final w in list) {
      if (w != null) counts[w] = (counts[w] ?? 0) + 1;
    }
    HaruWeather? best;
    for (final e in counts.entries) {
      if (best == null || e.value > counts[best]!) best = e.key;
    }
    return best;
  }
}

/// Rounded weather tile. A null [weather] draws the empty "–" tile.
class WeatherTile extends StatelessWidget {
  const WeatherTile({
    super.key,
    required this.weather,
    this.size = 46,
    this.radius = 14,
    this.iconSize = 20,
    this.emptyIcon = LucideIcons.minus,
    this.emptyColor = HaruColors.surface,
    this.emptyBorder = HaruColors.hairline,
    this.emptyIconColor = HaruColors.dsInkFaint,
    this.iconColor = HaruColors.dsInkSecondary,
  });

  final HaruWeather? weather;
  final double size;
  final double radius;
  final double iconSize;
  final IconData emptyIcon;
  final Color emptyColor;
  final Color emptyBorder;
  final Color emptyIconColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: w?.tint ?? emptyColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: w == null ? emptyBorder : Colors.transparent),
      ),
      child: Icon(
        w?.icon ?? emptyIcon,
        size: iconSize,
        color: w == null ? emptyIconColor : iconColor,
      ),
    );
  }
}

/// How a family member is drawn in VER2.
///
/// Prototype: 아빠 sky · 엄마 pink · 아들 green · 딸 butter, avatar initials
/// 빠 / 엄 / 나 (me) / 딸. Siblings with the same role get the next tint.
class MemberLook {
  const MemberLook({
    required this.userId,
    required this.label,
    required this.short,
    required this.initial,
    required this.tint,
    required this.isMe,
    this.isCreator = false,
  });

  final int userId;

  /// Full label, e.g. "첫째 아들".
  final String label;

  /// Role word, e.g. "아들".
  final String short;

  /// Single avatar character.
  final String initial;
  final Color tint;
  final bool isMe;
  final bool isCreator;

  static String shortFor(String role) => switch (role.toUpperCase()) {
        'FATHER' || '아빠' => '아빠',
        'MOTHER' || '엄마' => '엄마',
        'SON' || '아들' => '아들',
        'DAUGHTER' || '딸' => '딸',
        _ => role,
      };

  static String initialFor(String short, bool isMe) {
    if (isMe) return '나';
    return switch (short) {
      '아빠' => '빠',
      '엄마' => '엄',
      '아들' => '아',
      '딸' => '딸',
      _ => short.characters.isEmpty ? '?' : short.characters.first,
    };
  }

  static Color baseTint(String short) => switch (short) {
        '아빠' => HaruColors.accentSky,
        '엄마' => HaruColors.accentPink,
        '아들' => HaruColors.accentGreen,
        '딸' => HaruColors.accentButter,
        _ => HaruColors.accentTeal,
      };

  /// Builds looks for a whole family so duplicate roles get distinct tints.
  static List<MemberLook> forFamily(
    List<({int userId, String role, String label, bool isMe, bool isCreator})>
        members,
  ) {
    final used = <Color>{};
    final out = <MemberLook>[];
    for (final m in members) {
      final short = shortFor(m.role);
      var tint = baseTint(short);
      if (used.contains(tint)) {
        tint = HaruColors.tints.firstWhere(
          (t) => !used.contains(t),
          orElse: () => HaruColors.accentTeal,
        );
      }
      used.add(tint);
      out.add(MemberLook(
        userId: m.userId,
        label: m.label,
        short: short,
        initial: initialFor(short, m.isMe),
        tint: tint,
        isMe: m.isMe,
        isCreator: m.isCreator,
      ));
    }
    return out;
  }
}
