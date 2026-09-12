import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/focused_read_service.dart';
import '../services/account_switcher_service.dart';
import '../services/paged_controller.dart';
import '../services/supabase_content_service.dart';

/// Adds paging to an existing list without replacing its cards or interactions.
class RemoteContentPane extends StatefulWidget {
  const RemoteContentPane({
    super.key,
    required this.kind,
    this.clubId,
    this.from,
    this.until,
    this.descending = false,
    required this.builder,
  });
  final String kind;
  final String? clubId;
  final DateTime? from;
  final DateTime? until;
  final bool descending;
  final Widget Function(BuildContext, Set<String>?) builder;

  @override
  State<RemoteContentPane> createState() => _RemoteContentPaneState();
}

class _RemoteContentPaneState extends State<RemoteContentPane> {
  final _pages = PagedController<Map<String, dynamic>>(
    idOf: (row) => row['id'].toString(),
  );
  int _appliedRevision = -1;

  Map<String, dynamic> get _params => {
    'p_kind': widget.kind,
    'p_club_id': widget.clubId,
    'p_limit': 25,
    'p_from': widget.from?.toUtc().toIso8601String(),
    'p_until': widget.until?.toUtc().toIso8601String(),
    'p_descending': widget.descending,
  };

  @override
  void initState() {
    super.initState();
    _pages.addListener(_changed);
    accountSwitcherService.addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  void _accountChanged() {
    _pages.reset();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RemoteContentPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.clubId != widget.clubId ||
        oldWidget.from != widget.from ||
        oldWidget.until != widget.until ||
        oldWidget.descending != widget.descending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!focusedReadService.available) return;
    final params = _params;
    await _pages.load(
      (cursor) => focusedReadService.page(
        'get_content_page_v1',
        params,
        cursor: cursor,
        force: force,
      ),
      cached: focusedReadService.cached('get_content_page_v1', params),
      preserveItems: force,
    );
  }

  void _changed() {
    if (!mounted) return;
    if (_pages.revision != _appliedRevision) {
      _appliedRevision = _pages.revision;
      if (widget.kind == 'posts') {
        supabaseContentService.mergePostRows(_pages.changedItems);
      } else {
        supabaseContentService.mergeEventRows(_pages.changedItems);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    accountSwitcherService.removeListener(_accountChanged);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!focusedReadService.available) return widget.builder(context, null);
    return Column(
      children: [
        if (_pages.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical &&
                  notification.metrics.extentAfter < 350) {
                unawaited(_pages.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: widget.builder(
                context,
                _pages.items.map((row) => row['id'].toString()).toSet(),
              ),
            ),
          ),
        ),
        if (_pages.error != null)
          TextButton(
            onPressed: () => unawaited(_pages.retry()),
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        if (_pages.hasMore && !_pages.loading)
          IconButton(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onPressed: () => unawaited(_pages.loadMore()),
            icon: const Icon(Icons.expand_more),
          ),
      ],
    );
  }
}
