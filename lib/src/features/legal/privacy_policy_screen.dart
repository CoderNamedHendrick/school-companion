import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _PolicySection(
      icon: Icons.shield_outlined,
      title: '1. Information We Collect',
      content:
          'School Companion collects information necessary to deliver educational collaboration tools. This includes:\n'
          '• Personal details: Name, academic email address, user role (student or lecturer), and academic programme.\n'
          '• Educational data: Course channel messages, project submissions, shared library resources, notes, and meeting schedules.\n'
          '• Technical metrics: Device information, session timestamps, and error reports required to ensure platform reliability.',
    ),
    _PolicySection(
      icon: Icons.lock_outline,
      title: '2. How We Use Your Information',
      content:
          'We use the collected information strictly for academic and operational purposes:\n'
          '• Providing role-based access to channels, learning materials, and live meetings.\n'
          '• Enabling real-time discussion, notification delivery, and group project collaboration.\n'
          '• Ensuring institutional compliance, academic integrity, and system security.\n'
          'We do not sell personal data or monetize educational records.',
    ),
    _PolicySection(
      icon: Icons.storage_outlined,
      title: '3. Data Storage & Security',
      content:
          'Your data is secured through industry-standard cloud infrastructure:\n'
          '• Authentication credentials are encrypted and managed via Firebase Authentication.\n'
          '• Application data is protected with granular Cloud Firestore security rules ensuring access is restricted to verified users.\n'
          '• Files and attachments uploaded to the platform are secured with Firebase Storage access policies and transmitted via HTTPS/TLS encryption.',
    ),
    _PolicySection(
      icon: Icons.people_outline,
      title: '4. Information Sharing & Disclosure',
      content:
          'Information is shared only within your learning workspace:\n'
          '• Course participants: Classmates and lecturers can view messages, project boards, and shared files within registered channels.\n'
          '• Institutional administrators: Authorized representatives may review academic activity in accordance with institution policies.\n'
          '• Service providers: We utilize trusted cloud service providers (such as Google Cloud / Firebase) strictly to operate the service.',
    ),
    _PolicySection(
      icon: Icons.assignment_turned_in_outlined,
      title: '5. Your Rights & Data Retention',
      content:
          'You have control over your personal data:\n'
          '• Profile updates: You can update your name and programme information directly from the profile settings.\n'
          '• Resource management: Lecturers and contributors can delete or update uploaded files at any time.\n'
          '• Account deletion: You may request account closure and data deletion through your institutional administrator or support.',
    ),
    _PolicySection(
      icon: Icons.contact_support_outlined,
      title: '6. Updates & Contact',
      content:
          'We may update this Privacy Policy periodically to reflect improvements in our features or compliance requirements. Continued use of the platform constitutes agreement to the updated policy.\n\n'
          'For privacy inquiries or data requests, please contact your institution or the School Companion support team at privacy@schoolcompanion.edu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (appRouterConfig.router.stack.length > 1) {
              appRouterConfig.router.pop();
            } else {
              goTo(const MainShellRoute());
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Privacy Policy'),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: MivaColors.navy, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MivaColors.gold.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy Policy',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Effective Date: September 2026 • Version 1.0',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your privacy is fundamental to how School Companion is designed. This document details our commitment to safeguarding the data of students, lecturers, and academic staff.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final section in _sections) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(section.icon, color: MivaColors.navy, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    section.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: MivaColors.navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(section.content, style: const TextStyle(height: 1.5, color: MivaColors.ink)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: MivaColors.blue),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Looking for our Terms of Service?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              appRouterConfig.router.push(const TermsOfServiceRoute());
                            },
                            child: const Text('View Terms of Service'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.icon, required this.title, required this.content});

  final IconData icon;
  final String title;
  final String content;
}
