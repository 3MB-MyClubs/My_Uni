import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../services/app_strings.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/club_settings_design.dart';

/// `edit-category-light` / `-dark` — Figma `367:61` / `367:109`, inside
/// `canvas-edit-screens` `367:16`.
///
/// The club's Category editor, promoted from a bottom sheet to a full screen
/// because that is what the frame draws. Search-or-create at the top,
/// SUGGESTED pills below it, then ADDED pills that remove on tap.
///
/// Same storage as the sheet it replaces: `club.categoryName` is a
/// comma-separated string and `userPrefsService.saveClubCategory` persists it.
/// Nothing new is written.
class ClubEditCategoryScreen extends StatefulWidget {
  const ClubEditCategoryScreen({
    super.key,
    required this.club,
    required this.categoryOptions,
    required this.localizeCategory,
  });

  final Club club;

  /// The canonical list the settings screen already owns.
  final List<String> categoryOptions;

  /// Localizes a canonical category; custom tags come back unchanged.
  final String Function(BuildContext context, String category) localizeCategory;

  @override
  State<ClubEditCategoryScreen> createState() => _ClubEditCategoryScreenState();
}

class _ClubEditCategoryScreenState extends State<ClubEditCategoryScreen> {
  final TextEditingController _search = TextEditingController();

  /// Kept as a list, not a set: the frame draws ADDED in the order the club
  /// picked them, and `categoryName` round-trips in that order too.
  late final List<String> _added = _parse(widget.club.categoryName);
  late final List<String> _initial = List<String>.from(_added);
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static List<String> _parse(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return <String>[];
    return value
        .split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();
  }

  bool get _dirty => _added.join(', ') != _initial.join(', ');

  /// `suggested-chips` `411:11` — the canonical options, narrowed by the field.
  List<String> get _suggested {
    final query = _query.trim().toLowerCase();
    return widget.categoryOptions.where((category) {
      if (query.isEmpty) return true;
      return category.toLowerCase().contains(query) ||
          widget
              .localizeCategory(context, category)
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  /// The typed text is offerable as a new tag only when it is not already a
  /// suggestion or already added.
  String? get _creatable {
    final value = _search.text.trim();
    if (value.isEmpty) return null;
    bool matches(String other) => other.toLowerCase() == value.toLowerCase();
    if (widget.categoryOptions.any(matches)) return null;
    if (_added.any(matches)) return null;
    return value;
  }

  void _toggle(String category) {
    setState(() {
      final index = _added.indexWhere(
        (item) => item.toLowerCase() == category.toLowerCase(),
      );
      if (index >= 0) {
        _added.removeAt(index);
      } else {
        _added.add(category);
      }
    });
  }

  void _create() {
    final value = _creatable;
    if (value == null) return;
    setState(() {
      _added.add(value);
      _search.clear();
      _query = '';
    });
  }

  void _save() {
    final next = _added.join(', ');
    widget.club.categoryName = next.isEmpty ? null : next;
    userState.bumpClubInfo();
    unawaited(
      userPrefsService
          .saveClubCategory(widget.club.id, widget.club.categoryName)
          .catchError((_) {}),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suggested = _suggested;
    final creatable = _creatable;

    return Scaffold(
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              key: const ValueKey('club-edit-category-header'),
              title: S.clubCategoryTitle,
              compact: true,
              onBack: () => Navigator.maybePop(context),
              actions: [
                ClubSettingsSaveAction(
                  label: l10n.save,
                  enabled: _dirty,
                  onTap: _save,
                ),
              ],
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('club-edit-category-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  kClubProfileGutter,
                  12,
                  kClubProfileGutter,
                  28,
                ),
                children: [
                  ClubProfileCard(
                    key: const ValueKey('club-edit-category-input-card'),
                    padding: const EdgeInsets.all(16),
                    child: ClubSettingsSearchField(
                      key: const ValueKey('club-edit-category-search'),
                      controller: _search,
                      hint: S.clubCategorySearchHint,
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  if (creatable != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ClubSettingsChip(
                        key: const ValueKey('club-edit-category-create'),
                        label: S.clubCategoryAdd,
                        selected: true,
                        onTap: _create,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ClubSettingsSectionLabel(S.clubCategorySuggested),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in suggested)
                        ClubSettingsChip(
                          key: ValueKey('club-edit-category-chip-$category'),
                          label: widget.localizeCategory(context, category),
                          selected: _added.any(
                            (item) =>
                                item.toLowerCase() == category.toLowerCase(),
                          ),
                          onTap: () => _toggle(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ClubSettingsSectionLabel(S.clubCategoryAdded),
                  if (_added.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        S.clubCategoryNoneAdded,
                        style: figtree(
                          size: 12.5,
                          weight: FontWeight.w400,
                          color: ClubProfileColors.muted,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in _added)
                          ClubSettingsChip(
                            key: ValueKey('club-edit-category-added-$category'),
                            label: widget.localizeCategory(context, category),
                            removable: true,
                            onTap: () => _toggle(category),
                          ),
                      ],
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
