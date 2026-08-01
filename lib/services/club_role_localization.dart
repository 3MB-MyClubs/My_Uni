import '../l10n/app_localizations.dart';

/// Translates standard club roles while leaving club-specific custom titles
/// exactly as their admins entered them.
String localizedClubRole(AppLocalizations l10n, String? role) {
  final value = role?.trim() ?? '';
  if (value.isEmpty) return l10n.memberRoleDefault;

  return switch (_normalizedClubRole(value)) {
    'member' || 'üye' => l10n.memberRoleDefault,
    'board member' ||
    'boardmember' ||
    'kurul üyesi' ||
    'yönetim kurulu üyesi' => l10n.boardMemberFallbackTitle,
    'president' || 'başkan' => l10n.clubRolePresident,
    'vice president' ||
    'vicepresident' ||
    'başkan yardımcısı' => l10n.clubRoleVicePresident,
    'founder' || 'kurucu' => l10n.clubRoleFounder,
    'co founder' ||
    'cofounder' ||
    'eş kurucu' ||
    'kurucu ortak' => l10n.clubRoleCoFounder,
    'secretary' || 'sekreter' => l10n.clubRoleSecretary,
    'treasurer' || 'sayman' => l10n.clubRoleTreasurer,
    'coordinator' || 'koordinatör' => l10n.clubRoleCoordinator,
    'chair' || 'chairperson' => l10n.clubRoleChair,
    'vice chair' ||
    'vice chairperson' ||
    'başkan vekili' => l10n.clubRoleViceChair,
    'team lead' || 'team leader' || 'ekip lideri' => l10n.clubRoleTeamLead,
    _ => value,
  };
}

bool isClubMemberRole(String role) {
  final value = _normalizedClubRole(role);
  return value == 'member' || value == 'üye';
}

bool isClubFounderRole(String role) {
  final value = _normalizedClubRole(role);
  return value == 'founder' ||
      value == 'co founder' ||
      value == 'cofounder' ||
      value == 'kurucu' ||
      value == 'eş kurucu' ||
      value == 'kurucu ortak';
}

String _normalizedClubRole(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[_‐‑‒–—-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');
