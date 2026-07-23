import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/personalization_service.dart' show kAcademicPrograms;

class AcademicProgramField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;

  const AcademicProgramField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value! : hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasValue ? AppColors.text : AppColors.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<String>?> showAcademicProgramPicker({
  required BuildContext context,
  required String title,
  required Iterable<String> selected,
  bool allowsMultiple = false,
  Iterable<String>? programs,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcademicProgramPickerSheet(
      title: title,
      selected: selected.toSet(),
      allowsMultiple: allowsMultiple,
      programs: programs?.toList() ?? kAcademicPrograms,
    ),
  );
}

class _AcademicProgramPickerSheet extends StatefulWidget {
  final String title;
  final Set<String> selected;
  final bool allowsMultiple;
  final List<String> programs;

  const _AcademicProgramPickerSheet({
    required this.title,
    required this.selected,
    required this.allowsMultiple,
    required this.programs,
  });

  @override
  State<_AcademicProgramPickerSheet> createState() =>
      _AcademicProgramPickerSheetState();
}

class _AcademicProgramPickerSheetState
    extends State<_AcademicProgramPickerSheet> {
  late final Set<String> _selected = {...widget.selected};
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  bool _matches(String program) {
    final query = _normalize(_query);
    if (query.isEmpty) return true;

    final normalizedProgram = _normalize(program);
    if (normalizedProgram.contains(query)) return true;

    final queryWords = query.split(' ');
    final programWords = normalizedProgram.split(' ');
    final wordsMatch = queryWords.every(
      (queryWord) => programWords.any((word) => word.startsWith(queryWord)),
    );
    if (wordsMatch) return true;

    final initials = programWords.map((word) => word[0]).join();
    return initials.startsWith(query.replaceAll(' ', ''));
  }

  void _select(String program) {
    if (!widget.allowsMultiple) {
      Navigator.pop(context, [program]);
      return;
    }
    setState(() {
      if (!_selected.add(program)) _selected.remove(program);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.programs.where(_matches).toList();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        if (!widget.allowsMultiple) {
                          Navigator.pop(context, <String>[]);
                          return;
                        }
                        setState(_selected.clear);
                      },
                      child: Text(
                        S.clear,
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  if (widget.allowsMultiple)
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _selected.toList()),
                      child: Text(
                        S.done,
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                key: const ValueKey('academic-program-picker-search'),
                controller: _searchController,
                focusNode: _searchFocus,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: S.searchMajors,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: S.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        S.noMatchingMajor,
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(bottom: bottomInset + 16),
                      itemCount: matches.length,
                      separatorBuilder: (_, index) => Divider(
                        height: 1,
                        indent: 20,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final program = matches[index];
                        final isSelected = _selected.contains(program);
                        return ListTile(
                          key: ValueKey('academic-program-$program'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 3,
                          ),
                          title: Text(
                            program,
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primaryRed,
                                )
                              : null,
                          onTap: () => _select(program),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
