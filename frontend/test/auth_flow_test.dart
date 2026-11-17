import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ghiza_o_sehat/api_service.dart';
import 'package:ghiza_o_sehat/main.dart';
import 'package:ghiza_o_sehat/services/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.requireEmailConfirmation = false});

  final bool requireEmailConfirmation;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  String? lastPreferredLanguage;

  @override
  bool get isConfigured => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (password != 'secret123') {
      throw const AuthFailure(
        'Invalid email or password. Please check your credentials.',
      );
    }
    _user = AppUser(
      id: 'user-1',
      email: email,
      displayName: 'Ayesha Khan',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
    String preferredLanguage = 'en',
  }) async {
    lastPreferredLanguage = preferredLanguage;
    if (email == 'taken@example.com') {
      throw const AuthFailure(
        'An account with this email already exists. Try signing in instead.',
      );
    }
    final created = AppUser(
      id: 'user-2',
      email: email,
      displayName: displayName,
      preferredLanguage: preferredLanguage,
    );
    if (requireEmailConfirmation) {
      return const SignUpOutcome(
        user: null,
        requiresEmailConfirmation: true,
      );
    }
    _user = created;
    _controller.add(_user);
    return SignUpOutcome(
      user: created,
      requiresEmailConfirmation: false,
    );
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

ApiService _mockApi() => ApiService(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'classes': ['chapati', 'biryani'],
        'count': 2,
      }),
      200,
    ),
  ),
);

void main() {
  testWidgets('login validation, error state, sign-in and sign-out flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = FakeAuthService();
    final api = _mockApi();
    addTearDown(() {
      auth.dispose();
      api.close();
    });

    await tester.pumpWidget(MainApp(auth: auth, api: api));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    // Trigger empty validation
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    // Invalid email validation
    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'wrongpass',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    // Wrong credentials -> authError banner
    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'ayesha@example.com',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authError')), findsOneWidget);
    expect(find.textContaining('Invalid email or password'), findsOneWidget);

    // Valid credentials -> lands on MealScreen with user name and sign-out button
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Understand your meal'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);

    // Sign out -> returns to LoginScreen
    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('register validation, language selection and account creation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = FakeAuthService();
    final api = _mockApi();
    addTearDown(() {
      auth.dispose();
      api.close();
    });

    await tester.pumpWidget(MainApp(auth: auth, api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goToRegisterButton')));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    // Validation checks: short password and mismatched confirmation
    await tester.enterText(
      find.byKey(const Key('registerNameField')),
      'Faiz Ahmed',
    );
    await tester.enterText(
      find.byKey(const Key('registerEmailField')),
      'faiz@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('registerConfirmPasswordField')),
      'different',
    );
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);

    // Select Roman Urdu as preferred language
    await tester.tap(find.byKey(const Key('registerLanguageDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roman Urdu').last);
    await tester.pumpAndSettle();

    // Fix passwords and submit
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('registerConfirmPasswordField')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(auth.lastPreferredLanguage, 'roman_ur');
    expect(find.text('Understand your meal'), findsOneWidget);
    expect(find.text('Faiz Ahmed'), findsOneWidget);
  });

  testWidgets('register with email confirmation returns to login with banner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = FakeAuthService(requireEmailConfirmation: true);
    final api = _mockApi();
    addTearDown(() {
      auth.dispose();
      api.close();
    });

    await tester.pumpWidget(MainApp(auth: auth, api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goToRegisterButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('registerNameField')),
      'Zainab Ali',
    );
    await tester.enterText(
      find.byKey(const Key('registerEmailField')),
      'zainab@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('registerConfirmPasswordField')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('authInfoBanner')), findsOneWidget);
    expect(
      find.textContaining('Check your email to confirm your address'),
      findsOneWidget,
    );
  });
}
