import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = [
    _Feature(
      icon: Icons.forum_outlined,
      title: 'Learn together',
      description: 'Keep class conversations, announcements, and direct messages in one place.',
    ),
    _Feature(
      icon: Icons.folder_copy_outlined,
      title: 'Find what you need',
      description: 'Access shared resources and transcripts without searching across tools.',
    ),
    _Feature(
      icon: Icons.video_camera_front_outlined,
      title: 'Stay connected',
      description: 'Plan meetings and move from discussion to live collaboration quickly.',
    ),
    _Feature(
      icon: Icons.view_kanban_outlined,
      title: 'Make progress visible',
      description: 'Coordinate project tasks and keep your learning community moving forward.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => appRouterConfig.router.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('About'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 20),
                  Text(
                    'Everything your learning community needs',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: MivaColors.navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'School Companion brings the everyday parts of learning into one focused workspace.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: MivaColors.blue, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 2 ? 2.55 : 2.8,
                        children: [for (final feature in _features) _FeatureCard(feature: feature)],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _DetailsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: MivaColors.navy, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final mark = Container(
            width: compact ? 72 : 88,
            height: compact ? 72 : 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(
              'SC',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: MivaColors.navy, fontWeight: FontWeight.w900),
            ),
          );
          final copy = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                'School Companion',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Your classes, conversations, resources, meetings, and projects — together.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.5),
              ),
            ],
          );

          if (compact) {
            return Column(children: [mark, const SizedBox(height: 20), copy]);
          }
          return Row(
            children: [
              mark,
              const SizedBox(width: 24),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MivaColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(feature.icon, color: MivaColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: MivaColors.navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.4),
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: MivaColors.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _DetailRow(label: 'Version', value: '1.0.0'),
            const Divider(height: 24),
            const _DetailRow(label: 'Built for', value: 'Students, lecturers, and learning communities'),
            const Divider(height: 24),
            const _DetailRow(label: 'Our purpose', value: 'Make collaboration feel simple, focused, and connected.'),
            const Divider(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => appRouterConfig.router.push(const PrivacyPolicyRoute()),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('Privacy Policy'),
                ),
                OutlinedButton.icon(
                  onPressed: () => appRouterConfig.router.push(const TermsOfServiceRoute()),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Terms of Service'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '© 2026 School Companion. All rights reserved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MivaColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: MivaColors.blue, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;
}
