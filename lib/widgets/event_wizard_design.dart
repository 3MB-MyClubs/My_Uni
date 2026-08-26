import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/app_strings.dart';
import '../services/theme_service.dart';
import 'clubup_design.dart';

/// The EVENT CREATION flow of the ClubUp-Desings handoff — the `wz-*` chain
/// that ends at **Publish Event** (`club-flow-label-wz-10` 364:66).
///
/// Frames: `light-details` 310:11 / 310:200 with the newer `Starts`/`Ends`
/// layout from `light-start-time` 315:8 / 315:196, `light-end-time` 315:102 /
/// 315:290 and `light-select-date` 319:7 / 319:179; `light-speakers` 310:62 /
/// 310:251 with `light-speakers-expanded` 325:6 / 325:76 and
/// `light-add-speaker-modal` 325:154 / 325:204; `light-preview` 310:133 /
/// 310:322 with `light-add-session` 325:485 / 325:591; and the final
/// `light-details` 324:978 / 324:1066 (the Event Preview page).
///
/// Everything here is local to the wizard. The attendee-facing
/// `event_detail_screen.dart` and the shared `AppColors` chrome are untouched.

// ── tokens ───────────────────────────────────────────────────────────────────

/// Sampled from the frame PNGs. The page/card ramp is the one [ClubUpColors]
/// already carries, but **this section lifts the accent in dark** to a bright
/// `#FA526B` — every button, link and tag chip in `310:251` is that colour, not
/// the `#800020` the CLUB HOME frames keep.
class EventWizardColors {
  const EventWizardColors._();

  static bool get _dark => themeService.isDark;

  /// Page — `#FAF9F6` / `#121212`.
  static Color get page =>
      _dark ? const Color(0xFF121212) : const Color(0xFFFAF9F6);

  /// Input, card and sheet surface — `#FFFFFF` / `#1E1E1E`.
  static Color get card => _dark ? const Color(0xFF1E1E1E) : Colors.white;

  /// Hairline — `#E4E4E7` / `#27272A`.
  static Color get border =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

  /// Primary text — `#18181B` / `#FAFAFA`.
  static Color get text =>
      _dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);

  /// Field labels and secondary text — `#71717A` / `#A1A1AA`.
  static Color get muted =>
      _dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

  /// Placeholder text — `#A1A1AA` / `#71717A`.
  static Color get placeholder =>
      _dark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

  /// The step chip and the session modal's field fill — `#F4F4F5` / `#27272A`.
  static Color get chip =>
      _dark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

  /// `#800020` in light, **`#FA526B` in dark** — see the class doc.
  static Color get accent =>
      _dark ? const Color(0xFFFA526B) : const Color(0xFF800020);

  /// Tag-chip fill — the accent at 10%.
  static Color get accentSurface => accent.withValues(alpha: 0.10);

  /// `overlay-scrim` 315:70 — `rgba(0,0,0,0.4)`.
  static const Color scrim = Color(0x66000000);
}

/// `screen-body` padding, and the gutter every card in the flow sits on.
const double kEventWizardGutter = 20;

// ── chrome ───────────────────────────────────────────────────────────────────

