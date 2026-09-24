import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _sections = [
    _TermsSection(
      icon: Icons.verified_user_outlined,
      title: '1. Acceptance of Terms & Eligibility',
      content:
          'By accessing or using School Companion, you agree to be bound by these Terms of Service. If you do not agree, you must not access or use the application.\n\n'
          'The service is provided for students, lecturers, teaching assistants, and administrative personnel of recognized educational institutions. Users must maintain an active institutional account or verified student registration.',
    ),
    _TermsSection(
      icon: Icons.security_outlined,
      title: '2. User Accounts & Responsibilities',
      content:
          'You are responsible for maintaining the confidentiality of your login credentials and for all activities occurring under your account.\n'
          '• You agree to provide accurate and truthful profile information during registration.\n'
          '• You must notify your institution immediately of any unauthorized use or suspected security breach.\n'
          '• Account sharing or credential distribution outside the authorized individual is prohibited.',
    ),
    _TermsSection(
      icon: Icons.gavel_outlined,
      title: '3. Acceptable Use & Academic Integrity',
      content:
          'School Companion is designed to foster a safe, collaborative, and academically rigorous learning environment. You agree NOT to:\n'
          '• Post, upload, or transmit any unlawful, threatening, abusive, harassing, defamatory, or obscene content.\n'
          '• Engage in academic dishonesty, plagiarism, or unauthorized dissemination of confidential assessment materials.\n'
          '• Attempt to disrupt, compromise, or circumvent platform security measures, APIs, or database rules.\n'
          '• Upload malicious files, scripts, or content that infringes upon third-party intellectual property.',
    ),
    _TermsSection(
      icon: Icons.auto_stories_outlined,
      title: '4. Content Ownership & Course Materials',
      content:
          '• User Submissions: You retain ownership of coursework, notes, code, and project files submitted or shared through the platform.\n'
          '• Course Materials: Curricula, lecture notes, syllabus resources, and recordings uploaded by lecturers remain the intellectual property of the respective instructors and institution.\n'
          '• Platform License: By posting content in shared channels, you grant members of that space a limited license to review and collaborate on that content solely for educational purposes.',
    ),
    _TermsSection(
      icon: Icons.info_outline,
      title: '5. Service Availability & Disclaimers',
      content:
          '• The platform is provided "as is" and "as available". While we strive for high uptime and performance, uninterrupted service is not guaranteed.\n'
          '• Scheduled maintenance and feature updates will be communicated in advance whenever feasible.\n'
          '• School Companion is not liable for data loss arising from local connection issues or third-party service interruptions.',
    ),
    _TermsSection(
      icon: Icons.handshake_outlined,
      title: '6. Termination & Governing Terms',
      content:
          'We reserve the right to suspend or terminate access to any user who violates these Terms of Service or institutional code of conduct.\n\n'
          'These terms are governed by the applicable institutional guidelines and local laws. If you have questions regarding these terms, contact terms@schoolcompanion.edu.',
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
        title: const Text('Terms of Service'),
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
                              child: const Icon(Icons.article_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Terms of Service',
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
                          'These terms govern your use of the School Companion academic workspace. Please read them carefully before using our services.',
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
                          const Icon(Icons.privacy_tip_outlined, color: MivaColors.blue),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Have questions about how we handle your data?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              appRouterConfig.router.push(const PrivacyPolicyRoute());
                            },
                            child: const Text('View Privacy Policy'),
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

class _TermsSection {
  const _TermsSection({required this.icon, required this.title, required this.content});

  final IconData icon;
  final String title;
  final String content;
}
