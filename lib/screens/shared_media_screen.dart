import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_media_selection.dart';
import '../models/chat_message.dart';
import '../services/app_strings.dart';
import '../services/chat_store.dart';
import '../services/image_cache_service.dart';
import '../services/media_delivery_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';

/// `shared-media` — Figma `105:189` / `105:227`.
///
/// Everything on this screen is derived from the messages already in
/// [chatStore] for the thread: photo attachments for Media, `http(s)` runs
/// inside message bodies for Links, non-video file attachments for Docs. There
/// is no media index to query, and building one would be backend work.
class SharedMediaScreen extends StatefulWidget {
  final String threadId;
  final String myId;

  const SharedMediaScreen({
    super.key,
    required this.threadId,
    required this.myId,
  });

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

enum _MediaTab { media, links, docs }

class _SharedMediaScreenState extends State<SharedMediaScreen> {
  _MediaTab _tab = _MediaTab.media;

  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  List<ChatMessage> get _messages =>
      chatStore.messagesFor(widget.threadId, viewerId: widget.myId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: ListenableBuilder(
        listenable: chatStore,
        builder: (context, _) => SafeArea(
          bottom: false,
          top: false,
          child: Column(
            children: [
              ChatsTopBar(title: S.chatsSharedMedia),
              _buildTabBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  /// `tab-bar` 105:206 — pills, the active one filled with the accent.
  ///
  /// Scrollable: the three Turkish labels are together wider than a phone, and
  /// the frame's 402pt row has no answer for that.
  Widget _buildTabBar() {
    return SizedBox(
      height: 49,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 16),
          for (final tab in _MediaTab.values) ...[
            GestureDetector(
              key: ValueKey('shared-media-tab-${tab.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = tab),
              child: Container(
                height: 33,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == tab ? ChatsColors.accent : ChatsColors.fill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  switch (tab) {
                    _MediaTab.media => S.chatsMediaTab,
                    _MediaTab.links => S.chatsLinksTab,
                    _MediaTab.docs => S.chatsDocsTab,
                  },
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _tab == tab
                        ? ChatsColors.onAccent
                        : ChatsColors.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _MediaTab.media:
        final photos = _messages
            .where(
              (m) =>
                  m.kind == ChatMessageKind.photo &&
                  (m.attachmentPath ?? '').isNotEmpty,
            )
            .toList()
            .reversed
            .toList();
        if (photos.isEmpty) return _empty(S.chatsNoSharedMedia);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // `105:215` — 115 wide by 110 tall.
            childAspectRatio: 115 / 110,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) => SharedMediaTile(
            key: ValueKey('shared-media-photo-${photos[index].id}'),
            path: photos[index].attachmentPath!,
          ),
        );
      case _MediaTab.links:
        final links = <(String, ChatMessage)>[];
        for (final m in _messages.reversed) {
          for (final match in _urlPattern.allMatches(m.content)) {
            links.add((match.group(0)!, m));
          }
        }
        if (links.isEmpty) return _empty(S.chatsNoSharedLinks);
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: links.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _AttachmentRow(
            rowKey: ValueKey('shared-media-link-$index'),
            icon: Icons.link_rounded,
            title: links[index].$1,
            subtitle: links[index].$2.content.trim(),
          ),
        );
      case _MediaTab.docs:
        final docs = _messages
            .where((m) {
              if (m.kind != ChatMessageKind.file) return false;
              final path = m.attachmentPath ?? '';
              if (path.isEmpty) return false;
              return !isVideoMediaPath(m.attachmentName ?? path);
            })
            .toList()
            .reversed
            .toList();
        if (docs.isEmpty) return _empty(S.chatsNoSharedDocs);
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _AttachmentRow(
              rowKey: ValueKey('shared-media-doc-${doc.id}'),
              icon: Icons.description_outlined,
              title: doc.attachmentName ?? doc.attachmentPath!.split('/').last,
              subtitle: doc.content.trim(),
            );
          },
        );
    }
  }

  Widget _empty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: figtree(
            size: 13,
            weight: FontWeight.w400,
            color: ChatsColors.muted,
          ),
        ),
      ),
    );
  }
}

/// One media tile. Mirrors the three attachment shapes the thread
/// understands: a private `chat-attachment://` reference, a signed remote URL,
/// or a file on this device. Also used by `group-info`'s four-up strip.
class SharedMediaTile extends StatelessWidget {
  final String path;

  const SharedMediaTile({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final isPrivateReference = path.startsWith('chat-attachment://');
    final isRemote =
        isPrivateReference ||
        path.startsWith('http://') ||
        path.startsWith('https://');
    final file = isRemote ? null : File(path);
    final placeholder = ColoredBox(color: ChatsColors.fill);
    return ClipRRect(
      borderRadius: BorderRadius.circular(kChatCardRadius),
      child: SizedBox.expand(
        child: isPrivateReference
            ? PrivateMediaNetworkImage(
                reference: path,
                rendition: MediaRendition.thumbnail,
                cacheWidth: 240,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => placeholder,
                errorBuilder: (_) => placeholder,
              )
            : isRemote
            ? AppNetworkImage(
                url: path,
                cacheKey: stableSupabaseSignedUrlCacheKey(path) ?? path,
                cacheWidth: 240,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => placeholder,
                errorBuilder: (_) => placeholder,
              )
            : file!.existsSync()
            ? Image(
                image: ResizeImage(
                  FileImage(file),
                  width: (240 * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final Key rowKey;
  final IconData icon;
  final String title;
  final String subtitle;

  const _AttachmentRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ChatsCard(
      key: rowKey,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ChatsColors.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: ChatsColors.accentText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w600,
                    color: ChatsColors.text,
                  ),
                ),
                if (subtitle.isNotEmpty && subtitle != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w400,
                      color: ChatsColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
