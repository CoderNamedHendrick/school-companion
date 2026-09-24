import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaisel/kaisel.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../data/firebase/auth_session_service.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/firebase/push_notification_service.dart';
import '../../data/school_models.dart';
import '../channels/channel_detail_screen.dart';
import '../channels/channels_screen.dart';
import '../community/community_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../meetings/meetings_screen.dart';
import '../projects/projects_screen.dart';
import '../resources/resources_screen.dart';
import '../../shared/async_content.dart';

class SchoolShell extends StatelessWidget {
  const SchoolShell({super.key});

  @override
  Widget build(BuildContext context) {
    return KaiselBranchedShell.specs(
      branches: [
        KaiselBranchSpec<DashboardBranchRoute>(
          initial: const DashboardHomeRoute(),
          builder: (context, route) => switch (route) {
            DashboardHomeRoute() => const DashboardScreen(),
          },
        ),
        KaiselBranchSpec<ChannelsBranchRoute>(
          initial: const ChannelsHomeRoute(),
          builder: (context, route) => switch (route) {
            ChannelsHomeRoute() => const ChannelsScreen(),
            ChannelDetailBranchRoute(:final channelId) => ChannelDetailScreen(channelId: channelId),
          },
        ),
        KaiselBranchSpec<ResourcesBranchRoute>(
          initial: const ResourcesHomeRoute(),
          builder: (context, route) => switch (route) {
            ResourcesHomeRoute() => const ResourcesScreen(),
          },
        ),
        KaiselBranchSpec<MeetingsBranchRoute>(
          initial: const MeetingsHomeRoute(),
          builder: (context, route) => switch (route) {
            MeetingsHomeRoute() => const MeetingsScreen(),
          },
        ),
        KaiselBranchSpec<ProjectsBranchRoute>(
          initial: const ProjectsHomeRoute(),
          builder: (context, route) => switch (route) {
            ProjectsHomeRoute() => const ProjectsScreen(),
          },
        ),
        KaiselBranchSpec<CommunityBranchRoute>(
          initial: const CommunityHomeRoute(),
          builder: (context, route) => switch (route) {
            CommunityHomeRoute() => const CommunityScreen(),
          },
        ),
      ],
      chromeBuilder: (context, activeBranch, branchContent, switchBranch) {
        return _SchoolChrome(activeBranch: activeBranch, branchContent: branchContent, switchBranch: switchBranch);
      },
    );
  }
}

class _SchoolChrome extends ConsumerWidget {
  const _SchoolChrome({required this.activeBranch, required this.branchContent, required this.switchBranch});

  final int activeBranch;
  final Widget branchContent;
  final ValueChanged<int> switchBranch;

  static const _destinations = [
    _Destination('Home', Icons.space_dashboard_outlined, Icons.space_dashboard),
    _Destination('Channels', Icons.forum_outlined, Icons.forum),
    _Destination('Library', Icons.folder_copy_outlined, Icons.folder_copy),
    _Destination('Meetings', Icons.video_camera_front_outlined, Icons.video_camera_front),
    _Destination('Projects', Icons.view_kanban_outlined, Icons.view_kanban),
    _Destination('Community', Icons.groups_outlined, Icons.groups),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final user = switch (ref.watch(currentUserProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final userInitial = user?.name.characters.firstOrNull ?? 'S';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: MivaColors.navy, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'SC',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('School Companion', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _NotificationsDialog()),
            icon: const Icon(Icons.notifications_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              tooltip: 'Account menu',
              onSelected: (value) async {
                if (value == 'edit-profile' && user != null) {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _ProfileDialog(user: user),
                  );
                } else if (value == 'about') {
                  appRouterConfig.router.push(const AboutRoute());
                } else if (value == 'privacy') {
                  appRouterConfig.router.push(const PrivacyPolicyRoute());
                } else if (value == 'terms') {
                  appRouterConfig.router.push(const TermsOfServiceRoute());
                } else if (value == 'sign-out') {
                  try {
                    await ref.read(pushNotificationServiceProvider).unregisterDevice();
                    await AuthSessionService.clear();
                    await ref.read(firebaseAuthProvider).signOut();
                    goTo(const SignInRoute());
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Could not finish signing out. Please try again.')));
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text(user?.email ?? 'School Companion account')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit-profile',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('Manage profile'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('About School Companion'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'privacy',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('Privacy Policy'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'terms',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.description_outlined),
                    title: Text('Terms of Service'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'sign-out',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                  ),
                ),
              ],
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: CircleAvatar(
                    backgroundColor: MivaColors.gold.withValues(alpha: 0.25),
                    foregroundColor: MivaColors.navy,
                    child: Text(userInitial),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: activeBranch,
              extended: MediaQuery.sizeOf(context).width >= 1120,
              onDestinationSelected: switchBranch,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton.icon(
                  onPressed: () => switchBranch(SchoolBranch.channels),
                  icon: const Icon(Icons.add),
                  label: const Text('New space'),
                ),
              ),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(child: branchContent),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: activeBranch.clamp(0, _destinations.length - 1),
              onDestinationSelected: switchBranch,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}

class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog({required this.user});

  final SchoolUser user;

  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _programme;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _programme = TextEditingController(text: widget.user.programme);
  }

  @override
  void dispose() {
    _name.dispose();
    _programme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage profile'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              maxLength: 100,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _programme,
              maxLength: 160,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Programme'),
            ),
            const SizedBox(height: 8),
            Text('Email: ${widget.user.email}'),
            Text('Role: ${widget.user.role.name}'),
            const SizedBox(height: 8),
            const Text('Email and role are institution-controlled and cannot be changed here.'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: MivaColors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save changes')),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(schoolRepositoryProvider)
          .updateUserProfile(userId: widget.user.id, name: name, programme: _programme.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not update profile: $error';
        });
      }
    }
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    return AlertDialog(
      title: const Text('Notifications'),
      content: SizedBox(
        width: 420,
        child: AsyncContent(
          value: notificationsAsync,
          data: (notifications) {
            if (notifications.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications',
                message: 'Updates from your channels will appear here.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final notification in notifications)
                  ListTile(
                    onTap: notification.read
                        ? null
                        : () => ref
                              .read(schoolRepositoryProvider)
                              .markNotificationRead(
                                userId: ref.read(activeUserIdProvider),
                                notificationId: notification.id,
                              ),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      notification.read ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.body),
                    trailing: Text(notification.created),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final userId = ref.read(activeUserIdProvider);
            final status = await ref.read(pushNotificationServiceProvider).registerDevice(userId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Push notification status: $status')));
            }
          },
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Enable push'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
