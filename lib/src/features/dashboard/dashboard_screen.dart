import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);
    final meetingsAsync = ref.watch(meetingsProvider);
    final resourcesAsync = ref.watch(resourcesProvider);
    final tasksAsync = ref.watch(projectTasksProvider);
    final directMessagesAsync = ref.watch(directMessagesProvider);
    final channels = switch (channelsAsync) {
      AsyncData(:final value) => value,
      _ => const <LearningChannel>[],
    };
    final meetings = switch (meetingsAsync) {
      AsyncData(:final value) => value,
      _ => const <ScheduledMeeting>[],
    };
    final resources = switch (resourcesAsync) {
      AsyncData(:final value) => value,
      _ => const <LearningResource>[],
    };
    final tasks = switch (tasksAsync) {
      AsyncData(:final value) => value,
      _ => const <ProjectTask>[],
    };
    final unread = channels.fold<int>(0, (total, channel) => total + channel.unread);
    final transcriptCount = resources.where((item) => item.hasTranscript).length;

    return AdaptivePage(
      title: 'Today in your learning spaces',
      subtitle: 'A unified view of messages, meetings, resources, and project work.',
      actions: [
        FilledButton.icon(
          onPressed: () => switchToBranch(context, SchoolBranch.meetings),
          icon: const Icon(Icons.event_available),
          label: const Text('Schedule'),
        ),
        OutlinedButton.icon(
          onPressed: () => switchToBranch(context, SchoolBranch.channels),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Open channels'),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 920
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.1 : 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricTile(
                    label: 'Unread channel messages',
                    value: channelsAsync.isLoading ? '-' : '$unread',
                    icon: Icons.mark_chat_unread_outlined,
                    color: MivaColors.navy,
                  ),
                  MetricTile(
                    label: 'Upcoming meetings',
                    value: meetingsAsync.isLoading ? '-' : '${meetings.length}',
                    icon: Icons.video_camera_front_outlined,
                    color: MivaColors.gold,
                  ),
                  MetricTile(
                    label: 'Resources with transcripts',
                    value: resourcesAsync.isLoading ? '-' : '$transcriptCount',
                    icon: Icons.transcribe_outlined,
                    color: MivaColors.blue,
                  ),
                  MetricTile(
                    label: 'Project tasks active',
                    value: tasksAsync.isLoading ? '-' : '${tasks.length}',
                    icon: Icons.view_kanban_outlined,
                    color: MivaColors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _DirectMessagesSection(messagesAsync: directMessagesAsync),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 860;
              return Flex(
                direction: twoColumns ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: twoColumns ? 3 : 0,
                    child: _Section(
                      title: 'Priority channels',
                      child: AsyncContent(
                        value: channelsAsync,
                        data: (channels) {
                          if (channels.isEmpty) {
                            return const EmptyState(
                              icon: Icons.forum_outlined,
                              title: 'No channels yet',
                              message: 'Create or join a channel to start collaborating.',
                            );
                          }
                          return Column(
                            children: [
                              for (final channel in channels.take(4))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(backgroundColor: channel.color),
                                  title: Text(channel.title),
                                  subtitle: Text(channel.summary),
                                  trailing: Badge(label: Text('${channel.unread}')),
                                  onTap: () => switchToBranch(context, SchoolBranch.channels),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: twoColumns ? 16 : 0, height: twoColumns ? 0 : 16),
                  Expanded(
                    flex: twoColumns ? 2 : 0,
                    child: _Section(
                      title: 'Next meetings',
                      child: AsyncContent(
                        value: meetingsAsync,
                        data: (meetings) {
                          if (meetings.isEmpty) {
                            return const EmptyState(
                              icon: Icons.video_camera_front_outlined,
                              title: 'No meetings scheduled',
                              message: 'Your upcoming meetings will appear here.',
                            );
                          }
                          return Column(
                            children: [
                              for (final meeting in meetings.take(3))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.event_note_outlined),
                                  title: Text(meeting.title),
                                  subtitle: Text('${meeting.channel} • ${meeting.time}'),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DirectMessagesSection extends ConsumerWidget {
  const _DirectMessagesSection({required this.messagesAsync});

  final AsyncValue<List<DirectMessage>> messagesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    return _Section(
      title: 'Direct messages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsyncContent(
            value: messagesAsync,
            data: (messages) {
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'No direct messages',
                  message: 'Your direct conversations will appear here.',
                );
              }
              return Column(
                children: [
                  for (final message in messages.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline),
                      title: Text(message.sender),
                      subtitle: Text(message.body),
                      trailing: Text(message.time),
                    ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: user == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => _DirectMessageDialog(user: user),
                    ),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send direct message'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectMessageDialog extends ConsumerStatefulWidget {
  const _DirectMessageDialog({required this.user});

  final SchoolUser user;

  @override
  ConsumerState<_DirectMessageDialog> createState() => _DirectMessageDialogState();
}

class _DirectMessageDialogState extends ConsumerState<_DirectMessageDialog> {
  final _receiverId = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _receiverId.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send direct message'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _receiverId,
              decoration: const InputDecoration(labelText: 'Receiver user id'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              decoration: const InputDecoration(labelText: 'Message'),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _sending ? null : _send, child: Text(_sending ? 'Sending...' : 'Send')),
      ],
    );
  }

  Future<void> _send() async {
    if (_receiverId.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await ref
        .read(schoolRepositoryProvider)
        .sendDirectMessage(
          senderId: widget.user.id,
          receiverId: _receiverId.text.trim(),
          sender: widget.user.name,
          body: _body.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
