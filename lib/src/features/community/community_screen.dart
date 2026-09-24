import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);
    final pollsAsync = ref.watch(communityPollsProvider);
    final assessmentsAsync = ref.watch(assessmentsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;

    return AdaptivePage(
      title: 'Student community',
      subtitle: 'Forums, polls, peer resources, and moderated student-only spaces.',
      actions: [
        OutlinedButton.icon(
          onPressed: user?.role != UserRole.student
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => _PollDialog(author: user!.name, authorId: user.id),
                ),
          icon: const Icon(Icons.poll_outlined),
          label: const Text('Poll'),
        ),
        OutlinedButton.icon(
          onPressed: user?.role == UserRole.lecturer
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => _AssessmentDialog(authorId: user!.id),
                )
              : null,
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Quiz'),
        ),
        FilledButton.icon(
          onPressed: user?.role != UserRole.student
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => _PostDialog(author: user!.name, authorId: user.id),
                ),
          icon: const Icon(Icons.post_add),
          label: const Text('New post'),
        ),
      ],
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: MivaColors.navy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Student-only channels support moderation, polls, and peer resource sharing while keeping lecturer-controlled spaces separate.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PollsPanel(pollsAsync: pollsAsync),
          const SizedBox(height: 14),
          _AssessmentsPanel(assessmentsAsync: assessmentsAsync),
          const SizedBox(height: 14),
          AsyncContent(
            value: postsAsync,
            data: (posts) {
              if (posts.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No community posts yet',
                  message: 'Start a discussion or share a question with your community.',
                );
              }
              return Column(
                children: [
                  for (final post in posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => _ForumDialog(post: post),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: MivaColors.red.withValues(alpha: 0.12),
                            foregroundColor: MivaColors.red,
                            child: const Icon(Icons.forum_outlined),
                          ),
                          title: Text(post.title),
                          subtitle: Text('By ${post.author}'),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(label: Text(post.tag)),
                              if (post.moderationStatus != 'visible') Chip(label: Text(post.moderationStatus)),
                              Text('${post.replies} replies'),
                            ],
                          ),
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

class _ForumDialog extends ConsumerStatefulWidget {
  const _ForumDialog({required this.post});

  final CommunityPost post;

  @override
  ConsumerState<_ForumDialog> createState() => _ForumDialogState();
}

class _ForumDialogState extends ConsumerState<_ForumDialog> {
  final _reply = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final replies = ref.watch(communityRepliesProvider(widget.post.id));
    final user = ref.watch(currentUserProvider).asData?.value;
    return AlertDialog(
      title: Text(widget.post.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Started by ${widget.post.author} • ${widget.post.tag}'),
              const SizedBox(height: 14),
              AsyncContent(
                value: replies,
                data: (items) => items.isEmpty
                    ? const Text('No replies yet.')
                    : Column(
                        children: [
                          for (final item in items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.author),
                              subtitle: Text(item.body),
                              trailing: Text(item.created),
                            ),
                        ],
                      ),
              ),
              if (user?.role == UserRole.student) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reply,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Reply'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (user?.role == UserRole.lecturer)
          TextButton.icon(
            onPressed: () => ref
                .read(schoolRepositoryProvider)
                .moderateCommunityPost(
                  postId: widget.post.id,
                  moderationStatus: widget.post.moderationStatus == 'hidden' ? 'visible' : 'hidden',
                ),
            icon: const Icon(Icons.gavel_outlined),
            label: Text(widget.post.moderationStatus == 'hidden' ? 'Restore' : 'Hide'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        if (user?.role == UserRole.student)
          FilledButton(
            onPressed: _saving || _reply.text.trim().isEmpty ? null : _send,
            child: Text(_saving ? 'Sending...' : 'Reply'),
          ),
      ],
    );
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider).asData?.value;
    final body = _reply.text.trim();
    if (user == null || body.isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .addCommunityReply(postId: widget.post.id, authorId: user.id, author: user.name, body: body);
    _reply.clear();
    if (mounted) setState(() => _saving = false);
  }
}

class _PollsPanel extends ConsumerWidget {
  const _PollsPanel({required this.pollsAsync});

  final AsyncValue<List<CommunityPoll>> pollsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Polls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            AsyncContent(
              value: pollsAsync,
              data: (polls) {
                if (polls.isEmpty) {
                  return const Text('No polls have been created.');
                }
                return Column(
                  children: [
                    for (final poll in polls.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in poll.options.entries)
                                  ActionChip(
                                    label: Text('${option.key} (${option.value})'),
                                    onPressed: poll.open
                                        ? () async {
                                            try {
                                              await ref
                                                  .read(schoolRepositoryProvider)
                                                  .votePoll(pollId: poll.id, option: option.key);
                                            } catch (error) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(SnackBar(content: Text('$error')));
                                              }
                                            }
                                          }
                                        : null,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentsPanel extends StatelessWidget {
  const _AssessmentsPanel({required this.assessmentsAsync});

  final AsyncValue<List<Assessment>> assessmentsAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quizzes and exercises',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            AsyncContent(
              value: assessmentsAsync,
              data: (assessments) {
                if (assessments.isEmpty) {
                  return const Text('No quizzes or exercises yet.');
                }
                return Column(
                  children: [
                    for (final assessment in assessments.take(4))
                      ListTile(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(assessment.title),
                            content: SizedBox(
                              width: 500,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      assessment.instructions.isEmpty
                                          ? 'No instructions were supplied.'
                                          : assessment.instructions,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Lecturer solution', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      assessment.solution.isEmpty
                                          ? 'Solution has not been shared yet.'
                                          : assessment.solution,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          assessment.kind == AssessmentKind.quiz ? Icons.quiz_outlined : Icons.assignment_outlined,
                        ),
                        title: Text(assessment.title),
                        subtitle: Text('${assessment.channel} • ${assessment.questionCount} questions'),
                        trailing: Chip(label: Text(assessment.status)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDialog extends ConsumerStatefulWidget {
  const _PostDialog({required this.author, required this.authorId});

  final String author;
  final String authorId;

  @override
  ConsumerState<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends ConsumerState<_PostDialog> {
  final _title = TextEditingController();
  final _tag = TextEditingController(text: 'Discussion');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New forum post'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Topic'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tag,
              decoration: const InputDecoration(labelText: 'Tag'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Posting...' : 'Post')),
      ],
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .createCommunityPost(
          title: _title.text.trim(),
          author: widget.author,
          tag: _tag.text.trim(),
          authorId: widget.authorId,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

class _PollDialog extends ConsumerStatefulWidget {
  const _PollDialog({required this.author, required this.authorId});

  final String author;
  final String authorId;

  @override
  ConsumerState<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends ConsumerState<_PollDialog> {
  final _question = TextEditingController();
  final List<TextEditingController> _options = [TextEditingController(), TextEditingController()];
  bool _saving = false;
  String? _validationMessage;

  @override
  void dispose() {
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create poll'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _question,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Question'),
                onChanged: (_) => _clearValidationMessage(),
              ),
              for (var index = 0; index < _options.length; index++) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey(_options[index]),
                        controller: _options[index],
                        enabled: !_saving,
                        decoration: InputDecoration(labelText: 'Option ${index + 1}'),
                        onChanged: (_) => _clearValidationMessage(),
                      ),
                    ),
                    if (_options.length > 2) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Remove option ${index + 1}',
                        onPressed: _saving ? null : () => _removeOption(index),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ),
              if (_validationMessage != null)
                Text(_validationMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Creating...' : 'Create')),
      ],
    );
  }

  void _addOption() {
    setState(() {
      _options.add(TextEditingController());
      _validationMessage = null;
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final removed = _options.removeAt(index);
    removed.dispose();
    setState(() => _validationMessage = null);
  }

  void _clearValidationMessage() {
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
  }

  Future<void> _save() async {
    final options = _options
        .map((controller) => controller.text)
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    final normalizedOptions = options.map((option) => option.toLowerCase()).toSet();
    if (_question.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Enter a poll question.');
      return;
    }
    if (options.length < 2) {
      setState(() => _validationMessage = 'Enter at least two options.');
      return;
    }
    if (normalizedOptions.length != options.length) {
      setState(() => _validationMessage = 'Poll options must be unique.');
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .createCommunityPoll(
          question: _question.text.trim(),
          options: options,
          author: widget.author,
          authorId: widget.authorId,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

class _AssessmentDialog extends ConsumerStatefulWidget {
  const _AssessmentDialog({required this.authorId});

  final String authorId;

  @override
  ConsumerState<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends ConsumerState<_AssessmentDialog> {
  final _title = TextEditingController();
  final _channel = TextEditingController();
  final _channelId = TextEditingController();
  final _questionCount = TextEditingController(text: '10');
  final _instructions = TextEditingController();
  final _solution = TextEditingController();
  AssessmentKind _kind = AssessmentKind.quiz;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _channel.dispose();
    _channelId.dispose();
    _questionCount.dispose();
    _instructions.dispose();
    _solution.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create quiz or exercise'),
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
              controller: _channel,
              decoration: const InputDecoration(labelText: 'Channel'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _channelId,
              decoration: const InputDecoration(labelText: 'Channel id'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _questionCount,
              decoration: const InputDecoration(labelText: 'Question count'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructions,
              decoration: const InputDecoration(labelText: 'Questions or instructions'),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _solution,
              decoration: const InputDecoration(labelText: 'Lecturer solution'),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            SegmentedButton<AssessmentKind>(
              segments: const [
                ButtonSegment(value: AssessmentKind.quiz, icon: Icon(Icons.quiz_outlined), label: Text('Quiz')),
                ButtonSegment(
                  value: AssessmentKind.exercise,
                  icon: Icon(Icons.assignment_outlined),
                  label: Text('Exercise'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() {
                _kind = value.single;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Creating...' : 'Create')),
      ],
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _channel.text.trim().isEmpty || _channelId.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(schoolRepositoryProvider)
        .createAssessment(
          title: _title.text.trim(),
          channel: _channel.text.trim(),
          kind: _kind,
          questionCount: int.tryParse(_questionCount.text.trim()) ?? 0,
          channelId: _channelId.text.trim(),
          authorId: widget.authorId,
          instructions: _instructions.text.trim(),
          solution: _solution.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
