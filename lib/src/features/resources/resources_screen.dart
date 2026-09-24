import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../data/firebase/resource_storage.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';
import '../../shared/adaptive_page.dart';
import '../../shared/async_content.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(resourcesProvider);

    return AdaptivePage(
      title: 'Resource repository',
      subtitle: 'Documents, audio, video, transcripts, and note-ready learning materials.',
      actions: [
        FilledButton.icon(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _ResourceDialog()),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload'),
        ),
      ],
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SizedBox(
                    width: 360,
                    child: TextField(
                      decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search resources'),
                    ),
                  ),
                  FilterChip(label: const Text('PDF'), selected: true, onSelected: (_) {}),
                  FilterChip(label: const Text('Video'), selected: true, onSelected: (_) {}),
                  FilterChip(label: const Text('Audio'), selected: false, onSelected: (_) {}),
                  FilterChip(label: const Text('Has transcript'), selected: true, onSelected: (_) {}),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AsyncContent(
            value: resourcesAsync,
            data: (resources) {
              if (resources.isEmpty) {
                return const EmptyState(
                  icon: Icons.folder_copy_outlined,
                  title: 'No resources yet',
                  message: 'Share a file, transcript, or study note with your channel.',
                );
              }
              return Column(
                children: [
                  for (final resource in resources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => _ResourceDetails(resource: resource),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: MivaColors.navy.withValues(alpha: 0.1),
                            foregroundColor: MivaColors.navy,
                            child: Icon(_iconFor(resource.kind)),
                          ),
                          title: Text(resource.title),
                          subtitle: Text('${resource.channel} • Updated ${resource.updated}'),
                          trailing: resource.hasTranscript
                              ? const Chip(label: Text('Transcript'))
                              : const Icon(Icons.chevron_right),
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

  IconData _iconFor(ResourceKind kind) {
    return switch (kind) {
      ResourceKind.pdf => Icons.picture_as_pdf_outlined,
      ResourceKind.audio => Icons.graphic_eq_outlined,
      ResourceKind.video => Icons.smart_display_outlined,
      ResourceKind.transcript => Icons.article_outlined,
    };
  }
}

class _ResourceDialog extends ConsumerStatefulWidget {
  const _ResourceDialog();

  @override
  ConsumerState<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends ConsumerState<_ResourceDialog> {
  final _title = TextEditingController();
  final _channelId = TextEditingController();
  final _channel = TextEditingController();
  final _transcript = TextEditingController();
  final _notes = TextEditingController();
  ResourceKind _kind = ResourceKind.pdf;
  PlatformFile? _selectedFile;
  int? _selectedFileSize;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _channelId.dispose();
    _channel.dispose();
    _transcript.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add learning resource'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Resource title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _channel,
                decoration: const InputDecoration(labelText: 'Channel name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _channelId,
                decoration: const InputDecoration(labelText: 'Channel id'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ResourceKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ResourceKind.values
                    .map((kind) => DropdownMenuItem(value: kind, child: Text(kind.name)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _kind = value ?? ResourceKind.pdf;
                }),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_selectedFile?.name ?? 'Choose PDF, audio, or video'),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 6),
                Text('${_selectedFileSize ?? 0} bytes selected'),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _transcript,
                decoration: const InputDecoration(labelText: 'Transcript'),
                minLines: 2,
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: MivaColors.red)),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Study notes'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Adding...' : 'Add resource')),
      ],
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _channel.text.trim().isEmpty || _channelId.text.trim().isEmpty) {
      setState(() => _error = 'Title, channel name, and channel id are required.');
      return;
    }
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null) return;
    if (_selectedFile == null && _kind != ResourceKind.transcript) {
      setState(() {
        _error = 'Choose a file to upload.';
      });
      return;
    }
    setState(() => _saving = true);
    try {
      var storagePath = '';
      var kind = _kind;
      final file = _selectedFile;
      if (file != null) {
        kind = _kindForExtension(_extensionOf(file.name));
        final bytes = await file.readAsBytes();
        storagePath = await ref
            .read(resourceStorageProvider)
            .upload(
              channelId: _channelId.text.trim(),
              userId: user.id,
              fileName: file.name,
              bytes: bytes,
              contentType: _contentTypeFor(_extensionOf(file.name)),
            );
      }
      await ref
          .read(schoolRepositoryProvider)
          .addResource(
            title: _title.text.trim(),
            kind: kind,
            channelId: _channelId.text.trim(),
            channel: _channel.text.trim(),
            storagePath: storagePath,
            transcript: _transcript.text.trim(),
            notes: _notes.text.trim(),
            uploaderId: user.id,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Upload failed: $error';
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'mp3', 'm4a', 'wav', 'mp4', 'mov', 'txt'],
    );
    if (file == null) return;
    final size = await file.length();
    setState(() {
      _selectedFile = file;
      _selectedFileSize = size;
      _title.text = _title.text.trim().isEmpty ? file.name : _title.text;
      _kind = _kindForExtension(_extensionOf(file.name));
      _error = null;
    });
  }

  String? _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? null : fileName.substring(dot + 1).toLowerCase();
  }

  String _contentTypeFor(String? extension) {
    return switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'text/plain',
    };
  }

  ResourceKind _kindForExtension(String? extension) {
    return switch (extension) {
      'pdf' => ResourceKind.pdf,
      'mp3' || 'm4a' || 'wav' => ResourceKind.audio,
      'mp4' || 'mov' => ResourceKind.video,
      _ => ResourceKind.transcript,
    };
  }
}

class _ResourceDetails extends ConsumerStatefulWidget {
  const _ResourceDetails({required this.resource});

  final LearningResource resource;

  @override
  ConsumerState<_ResourceDetails> createState() => _ResourceDetailsState();
}

class _ResourceDetailsState extends ConsumerState<_ResourceDetails> {
  bool _opening = false;
  bool _deleting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final user = ref.watch(currentUserProvider).asData?.value;
    final canDelete = user != null && (user.role == UserRole.lecturer || user.id == resource.uploaderId);
    return AlertDialog(
      title: Text(resource.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${resource.channel} • ${resource.kind.name.toUpperCase()}'),
              const SizedBox(height: 16),
              Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText(resource.transcript.isEmpty ? 'No transcript attached.' : resource.transcript),
              const SizedBox(height: 16),
              Text('Study notes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText(resource.notes.isEmpty ? 'No study notes attached.' : resource.notes),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: MivaColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (canDelete)
          TextButton.icon(
            onPressed: _opening || _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Removing...' : 'Remove'),
          ),
        TextButton(onPressed: _deleting ? null : () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton.icon(
          onPressed: _opening || _deleting || resource.storagePath.isEmpty ? null : _open,
          icon: const Icon(Icons.open_in_new),
          label: Text(_opening ? 'Downloading...' : 'Download file'),
        ),
      ],
    );
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(resourceStorageProvider).download(widget.resource.storagePath);
      await FilePicker.saveFile(fileName: widget.resource.storagePath.split('/').last, bytes: bytes);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open resource: $error');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove resource?'),
        content: const Text('This permanently removes the resource metadata and its uploaded file.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      if (widget.resource.storagePath.isNotEmpty) {
        await ref.read(resourceStorageProvider).delete(widget.resource.storagePath);
      }
      await ref.read(schoolRepositoryProvider).deleteResource(resourceId: widget.resource.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'Could not remove resource: $error';
        });
      }
    }
  }
}
