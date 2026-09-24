import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../data/firebase/auth_session_service.dart';
import '../../data/firebase/school_repository.dart';
import '../../data/school_models.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _programme = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _programme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school, size: 52, color: MivaColors.navy),
                const SizedBox(height: 18),
                Text(
                  'Welcome to School Companion',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: MivaColors.navy),
                ),
                const SizedBox(height: 8),
                const Text('Sign in as a lecturer or student to continue.', textAlign: TextAlign.center),
                const SizedBox(height: 22),
                if (_creatingAccount) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_creatingAccount) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _programme,
                    decoration: const InputDecoration(labelText: 'Programme'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Student self-registration is available here. Lecturer accounts are provisioned by the institution and use the same sign-in form.',
                    style: TextStyle(color: MivaColors.blue),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: MivaColors.red)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _busy
                        ? 'Please wait...'
                        : _creatingAccount
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _creatingAccount = !_creatingAccount;
                          _error = null;
                        }),
                  child: Text(_creatingAccount ? 'I already have an account' : 'Create student account'),
                ),
                if (!_creatingAccount)
                  TextButton(onPressed: _busy ? null : _sendPasswordReset, child: const Text('Forgot password?')),
                const SizedBox(height: 8),
                const Divider(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: MivaColors.blue,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => appRouterConfig.router.push(const PrivacyPolicyRoute()),
                      child: const Text('Privacy Policy'),
                    ),
                    const Text('•', style: TextStyle(color: MivaColors.blue)),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: MivaColors.blue,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => appRouterConfig.router.push(const TermsOfServiceRoute()),
                      child: const Text('Terms of Service'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      final email = _email.text.trim();
      final password = _password.text;
      final credential = _creatingAccount
          ? await auth.createUserWithEmailAndPassword(email: email, password: password)
          : await auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;

      if (_creatingAccount && user != null) {
        await ref
            .read(schoolRepositoryProvider)
            .ensureUserProfile(
              userId: user.uid,
              name: _name.text.trim(),
              email: email,
              role: UserRole.student,
              programme: _programme.text.trim(),
            );
      }
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await auth.signOut();
        if (mounted) {
          setState(() {
            _creatingAccount = false;
            _error = 'Check your email to verify your account, then sign in.';
          });
        }
        return;
      }
      await AuthSessionService.create(user);
      goTo(const MainShellRoute());
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not sign in. Check your details and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email requested.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
