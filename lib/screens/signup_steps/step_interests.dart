import 'package:flutter/material.dart';
import 'signup_theme.dart';

const List<String> kInterests = [
  'Basketball', 'Theatre', 'Robotics', 'A cappella', 'Hiking',
  'Volunteering', 'Film', 'Debate', 'Greek life', 'Climate',
  'Esports', 'Photography', 'Entrepreneurship', 'Dance', 'Faith',
  'Coding', 'Music', 'Art',
];

const int kMinInterests = 3;

class StepInterests extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onNext;
  final VoidCallback onSkip;

  const StepInterests({
    super.key,
    this.selected = const [],
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<StepInterests> createState() => _StepInterestsState();
}

class _StepInterestsState extends State<StepInterests> {
  late Set<String> _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  void _toggle(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
      if (_selected.length >= kMinInterests) { _error = null; }
    });
  }

  void _submit() {
    if (_selected.length < kMinInterests) {
      setState(() => _error = 'Pick at least $kMinInterests to continue.');
      return;
    }
    widget.onNext(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selected.length;
    return Column(
      children: [
        // ── Scrollable content ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's your scene?",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: SC.ink,
                    height: 1.1,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 15,
                        color: SC.body,
                        height: 1.45,
                        letterSpacing: -0.1),
                    children: [
                      TextSpan(
                          text:
                              "Pick a few — we'll match you with clubs, events, and people. "),
                      TextSpan(
                        text: '($selCount of $kMinInterests min.)',
                        style: TextStyle(
                          color: selCount >= kMinInterests
                              ? SC.burgundy
                              : SC.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kInterests.map((tag) {
                    final sel = _selected.contains(tag);
                    return GestureDetector(
                      onTap: () => _toggle(tag),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? SC.burgundy : SC.card,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: sel ? SC.burgundy : SC.hair,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sel) ...[
                              Text('✓',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              tag,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: sel ? Colors.white : SC.ink,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(
                          color: SC.burgundy, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),

        // ── Finish setup — pinned to bottom ─────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: SC.primaryButtonStyle(),
              child: Text('Finish setup'),
            ),
          ),
        ),
      ],
    );
  }
}
