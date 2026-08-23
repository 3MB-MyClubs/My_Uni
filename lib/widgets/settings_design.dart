import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'clubup_design.dart';
import 'profile_design.dart';

/// `profile-settings-light` / `-dark` (Figma `120:3` / `120:144`) — the student
/// Settings page of the STUDENT PROFİLE handoff.
///
/// Everything here is local to that frame, the way every other redesigned area
/// keeps its own widgets: `settings_screen.dart` still draws the club-admin and
/// moderator settings with its original chrome, and none of those rows go
/// through these widgets.
///
/// Colors come from [SettingsColors], typography from [figtree].

// ── tokens ───────────────────────────────────────────────────────────────────

/// The settings frame reuses [ProfileColors] for page, card, hairline and text,
/// and adds four values of its own.
///
/// The notable one is [icon]: the profile frames keep `#800020` in dark, but
/// every icon on `profile-settings-dark` samples to `#E8A1A6` — the accent is
/// lifted here and nowhere else in the section. [danger] is likewise its own
/// red (`#DC2626` in both themes) rather than [ProfileColors.danger].
class SettingsColors {
  const SettingsColors._();

  static bool get _dark => themeService.isDark;

  /// Page background — `#FAF9F6` / `#09090B`.
  static Color get background => ProfileColors.background;

  /// Row card — `#FFFFFF` / `#18181B`.
  static Color get card => ProfileColors.card;

  /// Card hairline — `#E4E4E7` / `#27272A`.
  static Color get border => ProfileColors.border;

  /// Row title and page title — `#18181B` / `#FAFAFA`.
  static Color get text => ProfileColors.text;

  /// Section labels, subtitles, values and chevrons — `#71717A` / `#A1A1AA`.
  static Color get muted => ProfileColors.muted;

  /// The 34×34 square behind every row icon, and the segmented-toggle track —
  /// `#F4F4F5` / `#27272A`.
  static Color get tile =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

  /// Row icons — `#800020` light, **`#E8A1A6` dark**.
  static Color get icon =>
      _dark ? const Color(0xFFE8A1A6) : const Color(0xFF800020);

  /// The back button's ring, unchanged between themes.
  static const Color accent = Color(0xFF800020);

  /// The selected half of a segmented toggle — `#8B1111`, not the accent.
  static const Color toggleSelected = Color(0xFF8B1111);

  /// `Danger Zone` rows — `#DC2626` in both themes.
  static const Color danger = Color(0xFFDC2626);
}

/// `px-[24px]` — the frame's page padding, same as the profile frames.
const double kSettingsPagePadding = 24;

// ── chrome ───────────────────────────────────────────────────────────────────

/// `header` — the ringed back circle and the page title.
class SettingsHeaderBar extends StatelessWidget {
  const SettingsHeaderBar({
    super.key,
    required this.title,
    required this.onBack,
    this.backTooltip,
  });

  final String title;
  final VoidCallback onBack;
  final String? backTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSettingsPagePadding, 15, 24, 15),
      child: Row(
        children: [
          ProfileCircleButton(
            icon: Icons.chevron_left_rounded,
            iconSize: 22,
            tooltip: backTooltip,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 20,
                weight: FontWeight.w800,
                color: SettingsColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `sec-*` — an uppercase muted label over a run of row cards.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: figtree(
          size: 11,
          weight: FontWeight.w600,
          color: SettingsColors.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── rows ─────────────────────────────────────────────────────────────────────

/// `row-*` — one settings row, drawn as its own card.
///
/// The frame gives every row the same skeleton: a 34×34 icon tile, the title
/// (with an optional second line), then whatever sits on the right — a chevron,
/// a value beside a chevron, an external-link glyph, or a segmented toggle.
class SettingsRowCard extends StatelessWidget {
  const SettingsRowCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.external = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// The muted string left of the chevron — the saved-items count, the version.
  final String? value;

  /// Replaces the chevron entirely — the appearance and language toggles.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool chevron;

  /// Rows that leave the app end in a link glyph instead of a chevron.
  final bool external;

  /// `sec-danger-zone`: the icon and the title turn red, the tile does not.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger ? SettingsColors.danger : SettingsColors.text;
    final iconColor = danger ? SettingsColors.danger : SettingsColors.icon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SettingsColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: SettingsColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SettingsColors.tile,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 15,
                      weight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 11.5,
                        weight: FontWeight.w400,
                        color: SettingsColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (trailing == null) ...[
              if (value != null) ...[
                const SizedBox(width: 10),
                Text(
                  value!,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w500,
                    color: SettingsColors.muted,
                  ),
                ),
              ],
              if (external) ...[
                const SizedBox(width: 10),
                Icon(Icons.link_rounded, size: 15, color: SettingsColors.muted),
              ] else if (chevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: SettingsColors.muted,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The `toggle` on `row-appearance` and `row-language` — two labels in a filled
/// track, with a brief sliding transition between selections.
class SettingsSegmentedToggle extends StatefulWidget {
  const SettingsSegmentedToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const transitionDuration = Duration(milliseconds: 280);

  @override
  State<SettingsSegmentedToggle> createState() =>
      _SettingsSegmentedToggleState();
}

class _SettingsSegmentedToggleState extends State<SettingsSegmentedToggle> {
  late int _visualIndex;

  @override
  void initState() {
    super.initState();
    _visualIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(SettingsSegmentedToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.selectedIndex != _visualIndex) {
      _visualIndex = widget.selectedIndex;
    }
  }

  void _select(int index) {
    if (index == _visualIndex) return;
    setState(() => _visualIndex = index);
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.labels.isNotEmpty);
    assert(
      widget.selectedIndex >= 0 && widget.selectedIndex < widget.labels.length,
    );

    final unselectedStyle = figtree(
      size: 11.5,
      weight: FontWeight.w600,
      color: SettingsColors.muted,
    );
    var widestLabel = 0.0;
    for (final label in widget.labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: unselectedStyle),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > widestLabel) widestLabel = painter.width;
    }
    final cellWidth = widestLabel + 20;

    return AnimatedContainer(
      duration: SettingsSegmentedToggle.transitionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: SettingsColors.tile,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: SizedBox(
        width: cellWidth * widget.labels.length,
        height: 26,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: SettingsSegmentedToggle.transitionDuration,
              curve: Curves.easeInOutCubic,
              left: cellWidth * _visualIndex,
              top: 0,
              bottom: 0,
              width: cellWidth,
              child: const DecoratedBox(
                key: ValueKey('settings-segmented-indicator-surface'),
                decoration: BoxDecoration(
                  color: SettingsColors.toggleSelected,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 5,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < widget.labels.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _visualIndex,
                    child: GestureDetector(
                      onTap: i == _visualIndex ? null : () => _select(i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: cellWidth,
                        height: 26,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            style: unselectedStyle.copyWith(
                              color: i == _visualIndex
                                  ? Colors.white
                                  : SettingsColors.muted,
                            ),
                            child: Text(widget.labels[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
