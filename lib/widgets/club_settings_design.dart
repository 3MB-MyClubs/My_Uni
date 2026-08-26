import 'package:flutter/material.dart';

import 'club_profile_design.dart';

/// `settings-light` / `-dark` — Figma `350:6` / `350:184`, and the screens it
/// opens (`edit-category` `367:61`, `edit-description` `367:157`).
///
/// These frames sample to the **CLUB PROFILE** ramp, not the student settings
/// one: page `#FAF9F6` / `#0A0A0A`, cards `#FFFFFF` / `#121212`, inner fills
/// `#F4F4F5` / `#1E1E1E`. So everything here is built on [ClubProfileColors]
/// and pairs with [ClubProfileHeaderBar], exactly like the Manage Board Members
/// screen next door. `lib/widgets/settings_design.dart` stays the *student*
/// settings vocabulary and is untouched.
///
/// The one structural difference from the student frames: rows are **grouped**
/// — a section is a single card with hairlines between its rows, rather than
/// one card per row.
///
/// Every accent on these frames is drawn `#1DA1F2`. It is the mockup's default,
/// as on `board-members` `413:7`, and is rendered in the club burgundy here.

/// `section-label` `350:30` — an uppercase, tracked, muted label over a card.
class ClubSettingsSectionLabel extends StatelessWidget {
  const ClubSettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: figtree(
          size: 11,
          weight: FontWeight.w700,
          color: ClubProfileColors.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// `management-group` `350:70` — one card holding several rows, each separated
/// by a hairline inset to the card's padding.
class ClubSettingsGroupCard extends StatelessWidget {
  const ClubSettingsGroupCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return ClubProfileCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: ClubProfileColors.border),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// `settings-row` `350:71` — a 56pt row: a 32pt tinted icon tile, the title,
/// then a value, an external-link glyph, a chevron or a custom trailing.
class ClubSettingsRow extends StatelessWidget {
  const ClubSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.external = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;

  /// The muted string left of the chevron — the language, the board count.
  final String? value;

  /// Replaces everything on the right — the appearance and language toggles.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool chevron;

  /// Rows that leave the app end in a link glyph.
  final bool external;

  /// `danger-group`: the tile turns pale red and the glyph with it. The frame
  /// leaves the *label* on its blue default in light and white in dark — an
  /// unresolved mockup, so the label follows the tile and reads red, which is
  /// also what the student Danger Zone does.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger
        ? ClubProfileColors.danger
        : ClubProfileColors.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger
                    ? ClubProfileColors.dangerSurface
                    : ClubProfileColors.accentSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: danger
                    ? ClubProfileColors.danger
                    : ClubProfileColors.accentText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                // A trailing control leaves little room, so the title holds one
                // line there and may wrap onto a second when it is alone.
                maxLines: trailing == null ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else ...[
              if (value != null) ...[
                const SizedBox(width: 10),
                Text(
                  value!,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w500,
                    color: ClubProfileColors.muted,
                  ),
                ),
              ],
              if (external) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: ClubProfileColors.muted,
                ),
              ] else if (chevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ClubProfileColors.muted,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// `profile-card` `350:32` — the club's photo, name and an Edit chip, a
/// hairline, then the three filled [ClubSettingsDetailRow]s.
class ClubSettingsIdentityCard extends StatelessWidget {
  const ClubSettingsIdentityCard({
    super.key,
    required this.avatar,
    required this.name,
    required this.editLabel,
    required this.onEdit,
    required this.details,
  });

  final Widget avatar;
  final String name;
  final String editLabel;
  final VoidCallback onEdit;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    return ClubProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 56, height: 56, child: ClipOval(child: avatar)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 16,
                    weight: FontWeight.w800,
                    color: ClubProfileColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // `change-photo-btn` `350:40` — a 26pt tinted pill.
              GestureDetector(
                key: const ValueKey('club-settings-edit-photo'),
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClubProfileColors.accentSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: ClubProfileColors.accentText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        editLabel,
                        style: figtree(
                          size: 12,
                          weight: FontWeight.w700,
                          color: ClubProfileColors.accentText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: ClubProfileColors.border),
          const SizedBox(height: 17),
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            details[i],
          ],
        ],
      ),
    );
  }
}

/// `detail-row` `350:46` — a 56pt row on the card's inner fill: a small muted
/// glyph, the field name, and a chevron. The value itself is not drawn; the
/// frame keeps these as pure navigation.
class ClubSettingsDetailRow extends StatelessWidget {
  const ClubSettingsDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ClubProfileColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: ClubProfileColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: ClubProfileColors.muted,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: ClubProfileColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// `header-right` `367:73` — the Save action on the two editor frames. Muted
/// until there is something to save, so the header never invites a no-op.
class ClubSettingsSaveAction extends StatelessWidget {
  const ClubSettingsSaveAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('club-settings-save'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: figtree(
            size: 15,
            weight: FontWeight.w700,
            color: enabled
                ? ClubProfileColors.accentText
                : ClubProfileColors.muted,
          ),
        ),
      ),
    );
  }
}

/// `chip` / `chip-selected` / `chip-removable` `411:12` — the 32pt pills on
/// `edit-category`. Selected pills fill with the accent; removable ones carry
/// an × on the right.
class ClubSettingsChip extends StatelessWidget {
  const ClubSettingsChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.removable = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    final filled = selected || removable;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        padding: EdgeInsets.only(left: 12, right: removable ? 8 : 12),
        decoration: BoxDecoration(
          color: filled ? ClubProfileColors.accent : ClubProfileColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled ? ClubProfileColors.accent : ClubProfileColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: figtree(
                size: 13,
                weight: FontWeight.w600,
                color: filled ? Colors.white : ClubProfileColors.text,
              ),
            ),
            if (removable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

/// `search` `411:6` — a clean 44pt field with no fill or border. The board
/// screen's copy is private to its own file; this one serves the category
/// editor.
class ClubSettingsSearchField extends StatelessWidget {
  const ClubSettingsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: ClubProfileColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.done,
                style: figtree(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: ClubProfileColors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: figtree(
                    size: 13.5,
                    weight: FontWeight.w400,
                    color: ClubProfileColors.muted,
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
