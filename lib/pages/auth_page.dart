import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../services/local_store.dart';

enum AuthMode { signIn, signUp }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onAuthenticated,
    this.onPasswordReset,
    this.onResendConfirmation,
    this.usesSupabase = false,
  });

  final Future<AuthOutcome> Function(AuthCredentials credentials)
  onAuthenticated;
  final Future<void> Function(String email)? onPasswordReset;
  final Future<void> Function(String email)? onResendConfirmation;
  final bool usesSupabase;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final LocalStore localStore = LocalStore();
  AuthMode mode = AuthMode.signIn;
  AppRole selectedRole = AppRole.analyst;
  bool passwordObscured = true;
  bool confirmationObscured = true;
  bool isSubmitting = false;
  bool isRequestingPasswordReset = false;
  bool isResendingConfirmation = false;
  bool rememberEmail = false;
  bool requiresEmailConfirmation = false;
  String? submitError;
  String? resetMessage;
  String? confirmationMessage;

  bool get isSignUp => mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRememberedEmail());
  }

  Future<void> _restoreRememberedEmail() async {
    final email = await localStore.loadRememberedEmail();
    if (!mounted || email == null) return;
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail != email) {
      await localStore.saveRememberedEmail(normalizedEmail);
    }
    setState(() {
      rememberEmail = true;
      emailController.text = normalizedEmail;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  void changeMode(AuthMode value) {
    if (value == mode) return;
    setState(() {
      mode = value;
      submitError = null;
      resetMessage = null;
      confirmationMessage = null;
      requiresEmailConfirmation = false;
      if (value == AuthMode.signUp && selectedRole == AppRole.admin) {
        selectedRole = AppRole.analyst;
      }
      formKey.currentState?.reset();
    });
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  Future<void> _setRememberEmail(bool value) async {
    setState(() => rememberEmail = value);
    if (value) {
      final email = emailController.text.trim().toLowerCase();
      if (_isValidEmail(email)) await localStore.saveRememberedEmail(email);
    } else {
      await localStore.clearRememberedEmail();
    }
  }

  Future<void> requestPasswordReset() async {
    final email = emailController.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      setState(() {
        submitError = 'Enter a valid email address first.';
        resetMessage = null;
      });
      return;
    }
    final callback = widget.onPasswordReset;
    if (callback == null) return;

    setState(() {
      isRequestingPasswordReset = true;
      submitError = null;
      resetMessage = null;
    });
    try {
      await callback(email);
      if (mounted) {
        setState(
          () => resetMessage =
              'If an account exists for this email, a recovery link is on its way.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => submitError =
              'Could not send a recovery email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => isRequestingPasswordReset = false);
    }
  }

  Future<void> resendConfirmationEmail() async {
    final email = emailController.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      setState(() => submitError = 'Enter a valid email address first.');
      return;
    }
    final callback = widget.onResendConfirmation;
    if (callback == null) return;
    setState(() {
      isResendingConfirmation = true;
      submitError = null;
      confirmationMessage = null;
    });
    try {
      await callback(email);
      if (mounted) {
        setState(
          () => confirmationMessage =
              'If this address is awaiting confirmation, another email is on its way.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => submitError = 'Could not resend the email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => isResendingConfirmation = false);
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      isSubmitting = true;
      submitError = null;
    });
    try {
      final email = emailController.text.trim().toLowerCase();
      if (emailController.text != email) {
        emailController.value = TextEditingValue(
          text: email,
          selection: TextSelection.collapsed(offset: email.length),
        );
      }
      if (rememberEmail && !isSignUp) {
        await localStore.saveRememberedEmail(email);
      }
      final outcome = await widget.onAuthenticated(
        AuthCredentials(
          profile: AppUser(
            email: email,
            name: isSignUp || nameController.text.trim().isEmpty
                ? (isSignUp
                      ? nameController.text.trim()
                      : email.split('@').first)
                : nameController.text.trim(),
            role: selectedRole,
          ),
          password: passwordController.text,
          isSignUp: isSignUp,
        ),
      );
      if (outcome.message != null && mounted) {
        setState(() {
          requiresEmailConfirmation = outcome.requiresEmailConfirmation;
          if (outcome.requiresEmailConfirmation) {
            confirmationMessage = outcome.message;
          } else {
            submitError = outcome.message;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => submitError = 'Could not start your session.');
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: AutofillGroup(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: forest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.scatter_plot_rounded,
                            color: lime,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'MOSAIC',
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Text(
                      isSignUp
                          ? 'Make room for\nbetter insight.'
                          : 'Welcome\nback.',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      isSignUp
                          ? 'Create an account to start exploring your audience.'
                          : 'Sign in to see what your customers are telling you.',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 23),
                    SegmentedButton<AuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: AuthMode.signIn,
                          label: Text('Sign in'),
                        ),
                        ButtonSegment(
                          value: AuthMode.signUp,
                          label: Text('Create account'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) =>
                          changeMode(selection.first),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        key: ValueKey(mode),
                        children: [
                          if (isSignUp) ...[
                            TextFormField(
                              key: const ValueKey('auth-name'),
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter your name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            key: const ValueKey('auth-email'),
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => setState(() {
                              submitError = null;
                              resetMessage = null;
                              confirmationMessage = null;
                            }),
                            onEditingComplete: () {
                              final normalized = emailController.text
                                  .trim()
                                  .toLowerCase();
                              if (emailController.text != normalized) {
                                emailController.value = TextEditingValue(
                                  text: normalized,
                                  selection: TextSelection.collapsed(
                                    offset: normalized.length,
                                  ),
                                );
                              }
                              FocusScope.of(context).nextFocus();
                            },
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                              suffixIcon: emailController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear email address',
                                      onPressed: () {
                                        emailController.clear();
                                        setState(() {
                                          submitError = null;
                                          resetMessage = null;
                                        });
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return _isValidEmail(email)
                                  ? null
                                  : 'Enter a valid email address.';
                            },
                          ),
                          const SizedBox(height: 12),
                          if (isSignUp || !widget.usesSupabase)
                            DropdownButtonFormField<AppRole>(
                              key: const ValueKey('auth-role'),
                              initialValue: selectedRole,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isSignUp
                                    ? 'Account role'
                                    : 'Preview role',
                                helperText: isSignUp
                                    ? 'Choose Analyst, Marketing, or Customer. Admin access is assigned separately.'
                                    : widget.usesSupabase
                                    ? 'Role selection is only available during sign-up.'
                                    : 'Role selection is for this local demo only.',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: [
                                for (final role in AppRole.values)
                                  if (!isSignUp || role != AppRole.admin)
                                    DropdownMenuItem(
                                      value: role,
                                      child: Text(role.label),
                                    ),
                              ],
                              onChanged: (role) {
                                if (role != null) {
                                  setState(() => selectedRole = role);
                                }
                              },
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: forest.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: forest,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Your workspace and permissions follow your account.',
                                      style: TextStyle(
                                        color: forest,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('auth-password'),
                            controller: passwordController,
                            obscureText: passwordObscured,
                            textInputAction: isSignUp
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: isSignUp
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!isSignUp) submit();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: passwordObscured
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => passwordObscured = !passwordObscured,
                                ),
                                icon: Icon(
                                  passwordObscured
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) =>
                                value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          if (isSignUp) ...[
                            const SizedBox(height: 12),
                            _PasswordGuidance(
                              password: passwordController.text,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('auth-confirm-password'),
                              controller: confirmationController,
                              obscureText: confirmationObscured,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => submit(),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(
                                  Icons.verified_user_outlined,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: confirmationObscured
                                      ? 'Show confirmation password'
                                      : 'Hide confirmation password',
                                  onPressed: () => setState(
                                    () => confirmationObscured =
                                        !confirmationObscured,
                                  ),
                                  icon: Icon(
                                    confirmationObscured
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                helperText: confirmationController.text.isEmpty
                                    ? null
                                    : confirmationController.text ==
                                          passwordController.text
                                    ? 'Passwords match.'
                                    : 'Passwords do not match.',
                                helperStyle: TextStyle(
                                  color: confirmationController.text.isEmpty
                                      ? muted
                                      : confirmationController.text ==
                                            passwordController.text
                                      ? forest
                                      : const Color(0xFFAD4A31),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) =>
                                  value != passwordController.text
                                  ? 'Passwords do not match.'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isSignUp)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: rememberEmail,
                        onChanged: (value) =>
                            unawaited(_setRememberEmail(value ?? false)),
                        title: const Text('Remember email'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    if (submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        submitError!,
                        style: const TextStyle(color: Color(0xFFAD4A31)),
                      ),
                    ],
                    if (resetMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        resetMessage!,
                        style: const TextStyle(color: forest, fontSize: 12),
                      ),
                    ],
                    if (confirmationMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        confirmationMessage!,
                        style: const TextStyle(color: forest, fontSize: 12),
                      ),
                    ],
                    if (requiresEmailConfirmation &&
                        widget.onResendConfirmation != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isResendingConfirmation
                              ? null
                              : resendConfirmationEmail,
                          icon: isResendingConfirmation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mark_email_unread_outlined),
                          label: Text(
                            isResendingConfirmation
                                ? 'Sending…'
                                : 'Resend confirmation email',
                          ),
                        ),
                      ),
                    ],
                    if (!isSignUp && widget.usesSupabase) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isRequestingPasswordReset
                              ? null
                              : requestPasswordReset,
                          child: isRequestingPasswordReset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Forgot password?'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSubmitting ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: forest,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isSignUp ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        widget.usesSupabase
                            ? 'Protected by Supabase Auth.'
                            : 'Preview mode. Connect an identity provider for real accounts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PasswordGuidance extends StatelessWidget {
  const _PasswordGuidance({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final checks = <(String, bool)>[
      ('At least 8 characters', password.length >= 8),
      ('Uppercase letter', RegExp('[A-Z]').hasMatch(password)),
      ('Number', RegExp('[0-9]').hasMatch(password)),
      ('Symbol', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
    ];
    final score = checks.where((check) => check.$2).length;
    final strength = switch (score) {
      0 || 1 => 'Low',
      2 => 'Fair',
      3 => 'Good',
      _ => 'Strong',
    };
    final color = switch (score) {
      0 || 1 => const Color(0xFFAD4A31),
      2 => coral,
      3 => sky,
      _ => forest,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Password strength')),
            Text(
              strength,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: score / checks.length,
          minHeight: 5,
          color: color,
          backgroundColor: const Color(0xFFE1E6DF),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (label, passes) in checks)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passes ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 13,
                    color: passes ? forest : muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: passes ? forest : muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
