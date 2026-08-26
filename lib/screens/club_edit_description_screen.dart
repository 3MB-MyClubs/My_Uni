import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/app_strings.dart';
import '../services/supabase_club_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/club_settings_design.dart';

/// `edit-description-light` / `-dark` — Figma `367:157` / `367:180`.
///
/// The club's Description editor, promoted from a bottom sheet to a full screen
/// to match the frame: a labelled card holding the textarea, and a counter line
/// under it.
///
/// **The frame prints "Maximum 300 characters"; this keeps the app's existing
/// 240.** The sheet this replaces capped at 240, and raising a stored field's
/// limit is only safe to confirm against the backend, which is off-limits — so
/// [kClubDescriptionMaxLength] is one constant to flip if that gets checked.
///
/// Persistence is unchanged: `supabaseClubService.updateClubDescription` then
/// `userPrefsService.saveClubDescription`, exactly what the sheet called.
const int kClubDescriptionMaxLength = 240;

class ClubEditDescriptionScreen extends StatefulWidget {
  const ClubEditDescriptionScreen({super.key, required this.club});

  final Club club;

  @override
  State<ClubEditDescriptionScreen> createState() =>
      _ClubEditDescriptionScreenState();
}

class _ClubEditDescriptionScreenState extends State<ClubEditDescriptionScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.club.description,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();

  bool get _canSave =>
      _value.isNotEmpty && _value != widget.club.description && !_saving;

  Future<void> _save() async {
    final value = _value;
    setState(() => _saving = true);
    try {
      await supabaseClubService.updateClubDescription(
        club: widget.club,
        description: value,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotUpdateClubDescription,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (!mounted) return;
    widget.club.description = value;
    userState.bumpClubInfo();
    unawaited(userPrefsService.saveClubDescription(widget.club.id, value));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final used = _controller.text.characters.length;

    return Scaffold(
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              key: const ValueKey('club-edit-description-header'),
              title: S.clubDescriptionTitle,
              compact: true,
              onBack: () => Navigator.maybePop(context),
              actions: [
                ClubSettingsSaveAction(
                  label: _saving ? l10n.savingEllipsis : l10n.save,
                  enabled: _canSave,
                  onTap: _save,
                ),
              ],
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('club-edit-description-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  kClubProfileGutter,
                  12,
                  kClubProfileGutter,
                  28,
                ),
                children: [
                  ClubSettingsSectionLabel(S.clubDescriptionTitle),
                  // `input-card` 367:174 — the textarea sits directly on the
                  // card, inset 16 all round, with no extra fill or frame.
                  ClubProfileCard(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      key: const ValueKey('club-edit-description-input'),
                      height: 160,
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        key: const ValueKey('club-edit-description-field'),
                        controller: _controller,
                        maxLength: kClubDescriptionMaxLength,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => setState(() {}),
                        style: figtree(
                          size: 14,
                          weight: FontWeight.w500,
                          color: ClubProfileColors.text,
                          height: 1.45,
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
                          // The frame prints its own counter below the card.
                          counterText: '',
                          hintText: l10n.clubDescriptionHint,
                          hintStyle: figtree(
                            size: 14,
                            weight: FontWeight.w400,
                            color: ClubProfileColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // `counter-container` 367:177.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.clubDescriptionMax(kClubDescriptionMaxLength),
                            style: figtree(
                              size: 12,
                              weight: FontWeight.w400,
                              color: ClubProfileColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          S.clubDescriptionCounter(
                            used,
                            kClubDescriptionMaxLength,
                          ),
                          style: figtree(
                            size: 12,
                            weight: FontWeight.w500,
                            color: ClubProfileColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
