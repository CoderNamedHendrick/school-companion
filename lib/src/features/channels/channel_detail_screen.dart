import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaisel/kaisel.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class ChannelDetailScreen extends ConsumerWidget {
  const ChannelDetailScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelAsync = ref.watch(channelProvider(channelId));
    final messagesAsync = ref.watch(channelMessagesProvider(channelId));

    return AsyncContent(
      value: channelAsync,
      data: (channel) {
        if (channel == null) {
          return const AdaptivePage(
            title: 'Channel not found',
            subtitle: 'This channel is no longer available.',
            actions: [],
            child: EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Missing channel',
              message: 'Return to Channels and choose another channel.',
            ),
          );
        }

        return AdaptivePage(
          title: channel.title,
          subtitle: channel.summary,
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.router<ChannelsBranchRoute>().pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () => switchToBranch(context, SchoolBranch.meetings),
              icon: const Icon(Icons.video_camera_front_outlined),
              label: const Text('Meet'),
            ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final chat = _ChannelChat(channel: channel, channelId: channelId, messagesAsync: messagesAsync);
              final side = _ChannelSidePanel(channel: channel);
              if (!wide) {
                return Column(children: [chat, const SizedBox(height: 14), side]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chat),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: side),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ChannelChat extends ConsumerStatefulWidget {
  const _ChannelChat({required this.channel, required this.channelId, required this.messagesAsync});

  final LearningChannel channel;
  final String channelId;
  final AsyncValue<List<ChatMessage>> messagesAsync;

  @override
  ConsumerState<_ChannelChat> createState() => _ChannelChatState();
}

class _ChannelChatState extends ConsumerState<_ChannelChat> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live discussion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            AsyncContent(
              value: widget.messagesAsync,
              data: (messages) {
                if (messages.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message: 'Start the conversation with your channel.',
                  );
                }
                return Column(
                  children: [
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: message.isLecturer
                                  ? MivaColors.navy
                                  : widget.channel.color.withValues(alpha: 0.18),
                              foregroundColor: message.isLecturer ? Colors.white : MivaColors.navy,
                              child: Text(message.sender.characters.first),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(message.sender, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(message.time, style: const TextStyle(color: MivaColors.blue)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(message.body),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    decoration: const InputDecoration(hintText: 'Write a message or question'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending || user == null ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    final user = ref.read(currentUserProvider).asData?.value;
    if (body.isEmpty || user == null) return;
    setState(() => _sending = true);
    await ref
        .read(schoolRepositoryProvider)
        .sendChannelMessage(
          channelId: widget.channelId,
          senderId: user.id,
          sender: user.name,
          body: body,
          isLecturer: user.role == UserRole.lecturer,
        );
    _message.clear();
    if (mounted) setState(() => _sending = false);
  }
}

class _ChannelSidePanel extends ConsumerWidget {
  const _ChannelSidePanel({required this.channel});

  final LearningChannel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(channelAnnouncementsProvider(channel.id));
    final user = ref.watch(currentUserProvider).asData?.value;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pinned announcement',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                AsyncContent(
                  value: announcementsAsync,
                  data: (announcements) {
                    final pinned = announcements.where((announcement) => announcement.pinned).toList();
                    final visible = pinned.isEmpty ? announcements : pinned;
                    if (visible.isEmpty) {
                      return const Text('No announcements have been published.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final announcement in visible.take(2)) ...[
                          Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(announcement.body),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: user?.role != UserRole.lecturer
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _AnnouncementDialog(channelId: channel.id, authorId: user!.id, author: user.name),
                        ),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Publish'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Channel tools',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('Resources'),
                  onTap: () => switchToBranch(context, SchoolBranch.resources),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.view_kanban_outlined),
                  title: const Text('Project board'),
                  onTap: () => switchToBranch(context, SchoolBranch.projects),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.poll_outlined),
                  title: const Text('Polls and forums'),
                  onTap: () => switchToBranch(context, SchoolBranch.community),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementDialog extends ConsumerStatefulWidget {
  const _AnnouncementDialog({required this.channelId, required this.authorId, required this.author});

  final String channelId;
  final String authorId;
  final String author;

  @override
  ConsumerState<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends ConsumerState<_AnnouncementDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pinned = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Publish announcement'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              decoration: const InputDecoration(labelText: 'Memo or update'),
              minLines: 3,
              maxLines: 5,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pinned,
              onChanged: (value) => setState(() => _pinned = value),
              title: const Text('Pin to channel'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _publish, child: Text(_saving ? 'Publishing...' : 'Publish')),
      ],
    );
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .publishAnnouncement(
          channelId: widget.channelId,
          authorId: widget.authorId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          author: widget.author,
          pinned: _pinned,
        );
    if (mounted) Navigator.of(context).pop();
  }
}
