import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(projectTasksProvider);
    final stages = ['To do', 'In progress', 'Review', 'Done'];

    return AdaptivePage(
      title: 'Project board',
      subtitle: 'Kanban coordination for supervised academic projects.',
      actions: [
        FilledButton.icon(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _TaskDialog()),
          icon: const Icon(Icons.add_task),
          label: const Text('Add task'),
        ),
      ],
      child: AsyncContent(
        value: tasksAsync,
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.view_kanban_outlined,
              title: 'No project tasks yet',
              message: 'Create a task to organize your project work.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (!wide) {
                return Column(
                  children: [
                    for (final stage in stages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TaskStage(stage: stage, tasks: tasks),
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final stage in stages) ...[
                    Expanded(
                      child: _TaskStage(stage: stage, tasks: tasks),
                    ),
                    if (stage != stages.last) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskStage extends ConsumerWidget {
  const _TaskStage({required this.stage, required this.tasks});

  final String stage;
  final List<ProjectTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageTasks = tasks.where((task) => task.stage == stage).toList();

    void showComments(ProjectTask task) {
      showDialog<void>(
        context: context,
        builder: (_) => _TaskCommentDialog(task: task),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stage,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                CircleAvatar(
                  radius: 13,
                  backgroundColor: MivaColors.gold.withValues(alpha: 0.24),
                  foregroundColor: MivaColors.navy,
                  child: Text('${stageTasks.length}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final task in stageTasks)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MivaColors.cloud,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MivaColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(avatar: const Icon(Icons.person_outline, size: 16), label: Text(task.owner)),
                        ActionChip(
                          avatar: const Icon(Icons.comment_outlined, size: 16),
                          label: Text('${task.comments} comments'),
                          tooltip: 'View comments',
                          onPressed: () => showComments(task),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showComments(task),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Comments'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: task.stage,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Stage'),
                          items: const [
                            DropdownMenuItem(value: 'To do', child: Text('To do')),
                            DropdownMenuItem(value: 'In progress', child: Text('In progress')),
                            DropdownMenuItem(value: 'Review', child: Text('Review')),
                            DropdownMenuItem(value: 'Done', child: Text('Done')),
                          ],
                          onChanged: (value) {
                            if (value == null || value == task.stage) return;
                            ref.read(schoolRepositoryProvider).moveProjectTask(taskId: task.id, stage: value);
                          },
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

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog();

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _channelId = TextEditingController();
  String _stage = 'To do';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _channelId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add project task'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _owner,
              decoration: const InputDecoration(labelText: 'Owner'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _channelId,
              decoration: const InputDecoration(labelText: 'Project channel id'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _stage,
              decoration: const InputDecoration(labelText: 'Stage'),
              items: const [
                DropdownMenuItem(value: 'To do', child: Text('To do')),
                DropdownMenuItem(value: 'In progress', child: Text('In progress')),
                DropdownMenuItem(value: 'Review', child: Text('Review')),
                DropdownMenuItem(value: 'Done', child: Text('Done')),
              ],
              onChanged: (value) => setState(() {
                _stage = value ?? 'To do';
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Adding...' : 'Add task')),
      ],
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider).asData?.value;
    if (_title.text.trim().isEmpty || _owner.text.trim().isEmpty || _channelId.text.trim().isEmpty || user == null) {
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .addProjectTask(
          title: _title.text.trim(),
          owner: _owner.text.trim(),
          stage: _stage,
          channelId: _channelId.text.trim(),
          creatorId: user.id,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

class _TaskCommentDialog extends ConsumerStatefulWidget {
  const _TaskCommentDialog({required this.task});

  final ProjectTask task;

  @override
  ConsumerState<_TaskCommentDialog> createState() => _TaskCommentDialogState();
}

class _TaskCommentDialogState extends ConsumerState<_TaskCommentDialog> {
  final _body = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final commentsAsync = ref.watch(taskCommentsProvider(widget.task.id));
    return AlertDialog(
      title: Text('Comments on ${widget.task.title}'),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Could not load comments: $error')),
                data: (comments) {
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('No comments yet. Start the conversation below.', textAlign: TextAlign.center),
                    );
                  }
                  return ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(comment.author, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(comment.body),
                          trailing: Text(comment.created, style: Theme.of(context).textTheme.bodySmall),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 24),
            TextField(
              controller: _body,
              enabled: !_saving,
              decoration: InputDecoration(labelText: 'Add a comment', errorText: _error),
              minLines: 2,
              maxLines: 4,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving || user == null ? null : _save,
                icon: const Icon(Icons.send_outlined),
                label: Text(_saving ? 'Posting...' : 'Post comment'),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider).asData?.value;
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Enter a comment.');
      return;
    }
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(schoolRepositoryProvider)
          .addTaskComment(taskId: widget.task.id, author: user.name, body: body, authorId: user.id);
      _body.clear();
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not post the comment. Try again.';
        });
      }
    }
  }
}
