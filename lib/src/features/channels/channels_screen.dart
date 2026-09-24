import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaisel/kaisel.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);

    return AdaptivePage(
      title: 'Channels',
      subtitle: 'Course, project, and student-only collaboration spaces.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _JoinChannelDialog()),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Join'),
        ),
        FilledButton.icon(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _CreateChannelDialog()),
          icon: const Icon(Icons.add),
          label: const Text('Create channel'),
        ),
      ],
      child: AsyncContent(
        value: channelsAsync,
        data: (channels) {
          if (channels.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No channels yet',
              message: 'Create a channel or join one with an invite code.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 640
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 1.85 : 1.35,
                ),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.router<ChannelsBranchRoute>().push(ChannelDetailBranchRoute(channel.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: channel.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_iconFor(channel.kind), color: channel.color),
                                ),
                                const Spacer(),
                                Badge(label: Text('${channel.unread}')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              channel.code,
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(color: channel.color, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              channel.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Expanded(child: Text(channel.summary, maxLines: 3, overflow: TextOverflow.ellipsis)),
                            Text('${channel.members} members'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(ChannelKind kind) {
    return switch (kind) {
      ChannelKind.course => Icons.menu_book_outlined,
      ChannelKind.project => Icons.account_tree_outlined,
      ChannelKind.studentOnly => Icons.groups_2_outlined,
    };
  }
}

class _JoinChannelDialog extends ConsumerStatefulWidget {
  const _JoinChannelDialog();

  @override
  ConsumerState<_JoinChannelDialog> createState() => _JoinChannelDialogState();
}

class _JoinChannelDialogState extends ConsumerState<_JoinChannelDialog> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a channel'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Channel code'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: MivaColors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _joining ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _joining ? null : _join, child: Text(_joining ? 'Joining...' : 'Join')),
      ],
    );
  }

  Future<void> _join() async {
    final user = ref.read(currentUserProvider).asData?.value;
    final code = _code.text.trim();
    if (user == null || code.isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final title = await ref.read(schoolRepositoryProvider).joinChannel(code: code, userId: user.id, role: user.role);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined $title.')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = '$error';
        });
      }
    }
  }
}

class _CreateChannelDialog extends ConsumerStatefulWidget {
  const _CreateChannelDialog();

  @override
  ConsumerState<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends ConsumerState<_CreateChannelDialog> {
  final _title = TextEditingController();
  final _code = TextEditingController();
  final _summary = TextEditingController();
  ChannelKind _kind = ChannelKind.course;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).asData?.value;
    if (user?.role == UserRole.student) {
      _kind = ChannelKind.studentOnly;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    return AlertDialog(
      title: const Text('Create channel'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Channel title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Course or team code'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summary,
              decoration: const InputDecoration(labelText: 'Summary'),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            SegmentedButton<ChannelKind>(
              segments: [
                ButtonSegment(
                  value: ChannelKind.course,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Course'),
                  enabled: user?.role == UserRole.lecturer,
                ),
                ButtonSegment(
                  value: ChannelKind.project,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Project'),
                ),
                ButtonSegment(
                  value: ChannelKind.studentOnly,
                  icon: Icon(Icons.groups_2_outlined),
                  label: Text('Student'),
                  enabled: user?.role == UserRole.student,
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() {
                _kind = value.single;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: MivaColors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || user == null ? null : _create,
          child: Text(_saving ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty || _code.text.trim().isEmpty) return;
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(schoolRepositoryProvider)
          .createChannel(
            title: _title.text.trim(),
            kind: _kind,
            code: _code.text.trim(),
            summary: _summary.text.trim(),
            ownerId: user.id,
            ownerRole: user.role,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }
}
