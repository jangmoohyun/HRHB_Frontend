import 'package:flutter/foundation.dart';

import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/haru/haru_family.dart';

import 'authed_call.dart';

/// Family name, invite code and members as the VER2 tabs need them.
class FamilySnapshot {
  const FamilySnapshot({
    required this.name,
    required this.code,
    required this.isCreator,
    required this.members,
    this.myRole,
    this.myBirthOrder,
  });

  final String name;
  final String code;

  /// Whether *I* created the family (controls 가족 이름 editing).
  final bool isCreator;
  final List<MemberLook> members;

  /// Raw role/birthOrder for the settings rows.
  final String? myRole;
  final int? myBirthOrder;

  MemberLook? get me {
    for (final m in members) {
      if (m.isMe) return m;
    }
    return null;
  }

  MemberLook? byUserId(int userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  String get countText => '${members.length}명이 함께하고 있어요';
}

/// Shared family state for every tab. Loads the cached profile first so the
/// first frame has names, then refreshes from `/api/families/me`.
class FamilyContext extends ChangeNotifier {
  FamilyContext._();
  static final instance = FamilyContext._();

  final _storage = TokenStorage();
  final _api = ApiClient();

  FamilySnapshot? _value;
  FamilySnapshot? get value => _value;

  Future<FamilySnapshot?> loadCached() async {
    final profile = await _storage.readFamilyProfile();
    final members = await _storage.readFamilyMembers();
    if (profile == null) return null;
    _value = _build(
      name: profile.familyName,
      code: profile.familyCode,
      isCreator: profile.isFamilyCreator,
      members: members,
    );
    notifyListeners();
    return _value;
  }

  Future<FamilySnapshot> refresh() async {
    final cachedCreator =
        (await _storage.readFamilyProfile())?.isFamilyCreator ?? false;
    final family = await AuthedCall.run(_api.fetchMyFamily);
    final meRow = family.members.where((m) => m.isMe).firstOrNull;
    final isCreator = meRow?.isCreator ?? cachedCreator;
    await _storage.saveFamilyProfile(
      familyName: family.familyName,
      familyCode: family.inviteCode,
      myRoleLabel: meRow?.roleLabel ?? '',
      isFamilyCreator: isCreator,
    );
    await _storage.saveFamilyMembers(family.members);
    _value = _build(
      name: family.familyName,
      code: family.inviteCode,
      isCreator: isCreator,
      members: family.members,
    );
    notifyListeners();
    return _value!;
  }

  /// Returns the cached snapshot if present, otherwise fetches.
  Future<FamilySnapshot> ensure() async {
    if (_value != null) return _value!;
    final cached = await loadCached();
    if (cached != null && cached.members.isNotEmpty) {
      // Refresh in the background; callers get names immediately.
      refresh().ignore();
      return cached;
    }
    return refresh();
  }

  void clear() {
    _value = null;
    notifyListeners();
  }

  FamilySnapshot _build({
    required String name,
    required String code,
    required bool isCreator,
    required List<FamilyMemberResult> members,
  }) {
    final meRow = members.where((m) => m.isMe).firstOrNull;
    final looks = MemberLook.forFamily([
      for (final m in members)
        (
          userId: m.userId,
          role: m.role,
          label: m.roleLabel,
          isMe: m.isMe,
          // Until the backend exposes isCreator for everyone, only "me" can be
          // marked (from /api/auth/me).
          isCreator: m.isCreator ?? (m.isMe && isCreator),
        ),
    ]);
    return FamilySnapshot(
      name: name,
      code: code,
      isCreator: isCreator,
      members: looks,
      myRole: meRow?.role,
      myBirthOrder: meRow?.birthOrder,
    );
  }
}
