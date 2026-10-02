import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:smart_customer_segmentation/models.dart';
import 'package:smart_customer_segmentation/pages/auth_page.dart';
import 'package:smart_customer_segmentation/services/local_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Supabase password recovery is normalized and privacy safe', (
    WidgetTester tester,
  ) async {
    String? requestedEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          usesSupabase: true,
          onAuthenticated: (_) async => const AuthOutcome(),
          onPasswordReset: (email) async => requestedEmail = email,
        ),
      ),
    );

    expect(
      find.text('Your workspace and permissions follow your account.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-role')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      '  PERSON@Example.com ',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'person@example.com');
    expect(
      find.text(
        'If an account exists for this email, a recovery link is on its way.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sign-up keeps role selection and validates reset email', (
    WidgetTester tester,
  ) async {
    AppRole? submittedRole;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          usesSupabase: true,
          onAuthenticated: (credentials) async {
            submittedRole = credentials.profile.role;
            return const AuthOutcome();
          },
          onPasswordReset: (_) async {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'not-an-email',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address first.'), findsOneWidget);

    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-role')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer').last);
    await tester.pumpAndSettle();
    expect(find.text('Customer'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('auth-name')), 'Ravi Test');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'ravi@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPass8!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'StrongPass8!',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(submittedRole, AppRole.customer);
  });

  testWidgets('remembered email persists and can be cleared', (
    WidgetTester tester,
  ) async {
    String? authenticatedEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          onAuthenticated: (credentials) async {
            authenticatedEmail = credentials.profile.email;
            return const AuthOutcome();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      ' PERSON@Example.com ',
    );
    await tester.tap(find.text('Remember email'));
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'previewpass123',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(authenticatedEmail, 'person@example.com');
    expect(await LocalStore().loadRememberedEmail(), 'person@example.com');

    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(onAuthenticated: (_) async => const AuthOutcome()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-email')))
          .controller
          ?.text,
      'person@example.com',
    );
    await tester.tap(find.byTooltip('Clear email address'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-email')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('signup provides password guidance and resend confirmation', (
    WidgetTester tester,
  ) async {
    String? resentEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          usesSupabase: true,
          onAuthenticated: (_) async => const AuthOutcome(
            message: 'Check your email to confirm your account, then sign in.',
            requiresEmailConfirmation: true,
          ),
          onResendConfirmation: (email) async => resentEmail = email,
        ),
      ),
    );
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth-name')),
      'Ravi Patel',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      ' RAVI@Example.com ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPass8!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'StrongPass8!',
    );
    await tester.pumpAndSettle();

    expect(find.text('Password strength'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('Passwords match.'), findsOneWidget);
    await tester.tap(find.byTooltip('Show confirmation password'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('auth-confirm-password')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('auth-password')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Resend confirmation email'), findsOneWidget);
    await tester.tap(find.text('Resend confirmation email'));
    await tester.pumpAndSettle();
    expect(resentEmail, 'ravi@example.com');
    expect(
      find.text(
        'If this address is awaiting confirmation, another email is on its way.',
      ),
      findsOneWidget,
    );
  });
}
