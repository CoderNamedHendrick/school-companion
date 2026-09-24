import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;

    return AdaptivePage(
      title: 'Meetings',
      subtitle: 'Lecturer-led Google Calendar and Meet scheduling for channels.',
      actions: [
        FilledButton.icon(
          onPressed: user?.role == UserRole.lecturer
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => _MeetingDialog(organizerId: user!.id),
                )
              : null,
          icon: const Icon(Icons.add_call),
          label: const Text('New meeting'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final upcoming = _UpcomingMeetings(meetingsAsync: meetingsAsync);
          final form = _MeetingForm(user: user);
          if (!wide) {
            return Column(children: [upcoming, const SizedBox(height: 14), form]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: upcoming),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: form),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingMeetings extends StatelessWidget {
  const _UpcomingMeetings({required this.meetingsAsync});

  final AsyncValue<List<ScheduledMeeting>> meetingsAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            AsyncContent(
              value: meetingsAsync,
              data: (meetings) {
                if (meetings.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No meetings scheduled',
                    message: 'Meetings scheduled for your channels will appear here.',
                  );
                }
                return Column(
                  children: [
                    for (final meeting in meetings)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.video_camera_front_outlined),
                        title: Text(meeting.title),
                        subtitle: Text('${meeting.channel} • ${meeting.time} • ${meeting.duration}'),
                        trailing: Chip(
                          avatar: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(meeting.status),
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

class _MeetingForm extends ConsumerWidget {
  const _MeetingForm({required this.user});

  final SchoolUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schedule draft',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Meeting title')),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: 'Channel')),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: 'Date and time')),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: true,
              onChanged: (_) {},
              title: const Text('Generate Meet link'),
              subtitle: const Text('Calendar event will store the link and invite metadata.'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: user?.role == UserRole.lecturer
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => _MeetingDialog(organizerId: user!.id),
                    )
                  : null,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Create calendar event'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a Google Meet meeting and invite your channel members.',
              style: TextStyle(color: MivaColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingDialog extends ConsumerStatefulWidget {
  const _MeetingDialog({required this.organizerId});

  final String organizerId;

  @override
  ConsumerState<_MeetingDialog> createState() => _MeetingDialogState();
}

class _MeetingDialogState extends ConsumerState<_MeetingDialog> {
  final _title = TextEditingController();
  final _channelId = TextEditingController();
  final _channel = TextEditingController();
  final _startsAt = TextEditingController();
  final _duration = TextEditingController();
  final _attendees = TextEditingController();
  bool _generateMeetLink = true;
  bool _transcriptsEnabled = true;
  bool _smartNotesEnabled = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startsAt.text = DateTime.now().add(const Duration(days: 1)).toLocal().toIso8601String().substring(0, 16);
    _duration.text = '45 min';
  }

  @override
  void dispose() {
    _title.dispose();
    _channelId.dispose();
    _channel.dispose();
    _startsAt.dispose();
    _duration.dispose();
    _attendees.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Google Workspace meeting'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Meeting title'),
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
                controller: _startsAt,
                decoration: const InputDecoration(labelText: 'Date and time'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _duration,
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _attendees,
                decoration: const InputDecoration(labelText: 'Attendee emails (comma separated)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _generateMeetLink,
                onChanged: (value) => setState(() => _generateMeetLink = value),
                title: const Text('Generate Meet link'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _transcriptsEnabled,
                onChanged: (value) => setState(() => _transcriptsEnabled = value),
                title: const Text('Enable transcripts'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _smartNotesEnabled,
                onChanged: (value) => setState(() => _smartNotesEnabled = value),
                title: const Text('Enable smart notes'),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: MivaColors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Requesting...' : 'Request meeting')),
      ],
    );
  }

  Future<void> _save() async {
    final startsAt = DateTime.tryParse(_startsAt.text.trim());
    final minutes = int.tryParse(RegExp(r'\d+').firstMatch(_duration.text)?.group(0) ?? '') ?? 45;
    if (_title.text.trim().isEmpty ||
        _channel.text.trim().isEmpty ||
        _channelId.text.trim().isEmpty ||
        startsAt == null) {
      setState(() => _error = 'Title, channel, channel id, and a valid ISO date/time are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(schoolRepositoryProvider)
          .createMeetingRequest(
            title: _title.text.trim(),
            channelId: _channelId.text.trim(),
            channel: _channel.text.trim(),
            startsAtLabel: _startsAt.text.trim(),
            duration: _duration.text.trim(),
            generateMeetLink: _generateMeetLink,
            transcriptsEnabled: _transcriptsEnabled,
            smartNotesEnabled: _smartNotesEnabled,
            organizerId: widget.organizerId,
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(minutes: minutes)),
            attendees: _attendees.text
                .split(',')
                .map((email) => email.trim())
                .where((email) => email.isNotEmpty)
                .toList(),
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
