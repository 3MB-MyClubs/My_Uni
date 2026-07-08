import 'package:flutter/widgets.dart';

/// An [IndexedStack] whose children are only built on their first visit.
///
/// A plain IndexedStack instantiates every tab at once — at login that means
/// every screen's initState loads and first build run together, and their
/// repeat()ing animations keep ticking while hidden. Here a tab stays a
/// [SizedBox.shrink] until it is first selected, then remains mounted forever
/// (state — scroll positions, controllers, text fields — is preserved exactly
/// like before after that first visit).
///
/// Children must be stable instances across parent rebuilds (like
/// MainNavScreen's `late final _screens`), so the element-identity fast path
/// keeps skipping off-screen rebuilds. [TickerMode] additionally mutes
/// animation tickers in hidden tabs, letting the frame pipeline go idle.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _built = List<bool>.filled(
    widget.children.length,
    false,
  );

  @override
  Widget build(BuildContext context) {
    _built[widget.index] = true;
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _built[i] ? widget.children[i] : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
