import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/chat_v2.dart';
import 'chat_v2_service.dart';

class ChatHistoryStateV2 {
  const ChatHistoryStateV2({
    this.messages = const [],
    this.revision = 0,
    this.nextCursor,
    this.syncCursor = 0,
    this.hasMore = true,
    this.hasLoadedInitial = false,
    this.isInitialLoading = false,
    this.isOlderLoading = false,
    this.isReconciling = false,
    this.initialError,
    this.olderError,
    this.reconcileError,
  });

  final List<ChatMessage> messages;
  final int revision;
  final ChatHistoryCursorV2? nextCursor;
  final int syncCursor;
  final bool hasMore;
  final bool hasLoadedInitial;
  final bool isInitialLoading;
  final bool isOlderLoading;
  final bool isReconciling;
  final Object? initialError;
  final Object? olderError;
  final Object? reconcileError;

  ChatHistoryStateV2 copyWith({
    List<ChatMessage>? messages,
    ChatHistoryCursorV2? nextCursor,
    bool clearNextCursor = false,
    int? syncCursor,
    bool? hasMore,
    bool? hasLoadedInitial,
    bool? isInitialLoading,
    bool? isOlderLoading,
    bool? isReconciling,
    Object? initialError,
    bool clearInitialError = false,
    Object? olderError,
    bool clearOlderError = false,
    Object? reconcileError,
    bool clearReconcileError = false,
  }) => ChatHistoryStateV2(
    messages: messages ?? this.messages,
    revision: messages != null && !identical(messages, this.messages)
        ? revision + 1
        : revision,
    nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
    syncCursor: syncCursor ?? this.syncCursor,
    hasMore: hasMore ?? this.hasMore,
    hasLoadedInitial: hasLoadedInitial ?? this.hasLoadedInitial,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isOlderLoading: isOlderLoading ?? this.isOlderLoading,
    isReconciling: isReconciling ?? this.isReconciling,
    initialError: clearInitialError ? null : initialError ?? this.initialError,
    olderError: clearOlderError ? null : olderError ?? this.olderError,
    reconcileError: clearReconcileError
        ? null
        : reconcileError ?? this.reconcileError,
  );
}

class ChatV2Controller extends ChangeNotifier {
  ChatV2Controller({
    required ChatV2Source source,
    this.messagePageSize = 40,
    this.summaryPageSize = 40,
  }) : _source = source;

  final ChatV2Source _source;
  final int messagePageSize;
  final int summaryPageSize;

  List<ChatConversationSummaryV2> _summaries = const [];
  ChatSummaryCursorV2? _summaryCursor;
  bool _summaryHasMore = true;
  bool _summariesLoaded = false;
  bool _summariesLoading = false;
  Object? _summaryError;
  final Map<String, ChatHistoryStateV2> _histories = {};
  final Map<String, Future<void>> _initialTasks = {};
  final Map<String, Future<void>> _olderTasks = {};
  final Map<String, Future<void>> _reconcileTasks = {};
  Future<void>? _summaryTask;
  int _generation = 0;
  int summaryRevision = 0;
  List<ChatConversationSummaryV2>? _lastNotifiedSummaries;

  @override
  void notifyListeners() {
    if (!identical(_lastNotifiedSummaries, _summaries)) {
      summaryRevision++;
      _lastNotifiedSummaries = _summaries;
    }
    super.notifyListeners();
  }

  List<ChatConversationSummaryV2> get summaries => _summaries;
  bool get summariesLoaded => _summariesLoaded;
  bool get summariesLoading => _summariesLoading;
  bool get summaryHasMore => _summaryHasMore;
  Object? get summaryError => _summaryError;
  Iterable<String> get loadedThreadIds => _histories.entries
      .where((entry) => entry.value.hasLoadedInitial)
      .map((entry) => entry.key);

  ChatConversationSummaryV2? summaryFor(String threadId) {
    for (final summary in _summaries) {
      if (summary.threadId == threadId) return summary;
    }
    return null;
  }