/// `nav-bar` 315:24 — back arrow, screen title, and the "N of 3" chip.
class EventWizardTopBar extends StatelessWidget {
  const EventWizardTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.stepLabel,
  });

  final String title;
  final VoidCallback onBack;

  /// "1 of 3" on the wizard steps; the preview page passes its own badge.
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('event-wizard-back'),
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: EventWizardColors.text,
                semanticLabel: AppLocalizations.of(context)!.back,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              key: const ValueKey('event-wizard-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 18,
                weight: FontWeight.w700,
                color: EventWizardColors.text,
              ),
            ),
          ),
          if (stepLabel != null) ...[
            const SizedBox(width: 8),
            Container(
              key: const ValueKey('event-wizard-step-chip'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: EventWizardColors.chip,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                stepLabel!,
                style: figtree(
                  size: 12,
                  weight: FontWeight.w600,
                  color: EventWizardColors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `bottom-action` 315:65 — one full-width accent button. The frame draws it
/// solid in every state, so it never greys out; a step that is not ready
/// explains why instead (same call the FİRST LANDİNG PAGE made).
class EventWizardBottomAction extends StatelessWidget {
  const EventWizardBottomAction({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kEventWizardGutter),
      child: GestureDetector(
        key: const ValueKey('event-wizard-primary-action'),
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EventWizardColors.accent,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: figtree(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── fields ───────────────────────────────────────────────────────────────────

/// `field-*` label — SemiBold 13 in the muted tone.
class EventWizardLabel extends StatelessWidget {
  const EventWizardLabel(this.text, {super.key, this.size = 13});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: figtree(
        size: size,
        weight: FontWeight.w600,
        color: EventWizardColors.muted,
      ),
    );
  }
}

/// `input-container` — the flow's one box: page fill, neutral hairline and
/// radius 12. Focus is communicated by the cursor, without an accent frame.
class EventWizardInputBox extends StatelessWidget {
  const EventWizardInputBox({
    super.key,
    required this.child,
    this.icon,
    this.active = false,
    this.filled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final Widget child;
  final IconData? icon;
  final bool active;

  /// Retained for call-site compatibility; all event fields now share the page
  /// background so a second filled layer is never drawn inside the box.
  final bool filled;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: EventWizardColors.page,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: EventWizardColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: active
                  ? EventWizardColors.accent
                  : EventWizardColors.muted,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A labelled text field in the flow's box.
class EventWizardTextField extends StatelessWidget {
  const EventWizardTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.maxLines = 1,
    this.minLines,
    this.filled = false,
    this.fieldKey,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final int maxLines;
  final int? minLines;
  final bool filled;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          EventWizardLabel(label!),
          const SizedBox(height: 6),
        ],
        EventWizardInputBox(
          icon: icon,
          filled: filled,
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: maxLines > 1 ? 10 : 12,
          ),
          child: TextField(
            key: fieldKey,
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: figtree(
              size: 14,
              weight: FontWeight.w400,
              color: EventWizardColors.text,
              height: maxLines > 1 ? 1.4 : null,
            ),
            decoration: InputDecoration(
              isDense: true,
              // The box above owns the surface and outline. Explicitly opt out
              // of the app-wide grey fill and burgundy focused border.
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: figtree(
                size: 14,
                weight: FontWeight.w400,
                color: EventWizardColors.placeholder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A date or time cell — `starts-date` / `starts-time` 316:7 / 316:11. Empty
/// reads as a placeholder; the one the open sheet belongs to uses accent text
/// while its frame remains neutral.
class EventWizardPickerField extends StatelessWidget {
  const EventWizardPickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.active = false,
    this.fieldKey,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool active;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventWizardLabel(label, size: 12),
        const SizedBox(height: 6),
        GestureDetector(
          key: fieldKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: EventWizardInputBox(
            icon: icon,
            active: active,
            child: Text(
              filled ? value! : placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: figtree(
                size: 14,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? EventWizardColors.accent
                    : filled
                    ? EventWizardColors.text
                    : EventWizardColors.placeholder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `photo-uploader` 315:32 — a dashed accent frame. With a cover picked it
/// shows the photo itself; the frame only ever mocks the empty state.
class EventWizardPhotoUploader extends StatelessWidget {
  const EventWizardPhotoUploader({
    super.key,
    required this.imagePath,
    required this.onTap,
  });

  final String? imagePath;
  final VoidCallback onTap;

  bool get _isRemote =>
      imagePath != null &&
      (imagePath!.startsWith('http://') || imagePath!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';
    final hasImage = path.isNotEmpty;
    return GestureDetector(
      key: const ValueKey('event-wizard-cover'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: EventWizardColors.accent,
          radius: 16,
          strokeWidth: 1.5,
        ),
        child: SizedBox(
          height: hasImage ? 160 : 100,
          width: double.infinity,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: _isRemote
                          ? Image.network(path, fit: BoxFit.cover)
                          : Image.file(File(path), fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.changeEventPhoto,
                          style: figtree(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    S.eventWizardCoverHint,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w600,
                      color: EventWizardColors.muted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const double dash = 6;
  static const double gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

// ── small parts ──────────────────────────────────────────────────────────────

/// `tag-Networking` 310:92 — accent-tinted pill with a remove glyph.
class EventWizardTagChip extends StatelessWidget {
  const EventWizardTagChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: EventWizardColors.accentSurface,
        borderRadius: const BorderRadius.all(Radius.circular(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: figtree(
              size: 13,
              weight: FontWeight.w600,
              color: EventWizardColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: ValueKey('event-wizard-tag-remove-$label'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Icon(
              Icons.cancel_rounded,
              size: 12,
              color: EventWizardColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// `add-tag-btn` 310:89 — the solid accent "Add" beside the tag input.
class EventWizardAddButton extends StatelessWidget {
  const EventWizardAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.buttonKey,
  });

  final String label;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: EventWizardColors.accent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(
          label,
          style: figtree(
            size: 14,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// `Add Speaker` / `Add Session` / `Add Registration Link` — a plus glyph and
/// accent label, no box.
class EventWizardTextAction extends StatelessWidget {
  const EventWizardTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.actionKey,
  });

  final String label;
  final VoidCallback onTap;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: actionKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 14, color: EventWizardColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: figtree(
              size: 13,
              weight: FontWeight.w600,
              color: EventWizardColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// `add-another-btn` 310:118 — a dashed, muted full-width row.
class EventWizardDashedButton extends StatelessWidget {
  const EventWizardDashedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.buttonKey,
  });

  final String label;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: EventWizardColors.border,
          radius: 12,
          strokeWidth: 1,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 14, color: EventWizardColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: figtree(
                  size: 13,
                  weight: FontWeight.w600,
                  color: EventWizardColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `speaker-card` 310:107.
class EventWizardSpeakerCard extends StatelessWidget {
  const EventWizardSpeakerCard({
    super.key,
    required this.name,
    required this.role,
    required this.linkedin,
    required this.onEdit,
    required this.onRemove,
  });

  final String name;
  final String role;
  final String? linkedin;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final link = linkedin?.trim() ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EventWizardColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: EventWizardColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 14,
                          weight: FontWeight.w700,
                          color: EventWizardColors.text,
                        ),
                      ),
                      if (role.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figtree(
                            size: 12,
                            weight: FontWeight.w400,
                            color: EventWizardColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  key: ValueKey('event-wizard-speaker-remove-$name'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: EventWizardColors.muted,
                  ),
                ),
              ],
            ),
            if (link.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 14,
                    color: EventWizardColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 12,
                        weight: FontWeight.w400,
                        color: EventWizardColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One `Programme Schedule` row — title, "Speaker: x", and the start time.
class EventWizardSessionRow extends StatelessWidget {
  const EventWizardSessionRow({
    super.key,
    required this.title,
    required this.speaker,
    required this.time,
    required this.onEdit,
    required this.onRemove,
    this.showDivider = true,
  });

  final String title;
  final String? speaker;
  final String time;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final who = speaker?.trim() ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: EventWizardColors.border),
                ),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w700,
                      color: EventWizardColors.text,
                    ),
                  ),
                  if (who.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      S.eventWizardSessionSpeakerLine(who),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 12,
                        weight: FontWeight.w400,
                        color: EventWizardColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.schedule_rounded,
              size: 12,
              color: EventWizardColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              time,
              style: figtree(
                size: 12,
                weight: FontWeight.w600,
                color: EventWizardColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: ValueKey('event-wizard-session-remove-$title'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: EventWizardColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── sheets ───────────────────────────────────────────────────────────────────

/// The chrome every sheet in this flow shares: `bottom-sheet` 315:71 —
/// radius 32 top, a handle, then a title row with the accent **Done** pill.
class _WizardSheet extends StatelessWidget {
  const _WizardSheet({
    required this.title,
    required this.body,
    this.onDone,
    this.footer,
  });

  final String title;
  final Widget body;
  final VoidCallback? onDone;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EventWizardColors.card,
        border: Border(top: BorderSide(color: EventWizardColors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: EventWizardColors.muted,
                  borderRadius: const BorderRadius.all(Radius.circular(100)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: figtree(
                        size: 16,
                        weight: FontWeight.w700,
                        color: EventWizardColors.text,
                      ),
                    ),
                  ),
                  if (onDone != null)
                    GestureDetector(
                      key: const ValueKey('event-wizard-sheet-done'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onDone,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: EventWizardColors.accent,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(99),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.done,
                          style: figtree(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            body,
            ?footer,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showWizardSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: EventWizardColors.scrim,
    builder: builder,
  );
}

/// `select-date` 319:7 — a Mo–Su month grid. Today carries the accent tint,
/// the selection the solid accent.
Future<DateTime?> showEventWizardDateSheet(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstAllowed,
}) {
  return _showWizardSheet<DateTime>(
    context,
    (_) => _DateSheet(initial: initial, firstAllowed: firstAllowed),
  );
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, this.firstAllowed});

  final DateTime initial;
  final DateTime? firstAllowed;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _month = DateTime(_selected.year, _selected.month);
  }

  bool _isBlocked(DateTime day) {
    final first = widget.firstAllowed;
    if (first == null) return false;
    final floor = DateTime(first.year, first.month, first.day);
    return day.isBefore(floor);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final monthLabel = DateFormat.yMMMM(locale).format(_month);
    // Monday-first, as the frame's Mo…Su header row reads.
    final firstWeekday = DateTime(_month.year, _month.month).weekday;
    final leading = firstWeekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final selected = date == _selected;
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final blocked = _isBlocked(date);
      cells.add(
        GestureDetector(
          key: ValueKey('event-wizard-day-$day'),
          behavior: HitTestBehavior.opaque,
          onTap: blocked ? null : () => setState(() => _selected = date),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? EventWizardColors.accent
                    : isToday
                    ? EventWizardColors.accentSurface
                    : null,
              ),
              child: Text(
                '$day',
                style: figtree(
                  size: 14,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : blocked
                      ? EventWizardColors.placeholder
                      : isToday
                      ? EventWizardColors.accent
                      : EventWizardColors.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _WizardSheet(
      title: S.eventWizardSelectDate,
      onDone: () => Navigator.pop(context, _selected),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  key: const ValueKey('event-wizard-month-prev'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: EventWizardColors.text,
                  ),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: figtree(
                      size: 16,
                      weight: FontWeight.w700,
                      color: EventWizardColors.text,
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('event-wizard-month-next'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: EventWizardColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.E(locale)
                            .format(DateTime(2024, 1, 1).add(Duration(days: i)))
                            .substring(0, 2),
                        style: figtree(
                          size: 12,
                          weight: FontWeight.w600,
                          color: EventWizardColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

/// `select-start-time` 315:71 — two wheels and a colon. The frame's wheel
/// steps in quarters; five-minute steps keep the same shape without losing
/// times the old picker could set.
Future<TimeOfDay?> showEventWizardTimeSheet(
  BuildContext context, {
  required TimeOfDay initial,
  required String title,
}) {
  return _showWizardSheet<TimeOfDay>(
    context,
    (_) => _TimeSheet(initial: initial, title: title),
  );
}

const int kEventWizardMinuteStep = 5;

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, required this.title});

  final TimeOfDay initial;
  final String title;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _hour;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  static const int _minuteCount = 60 ~/ kEventWizardMinuteStep;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minuteIndex =
        (widget.initial.minute ~/ kEventWizardMinuteStep) % _minuteCount;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required String Function(int) label,
    required Key wheelKey,
  }) {
    return Expanded(
      child: SizedBox(
        height: 220,
        child: ListWheelScrollView.useDelegate(
          key: wheelKey,
          controller: controller,
          itemExtent: 44,
          diameterRatio: 2.2,
          physics: const FixedExtentScrollPhysics(),
          overAndUnderCenterOpacity: 0.45,
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) {
              final selected = index == selectedIndex;
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: selected
                      ? BoxDecoration(
                          color: EventWizardColors.chip,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        )
                      : null,
                  child: Text(
                    label(index),
                    style: figtree(
                      size: selected ? 24 : 18,
                      weight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? EventWizardColors.text
                          : EventWizardColors.muted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _WizardSheet(
      title: widget.title,
      onDone: () => Navigator.pop(
        context,
        TimeOfDay(hour: _hour, minute: _minuteIndex * kEventWizardMinuteStep),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            _wheel(
              wheelKey: const ValueKey('event-wizard-hour-wheel'),
              controller: _hourCtrl,
              count: 24,
              selectedIndex: _hour,
              onSelected: (i) => setState(() => _hour = i),
              label: (i) => i.toString().padLeft(2, '0'),
            ),
            Text(
              ':',
              style: figtree(
                size: 24,
                weight: FontWeight.w700,
                color: EventWizardColors.text,
              ),
            ),
            _wheel(
              wheelKey: const ValueKey('event-wizard-minute-wheel'),
              controller: _minuteCtrl,
              count: _minuteCount,
              selectedIndex: _minuteIndex,
              onSelected: (i) => setState(() => _minuteIndex = i),
              label: (i) =>
                  (i * kEventWizardMinuteStep).toString().padLeft(2, '0'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What `add-speaker-modal` 325:154 collects.
class EventWizardSpeakerDraft {
  const EventWizardSpeakerDraft({
    required this.name,
    required this.role,
    required this.linkedin,
  });

  final String name;
  final String role;
  final String linkedin;
}

/// `add-speaker-modal` 325:154 / 325:204.
Future<EventWizardSpeakerDraft?> showEventWizardSpeakerSheet(
  BuildContext context, {
  EventWizardSpeakerDraft? existing,
}) {
  return _showWizardSheet<EventWizardSpeakerDraft>(
    context,
    (_) => _SpeakerSheet(existing: existing),
  );
}

class _SpeakerSheet extends StatefulWidget {
  const _SpeakerSheet({this.existing});

  final EventWizardSpeakerDraft? existing;

  @override
  State<_SpeakerSheet> createState() => _SpeakerSheetState();
}

class _SpeakerSheetState extends State<_SpeakerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _linkedin;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _role = TextEditingController(text: widget.existing?.role ?? '');
    _linkedin = TextEditingController(text: widget.existing?.linkedin ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _WizardSheet(
        title: S.eventWizardAddSpeaker,
        body: _CappedScroll(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventWizardTextField(
                  fieldKey: const ValueKey('event-wizard-speaker-name'),
                  controller: _name,
                  label: S.eventWizardFullName,
                  hint: S.eventWizardFullNameHint,
                ),
                const SizedBox(height: 14),
                EventWizardTextField(
                  controller: _role,
                  label: S.eventWizardRoleTitle,
                  hint: S.eventWizardRoleTitleHint,
                ),
                const SizedBox(height: 14),
                EventWizardTextField(
                  controller: _linkedin,
                  label: S.eventWizardLinkedinLabel,
                  hint: S.eventWizardLinkedinHint,
                  icon: Icons.business_center_outlined,
                ),
              ],
            ),
          ),
        ),
        footer: _SheetFooter(
          primaryLabel: S.eventWizardSaveSpeaker,
          primaryKey: const ValueKey('event-wizard-save-speaker'),
          onPrimary: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              EventWizardSpeakerDraft(
                name: name,
                role: _role.text.trim(),
                linkedin: _linkedin.text.trim(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// What `add-session` 325:485 collects. The handoff also draws an End Time
/// field; [EventSlot] has no per-session end, so only the start is kept —
/// nothing in the programme list or the preview shows one either.
class EventWizardSessionDraft {
  const EventWizardSessionDraft({
    required this.title,
    required this.speaker,
    required this.start,
  });

  final String title;
  final String speaker;
  final TimeOfDay start;
}

/// `add-session` 325:485 / 325:591.
Future<EventWizardSessionDraft?> showEventWizardSessionSheet(
  BuildContext context, {
  EventWizardSessionDraft? existing,
  required TimeOfDay defaultStart,
}) {
  return _showWizardSheet<EventWizardSessionDraft>(
    context,
    (_) => _SessionSheet(existing: existing, defaultStart: defaultStart),
  );
}

class _SessionSheet extends StatefulWidget {
  const _SessionSheet({required this.defaultStart, this.existing});

  final EventWizardSessionDraft? existing;
  final TimeOfDay defaultStart;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _speaker;
  late TimeOfDay _start;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _speaker = TextEditingController(text: widget.existing?.speaker ?? '');
    _start = widget.existing?.start ?? widget.defaultStart;
  }

  @override
  void dispose() {
    _title.dispose();
    _speaker.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showEventWizardTimeSheet(
      context,
      initial: _start,
      title: S.eventWizardSelectStartTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _WizardSheet(
        title: S.eventWizardAddSession,
        body: _CappedScroll(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventWizardTextField(
                  fieldKey: const ValueKey('event-wizard-session-name'),
                  controller: _title,
                  label: S.eventWizardSessionName,
                  hint: S.eventWizardSessionNameHint,
                  filled: true,
                ),
                const SizedBox(height: 14),
                EventWizardTextField(
                  controller: _speaker,
                  label: S.eventWizardSessionSpeaker,
                  hint: S.eventWizardSessionSpeakerHint,
                  filled: true,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 180,
                  child: EventWizardPickerField(
                    fieldKey: const ValueKey('event-wizard-session-start'),
                    label: S.eventWizardStartTime,
                    icon: Icons.schedule_rounded,
                    value: _start.format(context),
                    placeholder: S.eventWizardStartTime,
                    onTap: _pickStart,
                  ),
                ),
              ],
            ),
          ),
        ),
        footer: _SheetFooter(
          primaryLabel: S.eventWizardSaveSession,
          primaryKey: const ValueKey('event-wizard-save-session'),
          onPrimary: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              EventWizardSessionDraft(
                title: title,
                speaker: _speaker.text.trim(),
                start: _start,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The `Save …` / `Cancel` pair both modals end on.
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final Key? primaryKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            key: primaryKey,
            behavior: HitTestBehavior.opaque,
            onTap: onPrimary,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: EventWizardColors.accent,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Text(
                primaryLabel,
                style: figtree(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: EventWizardColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── step 3's live preview card ───────────────────────────────────────────────

/// `Live Event Preview` — the summary card `325:485` puts under the programme
/// list: thumbnail, title, location, then the when/speakers/sessions line.
class EventWizardLivePreviewCard extends StatelessWidget {
  const EventWizardLivePreviewCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.location,
    required this.whenLabel,
    required this.speakerCount,
    required this.sessionCount,
  });

  final String? imagePath;
  final String title;
  final String location;
  final String whenLabel;
  final int speakerCount;
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('event-wizard-live-preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EventWizardColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: EventWizardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EventWizardThumb(imagePath: imagePath, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? S.eventWizardUntitled : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 15,
                        weight: FontWeight.w700,
                        color: EventWizardColors.text,
                      ),
                    ),
                    if (location.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: EventWizardColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: figtree(
                                size: 12,
                                weight: FontWeight.w400,
                                color: EventWizardColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.event_outlined,
                size: 12,
                color: EventWizardColors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                whenLabel.toUpperCase(),
                style: figtree(
                  size: 11,
                  weight: FontWeight.w700,
                  color: EventWizardColors.accent,
                ),
              ),
              Text(
                '   ·   ${S.eventWizardSpeakerCount(speakerCount)}'
                '   ·   ${S.eventWizardSessionCount(sessionCount)}',
                style: figtree(
                  size: 11,
                  weight: FontWeight.w500,
                  color: EventWizardColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventWizardThumb extends StatelessWidget {
  const _EventWizardThumb({required this.imagePath, required this.size});

  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';
    final remote = path.startsWith('http://') || path.startsWith('https://');
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: SizedBox(
        width: size,
        height: size,
        child: path.isEmpty || path.startsWith('tpl:')
            ? ColoredBox(
                color: EventWizardColors.accentSurface,
                child: Center(
                  child: Icon(
                    Icons.event_outlined,
                    size: size * 0.42,
                    color: EventWizardColors.accent,
                  ),
                ),
              )
            : remote
            ? Image.network(path, fit: BoxFit.cover)
            : Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

// ── the Event Preview page ───────────────────────────────────────────────────

/// The body of the final frame, `light-details` 324:978 / 324:1066 — what the
/// club is about to publish, rendered from the draft rather than from a saved
/// event. The attendee-facing `EventDetailScreen` is not reused: it carries
/// RSVP, tickets and capacity that a preview has nothing to show for.
class EventWizardPreviewBody extends StatelessWidget {
  const EventWizardPreviewBody({
    super.key,
    required this.imagePath,
    required this.title,
    required this.location,
    required this.dateLabel,
    required this.timeLabel,
    required this.description,
    required this.tags,
    required this.speakers,
    required this.sessions,
  });

  final String? imagePath;
  final String title;
  final String location;
  final String dateLabel;
  final String timeLabel;
  final String description;
  final List<String> tags;

  /// name / role / linkedin, in the order the club entered them.
  final List<EventWizardSpeakerDraft> speakers;

  /// title / speaker / formatted time.
  final List<({String title, String speaker, String time})> sessions;

  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: EventWizardColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: figtree(
                size: 14,
                weight: FontWeight.w400,
                color: EventWizardColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: figtree(
          size: 14,
          weight: FontWeight.w700,
          color: EventWizardColors.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';
    final remote = path.startsWith('http://') || path.startsWith('https://');
    return ListView(
      key: const ValueKey('event-wizard-preview-body'),
      padding: const EdgeInsets.fromLTRB(
        kEventWizardGutter,
        4,
        kEventWizardGutter,
        24,
      ),
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          // 362 × 425 in the frame — but every frame has a cover. Without one,
          // a 425pt empty box would push the whole page below the fold.
          child: path.isEmpty || path.startsWith('tpl:')
              ? SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: ColoredBox(
                    color: EventWizardColors.accentSurface,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: EventWizardColors.accent,
                      ),
                    ),
                  ),
                )
              : AspectRatio(
                  aspectRatio: 4 / 5,
                  child: remote
                      ? Image.network(path, fit: BoxFit.cover)
                      : Image.file(File(path), fit: BoxFit.cover),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          title.isEmpty ? S.eventWizardUntitled : title,
          key: const ValueKey('event-wizard-preview-title'),
          style: figtree(
            size: 22,
            weight: FontWeight.w800,
            color: EventWizardColors.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (location.trim().isNotEmpty)
          _metaRow(Icons.place_outlined, location.trim()),
        _metaRow(Icons.calendar_today_outlined, dateLabel),
        _metaRow(Icons.schedule_rounded, timeLabel),
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          EventWizardLabel(S.eventWizardAbout),
          const SizedBox(height: 6),
          Text(
            description.trim(),
            style: figtree(
              size: 14,
              weight: FontWeight.w400,
              color: EventWizardColors.text,
              height: 1.45,
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: EventWizardColors.accentSurface,
                    borderRadius: const BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Text(
                    tag,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w600,
                      color: EventWizardColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (speakers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Divider(height: 1, color: EventWizardColors.border),
          const SizedBox(height: 16),
          _sectionTitle(AppLocalizations.of(context)!.speakers),
          for (final speaker in speakers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EventWizardSpeakerCard(
                name: speaker.name,
                role: speaker.role,
                linkedin: speaker.linkedin,
                onEdit: () {},
                onRemove: () {},
              ),
            ),
        ],
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _sectionTitle(S.eventWizardProgrammeSchedule),
          for (final session in sessions)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18, right: 12),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: EventWizardColors.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: EventWizardSessionRow(
                    title: session.title,
                    speaker: session.speaker,
                    time: session.time,
                    onEdit: () {},
                    onRemove: () {},
                    showDivider: session != sessions.last,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

// ── the plus menu ────────────────────────────────────────────────────────────

/// `plus-menu` 297:8 / 297:79 — the "Create New" sheet the club's + button
/// opens, with the two destinations `cr-1` (Create Post) and `cr-2` (Create
/// Event) the flow labels name.
Future<void> showEventWizardCreateSheet(
  BuildContext context, {
  required VoidCallback onPost,
  required VoidCallback onEvent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: EventWizardColors.scrim,
    builder: (sheetContext) {
      void choose(VoidCallback callback) {
        Navigator.of(sheetContext).pop();
        callback();
      }

      return Container(
        key: const ValueKey('club-create-sheet'),
        decoration: BoxDecoration(
          color: EventWizardColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: EventWizardColors.muted,
                    borderRadius: const BorderRadius.all(Radius.circular(100)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.eventWizardCreateNew,
                        style: figtree(
                          size: 22,
                          weight: FontWeight.w800,
                          color: EventWizardColors.text,
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: const ValueKey('club-create-sheet-close'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(sheetContext).pop(),
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 24,
                        color: EventWizardColors.muted,
                        semanticLabel: AppLocalizations.of(
                          sheetContext,
                        )!.cancel,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    _CreateSheetRow(
                      rowKey: const ValueKey('club-create-post'),
                      icon: Icons.article_outlined,
                      title: S.eventWizardCreatePost,
                      subtitle: S.eventWizardCreatePostSubtitle,
                      onTap: () => choose(onPost),
                    ),
                    const SizedBox(height: 12),
                    _CreateSheetRow(
                      rowKey: const ValueKey('club-create-event'),
                      icon: Icons.calendar_today_outlined,
                      title: S.eventWizardStepOneTitle,
                      subtitle: S.eventWizardCreateEventSubtitle,
                      onTap: () => choose(onEvent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

class _CreateSheetRow extends StatelessWidget {
  const _CreateSheetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.rowKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EventWizardColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: EventWizardColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: EventWizardColors.accentSurface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Center(
                child: Icon(icon, size: 22, color: EventWizardColors.accent),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 15,
                      weight: FontWeight.w700,
                      color: EventWizardColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: figtree(
                      size: 12,
                      weight: FontWeight.w400,
                      color: EventWizardColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: EventWizardColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bodies scroll inside half the screen so the keyboard and the footer
/// always have room. A plain `Flexible` here let the wheel and the fields get
/// squeezed against the screen edge.
class _CappedScroll extends StatelessWidget {
  const _CappedScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: child,
    );
  }
}