  ChatHistoryStateV2 historyFor(String threadId) =>
      _histories[threadId] ?? const ChatHistoryStateV2();

  Future<void> loadFirstSummaries({bool force = false}) {
    final active = _summaryTask;
    if (active != null) return active;
    if (_summariesLoaded && !force) return Future.value();
    final generation = _generation;
    late final Future<void> task;
    task = _loadFirstSummaries(generation, force).whenComplete(() {
      if (identical(_summaryTask, task)) _summaryTask = null;
    });
    _summaryTask = task;
    return task;
  }

  Future<void> _loadFirstSummaries(int generation, bool force) async {
    _summariesLoading = true;
    _summaryError = null;
    notifyListeners();
    try {
      final page = await _source.fetchSummaries(
        limit: summaryPageSize,
        force: force,
      );
      if (generation != _generation) return;
      _summaries = _dedupeAndSortSummaries(page.items);
      _summaryCursor = page.nextCursor;
      _summaryHasMore = page.hasMore && page.nextCursor != null;
      _summariesLoaded = true;
      for (final summary in page.items) {
        final current = _histories[summary.threadId];
        if (current == null || !current.hasLoadedInitial) {
          _histories[summary.threadId] = (current ?? const ChatHistoryStateV2())
              .copyWith(syncCursor: summary.syncCursor);
        }
      }
    } catch (error) {
      if (generation == _generation) _summaryError = error;
    } finally {
      if (generation == _generation) {
        _summariesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSummaries() async {
    if (_summaryTask != null || !_summaryHasMore || _summaryCursor == null) {
      return;
    }
    final generation = _generation;
    final cursor = _summaryCursor;
    late final Future<void> task;
    task =
        (() async {
          _summariesLoading = true;
          _summaryError = null;
          notifyListeners();
          try {
            final page = await _source.fetchSummaries(
              cursor: cursor,
              limit: summaryPageSize,
              force: true,
            );
            if (generation != _generation) return;
            _summaries = _dedupeAndSortSummaries([
              ..._summaries,
              ...page.items,
            ]);
            _summaryCursor = page.nextCursor;
            _summaryHasMore = page.hasMore && page.nextCursor != null;
          } catch (error) {
            if (generation == _generation) _summaryError = error;
          } finally {
            if (generation == _generation) {
              _summariesLoading = false;
              notifyListeners();
            }
          }
        })().whenComplete(() {
          if (identical(_summaryTask, task)) _summaryTask = null;
        });
    _summaryTask = task;
    return task;
  }

  Future<void> loadInitialMessages(String threadId, {bool force = false}) {
    final active = _initialTasks[threadId];
    if (active != null) return active;
    final current = historyFor(threadId);
    if (current.hasLoadedInitial && !force) return Future.value();
    final generation = _generation;
    late final Future<void> task;
    task = _loadInitialMessages(threadId, generation).whenComplete(() {
      if (identical(_initialTasks[threadId], task)) {
        _initialTasks.remove(threadId);
      }
    });
    _initialTasks[threadId] = task;
    return task;
  }

  Future<void> _loadInitialMessages(String threadId, int generation) async {
    _histories[threadId] = historyFor(
      threadId,
    ).copyWith(isInitialLoading: true, clearInitialError: true);
    notifyListeners();
    try {
      final page = await _source.fetchMessages(
        threadId: threadId,
        limit: messagePageSize,
      );
      if (generation != _generation) return;
      _histories[threadId] = historyFor(threadId).copyWith(
        messages: _mergeById(const [], page.items),
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        syncCursor: page.syncCursor,
        hasMore: page.hasMore && page.nextCursor != null,
        hasLoadedInitial: true,
        isInitialLoading: false,
        clearInitialError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      _histories[threadId] = historyFor(
        threadId,
      ).copyWith(isInitialLoading: false, initialError: error);
    }
    notifyListeners();
  }

  Future<void> loadOlderMessages(String threadId) {
    final active = _olderTasks[threadId];
    if (active != null) return active;
    final current = historyFor(threadId);
    if (!current.hasLoadedInitial ||
        current.isInitialLoading ||
        !current.hasMore ||
        current.nextCursor == null) {
      return Future.value();
    }
    final generation = _generation;
    final cursor = current.nextCursor!;
    late final Future<void> task;
    task = _loadOlderMessages(threadId, cursor, generation).whenComplete(() {
      if (identical(_olderTasks[threadId], task)) _olderTasks.remove(threadId);
    });
    _olderTasks[threadId] = task;
    return task;
  }

  Future<void> _loadOlderMessages(
    String threadId,
    ChatHistoryCursorV2 cursor,
    int generation,
  ) async {
    _histories[threadId] = historyFor(
      threadId,
    ).copyWith(isOlderLoading: true, clearOlderError: true);
    notifyListeners();
    try {
      final page = await _source.fetchMessages(
        threadId: threadId,
        cursor: cursor,
        limit: messagePageSize,
      );
      if (generation != _generation) return;
      _histories[threadId] = historyFor(threadId).copyWith(
        messages: _mergeById(historyFor(threadId).messages, page.items),
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        syncCursor: page.syncCursor > historyFor(threadId).syncCursor
            ? page.syncCursor
            : historyFor(threadId).syncCursor,
        hasMore: page.hasMore && page.nextCursor != null,
        isOlderLoading: false,
        clearOlderError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      _histories[threadId] = historyFor(
        threadId,
      ).copyWith(isOlderLoading: false, olderError: error);
    }
    notifyListeners();
  }

  Future<void> reconcile(String threadId) {
    final active = _reconcileTasks[threadId];
    if (active != null) return active;
    final current = historyFor(threadId);
    if (!current.hasLoadedInitial) return Future.value();
    final generation = _generation;
    late final Future<void> task;
    task = _reconcile(threadId, generation).whenComplete(() {
      if (identical(_reconcileTasks[threadId], task)) {
        _reconcileTasks.remove(threadId);
      }
    });
    _reconcileTasks[threadId] = task;
    return task;
  }

  Future<void> _reconcile(String threadId, int generation) async {
    _histories[threadId] = historyFor(
      threadId,
    ).copyWith(isReconciling: true, clearReconcileError: true);
    notifyListeners();
    try {
      var cursor = historyFor(threadId).syncCursor;
      var hasMore = true;
      while (hasMore && generation == _generation) {
        final page = await _source.fetchChanges(
          threadId: threadId,
          afterChangeId: cursor,
        );
        if (generation != _generation) return;
        if (page.cursorExpired) {
          // The journal retention window has elapsed. Rebase this loaded
          // thread on one bounded current page; never fall back to a full
          // history download.
          final currentPage = await _source.fetchMessages(
            threadId: threadId,
            limit: messagePageSize,
          );
          if (generation != _generation) return;
          _histories[threadId] = historyFor(threadId).copyWith(
            messages: _mergeById(const [], currentPage.items),
            nextCursor: currentPage.nextCursor,
            syncCursor: currentPage.syncCursor,
            hasMore: currentPage.hasMore,
            hasLoadedInitial: true,
            isReconciling: false,
            clearReconcileError: true,
          );
          notifyListeners();
          return;
        }
        for (final change in page.changes) {
          _applyChange(threadId, change, notify: false);
        }
        cursor = page.nextChangeId;
        hasMore = page.hasMore;
      }
      if (generation != _generation) return;
      _histories[threadId] = historyFor(threadId).copyWith(
        syncCursor: cursor,
        isReconciling: false,
        clearReconcileError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      _histories[threadId] = historyFor(
        threadId,
      ).copyWith(isReconciling: false, reconcileError: error);
    }
    notifyListeners();
  }

  void mergeRealtimeMessage(
    ChatMessage message, {
    required bool isOwn,
    bool incrementUnread = true,
  }) {
    final threadId = message.threadId;
    final current = historyFor(threadId);
    if (current.hasLoadedInitial) {
      _histories[threadId] = current.copyWith(
        messages: _mergeById(current.messages, [message]),
      );
    }
    final index = _summaries.indexWhere((item) => item.threadId == threadId);
    if (index != -1) {
      final summary = _summaries[index];
      final incrementsBoard =
          summary.threadType == 'club' &&
          message.kind == ChatMessageKind.announcement;
      final incrementsChat =
          summary.threadType == 'club' &&
          message.kind != ChatMessageKind.announcement;
      final next = summary.copyWith(
        latestMessage: message,
        activityAt: message.createdAt,
        unreadCount: isOwn || !incrementUnread
            ? summary.unreadCount
            : summary.unreadCount + 1,
        unreadBoardCount: !isOwn && incrementUnread && incrementsBoard
            ? (summary.unreadBoardCount ?? 0) + 1
            : summary.unreadBoardCount,
        unreadChatCount: !isOwn && incrementUnread && incrementsChat
            ? (summary.unreadChatCount ?? 0) + 1
            : summary.unreadChatCount,
      );
      _summaries = [..._summaries]..[index] = next;
      _summaries = _dedupeAndSortSummaries(_summaries);
    }
    notifyListeners();
  }

  void removeRealtimeMessage(String threadId, String messageId) {
    final current = historyFor(threadId);
    if (!current.hasLoadedInitial) return;
    final messages = current.messages
        .where((message) => message.id != messageId)
        .toList(growable: false);
    if (messages.length == current.messages.length) return;
    _histories[threadId] = current.copyWith(messages: messages);
    notifyListeners();
  }

  void mergeOptimistic(ChatMessage message) {
    final current = historyFor(message.threadId);
    if (current.hasLoadedInitial) {
      _histories[message.threadId] = current.copyWith(
        messages: _mergeById(current.messages, [message]),
      );
    }
    notifyListeners();
  }

  void markSummaryRead(String threadId, {String scope = 'all'}) {
    final index = _summaries.indexWhere((item) => item.threadId == threadId);
    if (index == -1 || _summaries[index].unreadCount == 0) return;
    final summary = _summaries[index];
    final unreadBoard = scope == 'all' || scope == 'board'
        ? 0
        : summary.unreadBoardCount;
    final unreadChat = scope == 'all' || scope == 'chat'
        ? 0
        : summary.unreadChatCount;
    final unread = scope == 'all' ? 0 : (unreadBoard ?? 0) + (unreadChat ?? 0);
    _summaries = [..._summaries]
      ..[index] = summary.copyWith(
        unreadCount: unread,
        unreadBoardCount: unreadBoard,
        unreadChatCount: unreadChat,
      );
    notifyListeners();
  }

  void _applyChange(
    String threadId,
    ChatChangeV2 change, {
    required bool notify,
  }) {
    final current = historyFor(threadId);
    var messages = current.messages;
    if (change.recordType == 'message') {
      if (change.operation == 'DELETE') {
        messages = messages
            .where((message) => message.id != change.messageId)
            .toList(growable: false);
      } else {
        final message =
            change.message ?? ChatWireMessageV2(change.record).toChatMessage();
        if (message != null) messages = _mergeById(messages, [message]);
      }
    } else if (change.recordType == 'receipt') {
      messages = _applyReceipt(messages, change);
    } else if (change.recordType == 'poll_vote') {
      messages = _applyPollVote(messages, change);
    }
    _histories[threadId] = current.copyWith(
      messages: messages,
      syncCursor: change.changeId > current.syncCursor
          ? change.changeId
          : current.syncCursor,
    );
    if (notify) notifyListeners();
  }

  void applyRealtimeChange(String threadId, ChatChangeV2 change) =>
      _applyChange(threadId, change, notify: true);

  void reset() {
    _generation++;
    _summaries = const [];
    _summaryCursor = null;
    _summaryHasMore = true;
    _summariesLoaded = false;
    _summariesLoading = false;
    _summaryError = null;
    _histories.clear();
    _initialTasks.clear();
    _olderTasks.clear();
    _reconcileTasks.clear();
    _summaryTask = null;
    notifyListeners();
  }
}

List<ChatConversationSummaryV2> _dedupeAndSortSummaries(
  Iterable<ChatConversationSummaryV2> items,
) {
  final byId = <String, ChatConversationSummaryV2>{};
  for (final item in items) {
    byId[item.threadId] = item;
  }
  final result = byId.values.toList()
    ..sort((a, b) {
      final time = b.activityAt.compareTo(a.activityAt);
      return time != 0 ? time : b.threadId.compareTo(a.threadId);
    });
  return List.unmodifiable(result);
}

List<ChatMessage> _mergeById(
  Iterable<ChatMessage> existing,
  Iterable<ChatMessage> incoming,
) {
  final byId = <String, ChatMessage>{
    for (final message in existing) message.id: message,
  };
  for (final message in incoming) {
    byId[message.id] = message;
  }
  final result = byId.values.toList()
    ..sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
  return List.unmodifiable(result);
}

List<ChatMessage> _applyReceipt(
  List<ChatMessage> messages,
  ChatChangeV2 change,
) {
  final index = messages.indexWhere(
    (message) => message.id == change.messageId,
  );
  if (index == -1) return messages;
  final userId = change.record['user_id']?.toString() ?? '';
  if (userId.isEmpty) return messages;
  final receipts = [...messages[index].receipts]
    ..removeWhere((receipt) => receipt.userId == userId);
  if (change.operation != 'DELETE') {
    receipts.add(
      MessageReceipt(
        userId: userId,
        deliveredAt: DateTime.tryParse(
          change.record['delivered_at']?.toString() ?? '',
        )?.toLocal(),
        seenAt: DateTime.tryParse(
          change.record['seen_at']?.toString() ?? '',
        )?.toLocal(),
      ),
    );
  }
  final result = [...messages]
    ..[index] = messages[index].copyWith(receipts: receipts);
  return List.unmodifiable(result);
}

List<ChatMessage> _applyPollVote(
  List<ChatMessage> messages,
  ChatChangeV2 change,
) {
  final index = messages.indexWhere(
    (message) => message.id == change.messageId,
  );
  if (index == -1) return messages;
  final current = messages[index];
  final voterId = change.record['voter_auth_id']?.toString() ?? '';
  if (voterId.isNotEmpty) {
    // Legacy journal rows may still contain the identity. Keep this path for
    // old fixtures/clients; new v2 rows use aggregate counts below.
    final votes = Map<String, int>.from(current.pollVotes)..remove(voterId);
    if (change.operation != 'DELETE') {
      final option = change.record['option_index'];
      if (option is num) votes[voterId] = option.toInt();
    }
    final result = [...messages]..[index] = current.copyWith(pollVotes: votes);
    return List.unmodifiable(result);
  }

  final option = (change.record['option_index'] as num?)?.toInt();
  final previous = (change.record['previous_option_index'] as num?)?.toInt();
  final counts = [...current.pollVoteCounts];
  final requiredLength = [option, previous].whereType<int>().fold<int>(
    current.pollOptions.length,
    (max, value) => value + 1 > max ? value + 1 : max,
  );
  while (counts.length < requiredLength) {
    counts.add(0);
  }
  void decrement(int? value) {
    if (value != null &&
        value >= 0 &&
        value < counts.length &&
        counts[value] > 0) {
      counts[value]--;
    }
  }

  void increment(int? value) {
    if (value != null && value >= 0 && value < counts.length) counts[value]++;
  }

  decrement(previous);
  if (change.operation != 'DELETE') increment(option);
  final isViewer = change.record['is_viewer'] == true;
  final result = [...messages]
    ..[index] = current.copyWith(
      pollVoteCounts: counts,
      pollViewerOption: isViewer && change.operation != 'DELETE'
          ? option
          : current.pollViewerOption,
    );
  return List.unmodifiable(result);
}
